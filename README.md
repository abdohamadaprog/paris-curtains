# Paris Curtains — تطبيق باريس للستاير

تطبيق Flutter لعرض كتالوج الستائر والإكسسوارات، وإدارة الصور والعروض، ولوحة تحكم خاصة بالإدارة.

## المتطلبات

- Flutter SDK متوافق مع قيد Dart الموجود في `pubspec.yaml`.
- إعداد مشروع Firebase الصحيح للتطبيق، مع تفعيل Firebase Authentication وCloud Firestore.
- حساب Cloudinary، وخطة Blaze على Firebase لتشغيل `functions/` (التفاصيل في `docs/SECURITY_SETUP.md`).
- Node.js 20 لتشغيل ونشر Cloud Functions.

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
- `functions/`: Cloud Functions: توقيع رفع Cloudinary (`getCloudinarySignature`)، حذف الصور (`deleteCloudinaryAsset`)، وسكربت `scripts/set-admin-claim.js`.
- `firestore.rules`: قواعد الأمان (الأدمن + فحص شكل البيانات).

## ملاحظات مهمة قبل النشر

1. قواعد Firestore موجودة في `firestore.rules` (الأدمن بـ custom claim أو مستند `admins/{uid}`، من غير أي إيميل في الكود). خطوات النشر في `docs/SECURITY_SETUP.md`.
2. رفع الصور لـ Cloudinary بتوقيع من Cloud Function (`functions/`) مع Firebase App Check، ولازم تحذف الـ unsigned preset القديم بعد التجربة (التفاصيل في `docs/SECURITY_SETUP.md`).
3. توقيع الإصدار: أنشئ مفتاح توقيع خاص واكتب بياناته في `android/key.properties` (ممنوع يترفع على Git). لو الملف مش موجود، بيتوقّع بمفتاح debug للتجربة بس. الخطوات في `docs/SECURITY_SETUP.md`.
4. طابور الرفع بيحفظ نسخة من كل صورة في فولدر التطبيق نفسه ويمسحها بعد نجاح الرفع، فبيكمّل حتى بعد قفل التطبيق. لو النسخة مش متاحة، بيطلب منك تختار الصورة تاني.
5. الفاتورة بتتحفظ برقم (`PC-YYMMDD-XXXX`) وتاريخ وسجل دفعات وحالة (لم يُدفع/جزئي/مدفوعة)، ومعاها لقطة كاملة للأسعار وقت أول حفظ، فتغيير الأسعار الافتراضية بعدين مبيغيّرش الفواتير القديمة.
6. حذف صورة من المعرض أو العروض بيمسح الملف من Cloudinary كمان (عن طريق `deleteCloudinaryAsset`). لو الحذف فشل (مفيش نت) بيتمسح من Firestore بس، والملف اليتيم بيتشال يدويًا من لوحة Cloudinary.
7. دخول الأدمن مخفي: **ضغطة طويلة على اللوجو في الصفحة الرئيسية** بتفتح صفحة تسجيل الدخول، وفي صفحة التسجيل **ضغطة طويلة على اللوجو** بتفعّل الدخول بالبصمة (لو اتفعّلت قبل كده). ده إخفاء للواجهة بس، مش أمان؛ الأمان الحقيقي في `firestore.rules` وCloud Functions.
8. اللغة: التطبيق عربي فقط (RTL) والنصوص مكتوبة في الشاشات مباشرة. اتشالت مكتبة `easy_localization` لأنها ماكانتش مستخدمة.
9. بعد كل تعديل، شغّل `flutter analyze` والاختبارات وبناء المنصة المستهدفة على جهاز تطوير يحتوي على Flutter SDK.
