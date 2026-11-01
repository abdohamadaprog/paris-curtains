'use strict';

/**
 * تنبيهات أجندة التركيب (إشعارات Firebase على موبايل الأدمن).
 *
 *  - agendaEvening : كل يوم 7 مساءً، تركيبات بكرة.
 *  - agendaMorning : كل يوم 8 صباحًا، تركيبات النهاردة.
 *  - sendAgendaNow : تجربة فورية من التطبيق (الأدمن فقط + App Check).
 *
 * التركيبات اللي مرحلتها "تمت" (٤) مبتتبعتش.
 * الأجهزة بتتسجّل في admin_devices أول ما الأدمن يفتح لوحة الإدارة.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const { cairoDayRange, digestText } = require('./agenda_lib');

const REGION = 'europe-west1';
const STALE_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

const RUN_OPTIONS = { region: REGION, timeoutSeconds: 120, memory: '256MiB', maxInstances: 1 };

/** العملاء المطلوب تركيبهم في يوم معيّن (غير المنتهيين). */
async function clientsForDay(dayOffset) {
  const { start, end, ymd } = cairoDayRange(dayOffset);
  const snap = await admin
    .firestore()
    .collection('clients')
    .where('installation_date', '>=', admin.firestore.Timestamp.fromDate(start))
    .where('installation_date', '<', admin.firestore.Timestamp.fromDate(end))
    .get();

  const names = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const stage =
      typeof d.work_stage === 'number'
        ? d.work_stage
        : d.installation_done === true
          ? 4
          : 1;
    if (stage >= 4) continue; // تمت بالفعل
    names.push(d.name || 'عميل بدون اسم');
  }
  return { names, ymd };
}

async function deviceTokens() {
  const snap = await admin.firestore().collection('admin_devices').get();
  return snap.docs.map((d) => d.id);
}

async function pushToAdmins(title, body, data = {}) {
  const tokens = await deviceTokens();
  if (tokens.length === 0) return { devices: 0, sent: 0 };

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { type: 'agenda', ...data },
    android: { priority: 'high', notification: { channelId: 'agenda' } },
  });

  // نشيل التوكنات الميتة (مش بيانات مستخدم، مجرد عناوين أجهزة)
  const dead = [];
  res.responses.forEach((r, i) => {
    if (!r.success && r.error && STALE_TOKEN_CODES.has(r.error.code)) dead.push(tokens[i]);
  });
  await Promise.all(
    dead.map((t) => admin.firestore().collection('admin_devices').doc(t).delete()),
  );

  return { devices: tokens.length, sent: res.successCount };
}

async function sendDigest(dayOffset, dayLabel) {
  const { names, ymd } = await clientsForDay(dayOffset);
  if (names.length === 0) {
    console.log(`Agenda ${ymd}: مفيش تركيبات، مفيش إشعار`);
    return { clients: 0, devices: 0, sent: 0 };
  }
  const { title, body } = digestText(names, dayLabel);
  const r = await pushToAdmins(title, body, { date: ymd });
  console.log(`Agenda ${ymd}: ${names.length} تركيب → ${r.sent}/${r.devices} جهاز`);
  return { clients: names.length, ...r };
}

exports.agendaEvening = onSchedule(
  { ...RUN_OPTIONS, schedule: '0 19 * * *', timeZone: 'Africa/Cairo' },
  async () => {
    await sendDigest(1, 'بكرة');
  },
);

exports.agendaMorning = onSchedule(
  { ...RUN_OPTIONS, schedule: '0 8 * * *', timeZone: 'Africa/Cairo' },
  async () => {
    await sendDigest(0, 'النهاردة');
  },
);

async function assertAdmin(request) {
  const auth = request.auth;
  if (!auth) throw new HttpsError('unauthenticated', 'لازم تسجّل الدخول.');
  if (auth.token && auth.token.admin === true) return;
  const snap = await admin.firestore().collection('admins').doc(auth.uid).get();
  if (!snap.exists) throw new HttpsError('permission-denied', 'الحساب ده مش أدمن.');
}

exports.sendAgendaNow = onCall(
  { ...RUN_OPTIONS, enforceAppCheck: true },
  async (request) => {
    await assertAdmin(request);
    const day = request.data && request.data.day === 'today' ? 0 : 1;
    const label = day === 0 ? 'النهاردة' : 'بكرة';

    const result = await sendDigest(day, label);
    if (result.clients > 0) return { ...result, test: false };

    // مفيش تركيبات في اليوم ده: نبعت إشعار تجربة عشان تتأكد إن التنبيه واصل
    const r = await pushToAdmins(
      '✅ تجربة التنبيه',
      `التنبيه شغال. مفيش تركيبات ${label} في الأجندة.`,
      { test: '1' },
    );
    return { clients: 0, ...r, test: true };
  },
);
