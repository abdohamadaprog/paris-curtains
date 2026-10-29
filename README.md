# Paris Curtains — تطبيق باريس للستاير

تطبيق Flutter لعرض كتالوج الستائر والإكسسوارات، وإدارة الصور والعروض، ولوحة تحكم خاصة بالإدارة.

## المتطلبات

- Flutter SDK متوافق مع قيد Dart الموجود في `pubspec.yaml`.
- إعداد مشروع Firebase الصحيح للتطبيق، مع تفعيل Firebase Authentication وCloud Firestore.
- إعداد Cloudinary ومراجعة `cloudName` و`uploadPreset` وسياسات الرفع قبل الاستخدام الفعلي.

## التشغيل محليًا

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## أجزاء المشروع

- `lib/features/home/`: الصفحة الرئيسية والمعارض والبحث وعرض الصور.
- `lib/features/admin/`: لوحة الإدارة، إدارة الصور والعروض، التحليلات، ومتابعة طابور الرفع.
- `lib/features/clients/`: إدارة العملاء ومواعيد التركيب وحالة تنفيذ الشغل.
- `lib/core/`: ألوان التطبيق والثيم والمكونات المشتركة.

## ملاحظات مهمة قبل النشر

1. قواعد Firestore موجودة في `firestore.rules` (الأدمن بـ custom claim أو مستند `admins/{uid}`، من غير أي إيميل في الكود). خطوات النشر في `docs/SECURITY_SETUP.md`.
2. رفع الصور لـ Cloudinary بتوقيع من Cloud Function (`functions/`) مع Firebase App Check، ولازم تحذف الـ unsigned preset القديم بعد التجربة (التفاصيل في `docs/SECURITY_SETUP.md`).
3. توقيع الإصدار: أنشئ مفتاح توقيع خاص واكتب بياناته في `android/key.properties` (ممنوع يترفع على Git). لو الملف مش موجود، بيتوقّع بمفتاح debug للتجربة بس. الخطوات في `docs/SECURITY_SETUP.md`.
4. طابور الرفع بيحفظ نسخة من كل صورة في فولدر التطبيق نفسه ويمسحها بعد نجاح الرفع، فبيكمّل حتى بعد قفل التطبيق. لو النسخة مش متاحة، بيطلب منك تختار الصورة تاني.
5. بعد كل تعديل، شغّل `flutter analyze` والاختبارات وبناء المنصة المستهدفة على جهاز تطوير يحتوي على Flutter SDK.
