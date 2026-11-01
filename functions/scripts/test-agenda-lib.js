'use strict';
const assert = require('assert');
const { cairoYmd, addDays, cairoMidnight, cairoDayRange, digestText } = require('../agenda_lib');

// القاهرة شتاءً = UTC+2 (نهاية أكتوبر 2026 الساعة بترجع لـ UTC+2 بعد آخر خميس في أكتوبر)
assert.strictEqual(cairoMidnight('2026-01-15').toISOString(), '2026-01-14T22:00:00.000Z');
// صيفًا = UTC+3
assert.strictEqual(cairoMidnight('2026-07-15').toISOString(), '2026-07-14T21:00:00.000Z');

// اللحظة 22:30 UTC يوم 14/1 = 00:30 القاهرة يوم 15/1
assert.strictEqual(cairoYmd(new Date('2026-01-14T22:30:00Z')), '2026-01-15');
assert.strictEqual(cairoYmd(new Date('2026-01-14T21:30:00Z')), '2026-01-14');

assert.strictEqual(addDays('2026-01-31', 1), '2026-02-01');
assert.strictEqual(addDays('2026-12-31', 1), '2027-01-01');
assert.strictEqual(addDays('2026-03-01', -1), '2026-02-28');

// "بكرة" لو دلوقتي 19:00 القاهرة (17:00 UTC شتاءً)
const r = cairoDayRange(1, new Date('2026-01-15T17:00:00Z'));
assert.strictEqual(r.ymd, '2026-01-16');
assert.strictEqual(r.start.toISOString(), '2026-01-15T22:00:00.000Z');
assert.strictEqual(r.end.toISOString(), '2026-01-16T22:00:00.000Z');

// يوم تغيير التوقيت: اليوم بيكون 23 أو 25 ساعة، والحدود لسه صح
const dst = cairoDayRange(0, new Date('2026-10-29T10:00:00Z'));
assert.ok(dst.end > dst.start);

const t = digestText(['أحمد', 'محمد', 'سارة', 'منى', 'هدى', 'علي', 'نور'], 'بكرة');
assert.strictEqual(t.title, '📅 تركيبات بكرة (7)');
assert.ok(t.body.endsWith('و2 كمان'));
assert.strictEqual(digestText([''], 'النهاردة').body, 'افتح الأجندة للتفاصيل');

console.log('OK: agenda_lib');
