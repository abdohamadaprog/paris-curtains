/// مفاتيح تشغيل/إيقاف الميزات اللي محتاجة خطة Blaze (Cloud Functions).
///
/// لو `false` (خطة Spark): مفيش تنبيهات ولا نسخ احتياطي على السيرفر،
/// والرفع بيتم مباشرة على Cloudinary بـ unsigned preset.
/// لو `true` (بعد ترقية Blaze ورفع الدوال): توقيع الرفع + حذف الصور + التنبيهات.
class AppFeatures {
  AppFeatures._();

  /// لازم تكون `true` بعد `firebase deploy --only functions`.
  static const bool cloudFunctionsEnabled = false;

  /// اسم حساب Cloudinary (Cloud name) — مطلوب للرفع المباشر.
  /// تلاقيه في Cloudinary Console فوق على الشمال.
  /// مثال: `dxxxxxx`.
  static const String cloudinaryCloudName = 'napbqzng';

  /// اسم الـ unsigned upload preset في Cloudinary.
  /// لازم يكون من نوع **Unsigned** ومحدد له folder = `paris_curtains`.
  static const String unsignedUploadPreset = 'curtains_upload';
}
