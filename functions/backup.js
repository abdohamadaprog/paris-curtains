'use strict';

/**
 * النسخ الاحتياطي لبيانات Firestore.
 *
 *  - dailyBackup  : نسخة تلقائية كل يوم 3 الفجر بتوقيت القاهرة.
 *  - runBackupNow : نسخة فورية من التطبيق (الأدمن فقط + App Check).
 *
 * كل نسخة = ملف واحد مضغوط (JSON Lines) في Cloud Storage:
 *   gs://<BACKUP_BUCKET>/backups/2026-10-31_030000/firestore.jsonl.gz
 *   gs://<BACKUP_BUCKET>/backups/2026-10-31_030000/manifest.json
 *
 * مبدأ ثابت: الكود ده مبيمسحش ولا بيعدّل أي نسخة قديمة نهائيًا، بيضيف بس.
 * (والـ Bucket نفسه عليه Retention Policy بتمنع الحذف. شوف docs/BACKUP_SETUP.md)
 *
 * بيغطي كل الـ collections الموجودة (والـ subcollections) تلقائيًا،
 * فأي collection جديدة تتضاف بعدين بتتنسخ من غير تعديل هنا.
 */

const zlib = require('zlib');
const crypto = require('crypto');
const { once } = require('events');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineString } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { serialize } = require('./backup_lib');

const REGION = 'europe-west1';
const BACKUP_BUCKET = defineString('BACKUP_BUCKET');
const PAGE_SIZE = 300;
const META_DOC = ['app_meta', 'last_backup'];

const RUN_OPTIONS = {
  region: REGION,
  timeoutSeconds: 540,
  memory: '512MiB',
  maxInstances: 1,
};

function stamp(d) {
  const p = (n) => String(n).padStart(2, '0');
  return (
    `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}` +
    `_${p(d.getUTCHours())}${p(d.getUTCMinutes())}${p(d.getUTCSeconds())}`
  );
}

/** بتمشي على collection كاملة (وكل subcollections جواها) وبترجّع كل مستند. */
async function* walkCollection(colRef) {
  let last = null;
  for (;;) {
    let q = colRef.orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) return;
    for (const doc of snap.docs) {
      yield doc;
      const subs = await doc.ref.listCollections();
      for (const sub of subs) yield* walkCollection(sub);
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE_SIZE) return;
  }
}

async function writeLine(stream, line) {
  if (!stream.write(line)) await once(stream, 'drain');
}

async function performBackup(trigger) {
  const db = admin.firestore();
  const metaRef = db.collection(META_DOC[0]).doc(META_DOC[1]);
  const startedAt = new Date();
  const folder = `backups/${stamp(startedAt)}`;
  const dataPath = `${folder}/firestore.jsonl.gz`;
  const manifestPath = `${folder}/manifest.json`;

  await metaRef.set(
    {
      status: 'running',
      trigger,
      started_at: admin.firestore.Timestamp.fromDate(startedAt),
    },
    { merge: true },
  );

  try {
    const bucketName = BACKUP_BUCKET.value();
    if (!bucketName) throw new Error('BACKUP_BUCKET غير مضبوط');
    const bucket = admin.storage().bucket(bucketName);

    const gz = zlib.createGzip({ level: 9 });
    const out = bucket.file(dataPath).createWriteStream({
      resumable: false,
      contentType: 'application/gzip',
    });
    const hash = crypto.createHash('sha256');
    let bytes = 0;
    gz.on('data', (c) => {
      hash.update(c);
      bytes += c.length;
    });
    const finished = new Promise((resolve, reject) => {
      out.on('finish', resolve);
      out.on('error', reject);
      gz.on('error', reject);
    });
    gz.pipe(out);

    const counts = {};
    let total = 0;
    const topLevel = await db.listCollections();
    for (const col of topLevel) {
      let n = 0;
      for await (const doc of walkCollection(col)) {
        await writeLine(
          gz,
          JSON.stringify({ path: doc.ref.path, data: serialize(doc.data()) }) + '\n',
        );
        n += 1;
      }
      counts[col.id] = n;
      total += n;
    }
    gz.end();
    await finished;

    // تحقق: الملف موجود وحجمه مطابق لللي كتبناه
    const [meta] = await bucket.file(dataPath).getMetadata();
    if (Number(meta.size) !== bytes) {
      throw new Error(`حجم الملف غير مطابق (${meta.size} بدل ${bytes})`);
    }

    const finishedAt = new Date();
    const manifest = {
      ok: true,
      trigger,
      started_at: startedAt.toISOString(),
      finished_at: finishedAt.toISOString(),
      data_file: dataPath,
      bytes,
      sha256: hash.digest('hex'),
      total_docs: total,
      counts,
    };
    await bucket.file(manifestPath).save(JSON.stringify(manifest, null, 2), {
      contentType: 'application/json',
      resumable: false,
    });

    await metaRef.set({
      status: 'ok',
      trigger,
      started_at: admin.firestore.Timestamp.fromDate(startedAt),
      finished_at: admin.firestore.Timestamp.fromDate(finishedAt),
      path: `gs://${bucketName}/${dataPath}`,
      bytes,
      total_docs: total,
      counts,
      error: null,
    });
    console.log(`Backup OK: ${total} docs, ${bytes} bytes -> ${dataPath}`);
    return manifest;
  } catch (err) {
    console.error('Backup FAILED', err);
    await metaRef.set(
      {
        status: 'failed',
        trigger,
        started_at: admin.firestore.Timestamp.fromDate(startedAt),
        failed_at: admin.firestore.Timestamp.now(),
        error: String((err && err.message) || err).slice(0, 500),
      },
      { merge: true },
    );
    throw err;
  }
}

async function assertAdmin(request) {
  const auth = request.auth;
  if (!auth) throw new HttpsError('unauthenticated', 'لازم تسجّل الدخول.');
  if (auth.token && auth.token.admin === true) return;
  const snap = await admin.firestore().collection('admins').doc(auth.uid).get();
  if (!snap.exists) throw new HttpsError('permission-denied', 'الحساب ده مش أدمن.');
}

exports.dailyBackup = onSchedule(
  { ...RUN_OPTIONS, schedule: '0 3 * * *', timeZone: 'Africa/Cairo' },
  async () => {
    await performBackup('scheduled');
  },
);

exports.runBackupNow = onCall(
  { ...RUN_OPTIONS, enforceAppCheck: true },
  async (request) => {
    await assertAdmin(request);

    // حماية من الضغط المتكرر: لو فيه نسخة بدأت من أقل من دقيقة نرجّع نتيجتها
    const metaSnap = await admin
      .firestore()
      .collection(META_DOC[0])
      .doc(META_DOC[1])
      .get();
    const prev = metaSnap.exists ? metaSnap.data() : null;
    if (prev && prev.status === 'running' && prev.started_at) {
      const age = Date.now() - prev.started_at.toMillis();
      if (age < 60 * 1000) {
        throw new HttpsError('already-exists', 'فيه نسخة شغالة دلوقتي، استنى شوية.');
      }
    }

    try {
      const m = await performBackup('manual');
      return { ok: true, total_docs: m.total_docs, bytes: m.bytes };
    } catch (e) {
      throw new HttpsError('internal', 'فشلت النسخة الاحتياطية. راجع السجلات.');
    }
  },
);
