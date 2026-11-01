/// مفاتيح تشغيل المميزات اللي محتاجة خطة Blaze (Cloud Functions).
///
/// ✦ false (الوضع المجاني / Spark): النسخ الاحتياطي اليدوي من التطبيق، ومفيش
///   تنبيهات أجندة من السيرفر.
/// ✦ true  (بعد ترقية المشروع لـ Blaze ونشر الدوال): نسخة تلقائية يوميًا +
///   تنبيهات الأجندة. شوف docs/BACKUP_SETUP.md وبعدين غيّر القيمة دي لـ true.
class AppFeatures {
  AppFeatures._();

  static const bool cloudFunctionsEnabled = false;
}
