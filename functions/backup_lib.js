'use strict';

/**
 * تحويل بيانات Firestore لـ JSON بدون ما نفقد أي نوع (Timestamp / GeoPoint / Reference ...)،
 * ورجوعها تاني زي ما كانت بالظبط وقت الاسترجاع.
 *
 * دوال نقية (من غير ما نعتمد على firebase-admin) عشان نقدر نختبرها لوحدها.
 */

const TAG = '__t';

function isTimestamp(v) {
  return (
    v &&
    typeof v === 'object' &&
    v.constructor &&
    v.constructor.name === 'Timestamp' &&
    typeof v.seconds === 'number' &&
    typeof v.nanoseconds === 'number'
  );
}

function isGeoPoint(v) {
  return (
    v &&
    typeof v === 'object' &&
    v.constructor &&
    v.constructor.name === 'GeoPoint' &&
    typeof v.latitude === 'number'
  );
}

function isDocRef(v) {
  return (
    v &&
    typeof v === 'object' &&
    v.constructor &&
    v.constructor.name === 'DocumentReference' &&
    typeof v.path === 'string'
  );
}

function isBytes(v) {
  return Buffer.isBuffer(v) || v instanceof Uint8Array;
}

/** Firestore value -> JSON-safe value */
function serialize(v) {
  if (v === null || v === undefined) return null;
  if (typeof v === 'string' || typeof v === 'boolean') return v;
  if (typeof v === 'number') {
    if (Number.isNaN(v)) return { [TAG]: 'num', v: 'NaN' };
    if (v === Infinity) return { [TAG]: 'num', v: 'Infinity' };
    if (v === -Infinity) return { [TAG]: 'num', v: '-Infinity' };
    return v;
  }
  if (isTimestamp(v)) return { [TAG]: 'ts', s: v.seconds, n: v.nanoseconds };
  if (v instanceof Date) {
    const ms = v.getTime();
    return { [TAG]: 'ts', s: Math.floor(ms / 1000), n: (ms % 1000) * 1e6 };
  }
  if (isGeoPoint(v)) return { [TAG]: 'geo', lat: v.latitude, lng: v.longitude };
  if (isDocRef(v)) return { [TAG]: 'ref', path: v.path };
  if (isBytes(v)) return { [TAG]: 'bytes', b64: Buffer.from(v).toString('base64') };
  if (Array.isArray(v)) return v.map(serialize);
  if (typeof v === 'object') {
    const out = {};
    for (const k of Object.keys(v)) out[k] = serialize(v[k]);
    // لو map عادي فيه مفتاح اسمه __t نلفّه عشان مايتلخبطش مع الأنواع
    if (Object.prototype.hasOwnProperty.call(out, TAG)) {
      return { [TAG]: 'map', v: out };
    }
    return out;
  }
  return String(v);
}

/**
 * JSON value -> Firestore value.
 * ctx = { Timestamp, GeoPoint, db }  (من firebase-admin)
 */
function deserialize(v, ctx) {
  if (v === null || typeof v !== 'object') return v;
  if (Array.isArray(v)) return v.map((x) => deserialize(x, ctx));
  if (Object.prototype.hasOwnProperty.call(v, TAG)) {
    switch (v[TAG]) {
      case 'ts':
        return new ctx.Timestamp(v.s, v.n);
      case 'geo':
        return new ctx.GeoPoint(v.lat, v.lng);
      case 'ref':
        return ctx.db.doc(v.path);
      case 'bytes':
        return Buffer.from(v.b64, 'base64');
      case 'num':
        return Number(v.v);
      case 'map': {
        const m = {};
        for (const k of Object.keys(v.v)) m[k] = deserialize(v.v[k], ctx);
        return m;
      }
      default:
        break;
    }
  }
  const out = {};
  for (const k of Object.keys(v)) out[k] = deserialize(v[k], ctx);
  return out;
}

module.exports = { serialize, deserialize };
