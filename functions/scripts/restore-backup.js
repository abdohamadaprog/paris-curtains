'use strict';

/**
 * استرجاع نسخة احتياطية في Firestore.
 *
 * الاستخدام (PowerShell):
 *   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\service-account.json"
 *   cd functions
 *   node scripts/restore-backup.js <المصدر> [خيارات]
 *
 * المصدر:
 *   gs://BUCKET/backups/2026-10-31_030000/firestore.jsonl.gz   (من Cloud Storage)
 *   أو مسار ملف محلي .jsonl.gz (لو نزّلته)
 *
 * الخيارات:
 *   --dry-run          يعدّ بس ومبيكتبش حاجة (جرّب بيه الأول)
 *   --overwrite        يكتب فوق المستندات الموجودة (الافتراضي: يتخطاها ومبيلمسش الموجود)
 *   --only=clients,settings   يسترجع collections معيّنة بس
 *   --project=parisapp-7c377  (اختياري) رقم المشروع
 */

const fs = require('fs');
const zlib = require('zlib');
const readline = require('readline');
const admin = require('firebase-admin');
const { deserialize } = require('../backup_lib');

const args = process.argv.slice(2);
const source = args.find((a) => !a.startsWith('--'));
const flag = (name) => args.includes(`--${name}`);
const opt = (name) => {
  const a = args.find((x) => x.startsWith(`--${name}=`));
  return a ? a.split('=').slice(1).join('=') : null;
};

if (!source) {
  console.error('لازم تحدد المصدر. شوف الشرح في أول الملف.');
  process.exit(1);
}

const dryRun = flag('dry-run');
const overwrite = flag('overwrite');
const only = opt('only') ? new Set(opt('only').split(',').map((s) => s.trim())) : null;
const project = opt('project');

admin.initializeApp(project ? { projectId: project } : undefined);
const db = admin.firestore();
const ctx = { Timestamp: admin.firestore.Timestamp, GeoPoint: admin.firestore.GeoPoint, db };

function openSource() {
  if (source.startsWith('gs://')) {
    const rest = source.slice(5);
    const slash = rest.indexOf('/');
    const bucket = rest.slice(0, slash);
    const file = rest.slice(slash + 1);
    return admin.storage().bucket(bucket).file(file).createReadStream();
  }
  return fs.createReadStream(source);
}

async function main() {
  const rl = readline.createInterface({
    input: openSource().pipe(zlib.createGunzip()),
    crlfDelay: Infinity,
  });

  let batch = db.batch();
  let pending = 0;
  const stats = { read: 0, written: 0, skippedExisting: 0, skippedFilter: 0 };

  async function flush() {
    if (pending === 0) return;
    if (!dryRun) await batch.commit();
    stats.written += pending;
    batch = db.batch();
    pending = 0;
  }

  for await (const line of rl) {
    if (!line.trim()) continue;
    const { path, data } = JSON.parse(line);
    stats.read += 1;

    const topCollection = path.split('/')[0];
    if (only && !only.has(topCollection)) {
      stats.skippedFilter += 1;
      continue;
    }

    const ref = db.doc(path);
    if (!overwrite) {
      const exists = (await ref.get()).exists;
      if (exists) {
        stats.skippedExisting += 1;
        continue;
      }
    }

    batch.set(ref, deserialize(data, ctx));
    pending += 1;
    if (pending >= 400) await flush();
  }
  await flush();

  console.log(dryRun ? '--- تجربة فقط (مفيش كتابة) ---' : '--- تم الاسترجاع ---');
  console.log(`مستندات في النسخة : ${stats.read}`);
  console.log(`${dryRun ? 'هتتكتب' : 'اتكتبت'}            : ${stats.written}`);
  console.log(`موجودة وتم تخطيها : ${stats.skippedExisting}`);
  console.log(`خارج الفلتر        : ${stats.skippedFilter}`);
}

main().catch((e) => {
  console.error('فشل الاسترجاع:', e);
  process.exit(1);
});
