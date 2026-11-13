/// إعدادات الخدمات الخارجية اللي التطبيق بيستخدمها مباشرة.
///
/// التطبيق شغال على خطة Firebase Spark (مفيش Cloud Functions)، لكل الخدمات
/// هنا بتشتغل من غير سيرفر: رفع الصور على Cloudinary بـ unsigned preset،
/// والنسخ الاحتياطي/تنبيهات تليجرام بـ HTTP مباشر.
class AppFeatures {
  AppFeatures._();

  /// اسم حساب Cloudinary (Cloud name) — مطلوب للرفع المباشر.
  /// تلاقيه في Cloudinary Console فوق على الشمال.
  /// مثال: `dxxxxxx`.
  static const String cloudinaryCloudName = 'napbqzng';

  /// اسم الـ unsigned upload preset في Cloudinary.
  /// لازم يكون من نوع **Unsigned** ومحدد له folder = `paris_curtains`.
  static const String unsignedUploadPreset = 'curtains_upload';
}
