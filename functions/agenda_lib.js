'use strict';

/**
 * أدوات التواريخ بتوقيت القاهرة (دوال نقية عشان تتختبر).
 * تواريخ التركيب في Firestore محفوظة كـ Timestamp بتاع يوم التركيب،
 * فبنجيب "يوم كامل" بتوقيت القاهرة: من 12 الفجر لحد 12 الفجر اللي بعده.
 */

const TZ = 'Africa/Cairo';

/** فرق التوقيت (بالمللي ثانية) بين القاهرة وUTC في لحظة معيّنة. */
function cairoOffsetMs(date) {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone: TZ,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
  const p = {};
  for (const part of dtf.formatToParts(date)) p[part.type] = part.value;
  const asUtc = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
  return asUtc - Math.floor(date.getTime() / 1000) * 1000;
}

/** تاريخ اليوم بتوقيت القاهرة بصيغة YYYY-MM-DD. */
function cairoYmd(date = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

/** إضافة أيام لتاريخ YYYY-MM-DD. */
function addDays(ymd, n) {
  const [y, m, d] = ymd.split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + n));
  const p = (x) => String(x).padStart(2, '0');
  return `${t.getUTCFullYear()}-${p(t.getUTCMonth() + 1)}-${p(t.getUTCDate())}`;
}

/** اللحظة اللي بيبدأ فيها اليوم YYYY-MM-DD بتوقيت القاهرة (12 الفجر). */
function cairoMidnight(ymd) {
  const [y, m, d] = ymd.split('-').map(Number);
  const utcMidnight = Date.UTC(y, m - 1, d);
  let off = cairoOffsetMs(new Date(utcMidnight));
  off = cairoOffsetMs(new Date(utcMidnight - off));
  return new Date(utcMidnight - off);
}

/** بداية ونهاية يوم (النهاية غير شاملة). dayOffset: 0 النهاردة، 1 بكرة. */
function cairoDayRange(dayOffset = 0, now = new Date()) {
  const ymd = addDays(cairoYmd(now), dayOffset);
  return { ymd, start: cairoMidnight(ymd), end: cairoMidnight(addDays(ymd, 1)) };
}

/** نص الإشعار من أسماء العملاء. */
function digestText(names, dayLabel) {
  const clean = names.map((n) => String(n || '').trim()).filter(Boolean);
  const shown = clean.slice(0, 5);
  const rest = clean.length - shown.length;
  const title = `📅 تركيبات ${dayLabel} (${names.length})`;
  let body = shown.join(' • ');
  if (!body) body = 'افتح الأجندة للتفاصيل';
  if (rest > 0) body += ` • و${rest} كمان`;
  return { title, body };
}

module.exports = { cairoYmd, addDays, cairoMidnight, cairoDayRange, digestText };
