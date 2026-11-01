# تجهيز التطبيق للرفع على Google Play

## 1) القرارات الثابتة (قبل أول رفع)
| البند | القرار المقترح | ملاحظة |
|---|---|---|
| اسم التطبيق | **باريس للستائر** (و"Paris Curtains" في الوصف) | لازم الكتابة "للستائر" في كل مكان (اللوجو القديم مكتوب "للستار") |
| Application ID | `com.pariscurtains.app` | **مبيتغيرش أبدًا بعد النشر**. الحالي `com.example.paris_curtian_app` مش مقبول على المتجر |
| الأيقونة | `assets/images/app_icon.png` (بدون كتابة) | `dart run flutter_launcher_icons` |

## 2) تغيير الـ Application ID
الكود اتغيّر لـ `com.pariscurtains.app`. الخطوات الكاملة بالترتيب (تسجيل التطبيق في Firebase، `google-services.json`، البصمات، App Check) في **`docs/APP_ID_CHANGE.md`**. نفّذها قبل أي نشر.

## 3) التوقيع (Release signing)
```powershell
keytool -genkey -v -keystore $env:USERPROFILE\paris-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- اعمل `android/key.properties` (مش بيترفع على git):
  ```
  storePassword=...
  keyPassword=...
  keyAlias=upload
  storeFile=C:\\Users\\<you>\\paris-upload-key.jks
  ```
- **احتفظ بنسخة من الـ keystore والباسورد في مكانين آمنين.** لو ضاعوا مش هتقدر تحدّث التطبيق (Play App Signing بيخفف المشكلة لكن لازم تفعّله).
- بناء النسخة: `flutter build appbundle --release` ثم ارفع `build/app/outputs/bundle/release/app-release.aab`.

## 4) مطلوب من جوجل
- **سياسة الخصوصية** (رابط صفحة عامة): التطبيق بيخزّن أسماء وتليفونات وعناوين عملاء، فلازم توضّح إيه بيتخزّن ولمين بيتشارك (Firebase وCloudinary) وإزاي يتمسح.
- **Data safety form:** بيانات شخصية (اسم، تليفون، عنوان) + صور، بتتخزّن على سيرفرات، مفيش بيع بيانات.
- **حساب تجريبي لفريق المراجعة** (إيميل وباسورد أدمن للتجربة) لأن اللوحة محمية بتسجيل دخول.
- لقطات شاشة (على الأقل 2)، وصورة الواجهة 1024×500، وأيقونة 512×512.
- **حسابات جديدة (شخصية):** لازم اختبار مغلق: 12 مختبِر لمدة 14 يوم قبل الإنتاج.

## 5) قبل الرفع
- [ ] `flutter analyze` و`flutter test` بدون أخطاء
- [ ] التطبيق مجرّب على جهاز حقيقي بنسخة release
- [ ] قواعد Firestore منشورة، والنسخ الاحتياطي شغال (`docs/BACKUP_SETUP.md`)
- [ ] ترقية Gradle/AGP/Kotlin (التحذيرات اللي بتظهر) كخطوة منفصلة ومجرّبة
