# قبل الرفع: اللي لازم يتقفل (مرتب بالأهمية)

## 🔴 يوقّف البيلد أو الرفع لو مااتعملش
1. **google-services.json لسه بالمعرّف القديم.** `build.gradle.kts` على `com.pariscurtains.app` لكن `android/app/google-services.json` فيه `com.example.paris_curtian_app` (وكمان `lib/firebase_options.dart` و`firebase.json` appId القديم). بيلد أندرويد هيفشل. نفّذ خطوات 1–3 من `docs/APP_ID_CHANGE.md` (Add app في Firebase ← نزّل google-services.json الجديد ← `flutterfire configure`).
2. **رفع الصور وحذفها محتاجين Cloud Functions (خطة Blaze).** `CloudinaryService` بينادي `getCloudinarySignature` دايمًا، و`docs/FREE_MODE.md` بيقول المشروع على Spark. من غير Blaze + نشر الدوال، رفع صور المعرض/العروض مش هيشتغل. اترقّى لـ Blaze وانفّذ `docs/SECURITY_SETUP.md` (خطوة 4) و`docs/BACKUP_SETUP.md`، وبعدها غيّر `AppFeatures.cloudFunctionsEnabled = true`.
3. **مفتاح التوقيع.** من غير `android/key.properties` الإصدار بيتوقّع بمفتاح debug ومينفعش للمتجر (`docs/SECURITY_SETUP.md` خطوة 7).

## 🟠 ترتيب النشر (مهم)
1. اعمل مستند `admins/{uid}` الأول، وبعدين `firebase deploy --only firestore:rules`.
2. اختبر: دخول الأدمن، إضافة/تعديل/أرشفة عميل، رفع صورة، تعديل ترتيب المعرض، حفظ الأسعار.
3. App Check: سجّل Play Integrity + بصمة **App signing key** من Play Console + debug token. راقب كام يوم قبل Enforce.
4. بعد نجاح رفع الصور: احذف الـ unsigned preset `curtains_upload` من Cloudinary.

## 🟡 متطلبات Google Play
سياسة خصوصية (رابط عام) · Data safety · حساب أدمن تجريبي للمراجعة · لقطات شاشة (2+) · Feature graphic 1024×500 · أيقونة 512 (جاهزة: `branding/play_store_icon_512.png`) · اختبار مغلق 12 مختبِر × 14 يوم للحسابات الشخصية الجديدة.

## 🟢 تحسينات
- اللوجو جوه التطبيق (`assets/images/logo.png`: السبلاش والفوتر وصورة الفاتورة) لسه الشكل القديم (خلفية كحلي + برج إيفل). وحّده مع الأيقونة الجديدة (أسود/ذهبي).
- اعمل custom claim للأدمن (`npm run set-admin`) عشان القواعد متقراش `admins/{uid}` في كل طلب (توفير قراءات).
- iOS: `PRODUCT_BUNDLE_IDENTIFIER` لسه `com.example.parisCurtianApp` لو هتنشر على App Store.
- ضيف Crashlytics (مكانه جاهز في `main.dart`).
- شغّل `flutter analyze` و`flutter test` على جهازك (مااتشغلوش هنا).
