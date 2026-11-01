'use strict';
// اختبار بسيط: serialize ثم deserialize لازم يرجّع نفس البيانات بالظبط.
const assert = require('assert');
const { serialize, deserialize } = require('../backup_lib');

class Timestamp { constructor(s, n) { this.seconds = s; this.nanoseconds = n; } }
class GeoPoint { constructor(a, b) { this.latitude = a; this.longitude = b; } }
class DocumentReference { constructor(p) { this.path = p; } }
const db = { doc: (p) => new DocumentReference(p) };
const ctx = { Timestamp, GeoPoint, db };

const original = {
  name: 'أحمد',
  total: 14625.5,
  nan: NaN,
  inf: Infinity,
  nothing: null,
  done: true,
  created: new Timestamp(1761864000, 123000000),
  place: new GeoPoint(30.46, 31.18),
  ref: new DocumentReference('clients/abc'),
  bytes: Buffer.from([1, 2, 3, 250]),
  list: [1, 'x', new Timestamp(5, 6), { deep: new GeoPoint(1, 2) }],
  tricky: { __t: 'ts', s: 1 },
  nested: { a: { b: { c: [new Timestamp(9, 9)] } } },
};

const json = JSON.parse(JSON.stringify(serialize(original)));
const back = deserialize(json, ctx);

assert.strictEqual(back.name, 'أحمد');
assert.strictEqual(back.total, 14625.5);
assert.ok(Number.isNaN(back.nan));
assert.strictEqual(back.inf, Infinity);
assert.strictEqual(back.nothing, null);
assert.ok(back.created instanceof Timestamp);
assert.strictEqual(back.created.seconds, 1761864000);
assert.strictEqual(back.created.nanoseconds, 123000000);
assert.ok(back.place instanceof GeoPoint && back.place.longitude === 31.18);
assert.ok(back.ref instanceof DocumentReference && back.ref.path === 'clients/abc');
assert.deepStrictEqual([...back.bytes], [1, 2, 3, 250]);
assert.ok(back.list[2] instanceof Timestamp);
assert.ok(back.list[3].deep instanceof GeoPoint);
assert.deepStrictEqual(back.tricky, { __t: 'ts', s: 1 }); // map عادي فيه مفتاح __t مش بيتلخبط
assert.ok(back.nested.a.b.c[0] instanceof Timestamp);

console.log('OK: serialize/deserialize roundtrip');
