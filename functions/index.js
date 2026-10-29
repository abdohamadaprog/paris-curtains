'use strict';

/**
 * Cloud Functions لتطبيق ستائر باريس.
 *
 *  - getCloudinarySignature : توقيع رفع صورة (الأدمن فقط + App Check).
 *  - deleteCloudinaryAsset  : حذف صورة من Cloudinary (الأدمن فقط + App Check).
 *
 * الإعدادات:
 *   firebase functions:secrets:set CLOUDINARY_API_SECRET
 *   functions/.env :
 *       CLOUDINARY_API_KEY=...
 *       CLOUDINARY_CLOUD_NAME=...
 *
 * الـ region لازم يطابق lib/core/services/cloudinary_service.dart.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const admin = require('firebase-admin');
const cloudinary = require('cloudinary').v2;

admin.initializeApp();

const REGION = 'europe-west1';

const CLOUDINARY_API_SECRET = defineSecret('CLOUDINARY_API_SECRET');
const CLOUDINARY_API_KEY = defineString('CLOUDINARY_API_KEY');
const CLOUDINARY_CLOUD_NAME = defineString('CLOUDINARY_CLOUD_NAME');

// السيرفر هو اللي بيحدد المسار الفعلي ولا يثق في أي مسار جاي من التطبيق
const FOLDERS = {
  gallery: 'paris_curtains/gallery',
  promo: 'paris_curtains/promo',
};
const ALLOWED_FORMATS = 'jpg,jpeg,png,webp';

const BASE_OPTIONS = {
  region: REGION,
  secrets: [CLOUDINARY_API_SECRET],
  enforceAppCheck: true,
  maxInstances: 5,
};

/** يتأكد إن المستدعي أدمن (custom claim أو مستند admins/{uid}). */
async function assertAdmin(request) {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'لازم تسجّل الدخول.');
  }
  if (auth.token && auth.token.admin === true) return;

  const snap = await admin.firestore().collection('admins').doc(auth.uid).get();
  if (!snap.exists) {
    throw new HttpsError('permission-denied', 'الحساب ده مش أدمن.');
  }
}

exports.getCloudinarySignature = onCall(BASE_OPTIONS, async (request) => {
  await assertAdmin(request);

  const key = request.data && request.data.folder;
  const folder = FOLDERS[key];
  if (!folder) {
    throw new HttpsError('invalid-argument', 'نوع الفولدر غير مسموح.');
  }

  const timestamp = Math.round(Date.now() / 1000);
  // الباراميترات الموقّعة لازم تتبعت للـ Cloudinary بنفس القيم بالظبط
  const paramsToSign = {
    allowed_formats: ALLOWED_FORMATS,
    folder,
    timestamp,
  };
  const signature = cloudinary.utils.api_sign_request(
    paramsToSign,
    CLOUDINARY_API_SECRET.value(),
  );

  return {
    signature,
    timestamp,
    folder,
    allowed_formats: ALLOWED_FORMATS,
    apiKey: CLOUDINARY_API_KEY.value(),
    cloudName: CLOUDINARY_CLOUD_NAME.value(),
  };
});

// حروف مسموحة في public_id (بدون .. أو مسارات غريبة)
const PUBLIC_ID_PATTERN = /^[A-Za-z0-9_\-\/.]+$/;

exports.deleteCloudinaryAsset = onCall(BASE_OPTIONS, async (request) => {
  await assertAdmin(request);

  const publicId = request.data && request.data.publicId;
  if (
    typeof publicId !== 'string' ||
    publicId.length === 0 ||
    publicId.length > 300 ||
    publicId.includes('..') ||
    publicId.startsWith('/') ||
    !PUBLIC_ID_PATTERN.test(publicId)
  ) {
    throw new HttpsError('invalid-argument', 'معرّف الصورة غير صالح.');
  }

  cloudinary.config({
    cloud_name: CLOUDINARY_CLOUD_NAME.value(),
    api_key: CLOUDINARY_API_KEY.value(),
    api_secret: CLOUDINARY_API_SECRET.value(),
    secure: true,
  });

  try {
    const res = await cloudinary.uploader.destroy(publicId, {
      resource_type: 'image',
      invalidate: true,
    });
    // result: "ok" أو "not found" (الاتنين مقبولين: الصورة مبقتش موجودة)
    return { result: res.result };
  } catch (e) {
    console.error('Cloudinary destroy failed', publicId, e);
    throw new HttpsError('internal', 'تعذّر حذف الصورة من Cloudinary.');
  }
});
