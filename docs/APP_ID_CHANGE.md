# تغيير Application ID إلى `com.pariscurtains.app`

الـ ID القديم `com.example.paris_curtian_app` (تجريبي ومش مقبول على Google Play).
الجديد **`com.pariscurtains.app`**. بعد أول نشر مبيتغيرش أبدًا.

> الكود (`build.gradle.kts` و`MainActivity.kt`) اتغيّر بالفعل في الملفات المرفقة.
> **متطبّقش الملفات دي قبل الخطوتين 1 و2 تحت**، لأن Firebase لازم يعرف الـ ID الجديد الأول،
> وإلا البناء هيفشل برسالة `No matching client found for package name`.

اللي **مش** بيتغيّر: اسم الحزمة في `pubspec.yaml` (`paris_curtian_app`) وكل الـ imports اللي بتبدأ بـ
`package:paris_curtian_app/...`. ده اسم حزمة Dart مش الـ ID بتاع المتجر.

## 1) سجّل التطبيق الجديد في Firebase
Firebase Console ← **Project settings** ← **Your apps** ← **Add app** ← **Android**
- Package name: `com.pariscurtains.app`
- Nickname: `Paris Curtains`
- دوس Register ثم **نزّل `google-services.json`** وأوقف عند هنا (باقي خطوات الـ wizard جاهزة في المشروع).

سيب التطبيق القديم مسجّل زي ما هو. ملهوش ضرر.

## 2) حدّث إعدادات Firebase في المشروع
1. استبدل `android/app/google-services.json` بالملف الجديد.
2. افتح الملف الجديد وخد منه قيمتين:
   - `client[0].client_info.mobilesdk_app_id` (شكلها `1:881801623559:android:xxxxxxxx`)
   - `client[0].api_key[0].current_key`
3. في `lib/firebase_options.dart`، **جوه `static const FirebaseOptions android` بس**، غيّر:
   ```dart
   static const FirebaseOptions android = FirebaseOptions(
     apiKey: '<current_key من الملف الجديد>',
     appId: '<mobilesdk_app_id من الملف الجديد>',
     // باقي الحقول زي ما هي (messagingSenderId, projectId, storageBucket)
   );
   ```
   (أو شغّل `flutterfire configure` لو منزّله، بيعمل نفس الشيء.)

## 3) طبّق ملفات الكود
فك الـ `app_id_change.zip` فوق المشروع، وبعدها **امسح الفولدر القديم**:
```
android/app/src/main/kotlin/com/example
```
(MainActivity اتنقلت لـ `android/app/src/main/kotlin/com/pariscurtains/app/`.)

## 4) البصمات (SHA)
بصمة الـ debug:
```powershell
keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```
أضف **SHA-1 و SHA-256** في Firebase ← Project settings ← التطبيق الجديد ← Add fingerprint.

لما ترفع على Play: خد بصمة **App signing key** من Play Console ← App integrity وضيفها بنفس الطريقة (وبصمة upload key كمان).

## 5) App Check للتطبيق الجديد
Firebase Console ← **App Check** ← Apps ← سجّل `com.pariscurtains.app` بـ **Play Integrity**.

للتجربة (debug): أول ما تشغّل التطبيق هتلاقي في اللوج سطر `Enter this debug secret into the allow list...`.
خد التوكن وضيفه في App Check ← التطبيق الجديد ← **Manage debug tokens**.
من غير ده رفع الصور والنسخ الاحتياطي والتنبيهات (Cloud Functions) هترفض في وضع debug.

## 6) شغّل وجرّب
```powershell
flutter clean
flutter pub get
flutter run
```
- **امسح التطبيق القديم من التليفون** (ده تطبيق مختلف عن الجديد، وهيفضلوا الاتنين جنب بعض لو مسحتوش).
- بياناتك على Firebase (العملاء والفواتير) مش بتتأثر، لأنها مرتبطة بالمشروع مش بالتطبيق.

اختبر: دخول الأدمن، رفع صورة، "نسخة احتياطية الآن"، "جرّب التنبيه الآن".
(الإشعارات: افتح لوحة الإدارة مرة عشان التطبيق الجديد يسجّل توكن جهازه.)

## لو ظهرت مشكلة
| الخطأ | السبب |
|---|---|
| `No matching client found for package name 'com.pariscurtains.app'` | `google-services.json` لسه القديم (الخطوة 2) |
| الرفع أو الدوال بترفض / `app-check` | التطبيق الجديد مش مسجّل في App Check أو debug token ناقص (الخطوة 5) |
| `Duplicate class` أو `MainActivity not found` | فولدر `kotlin/com/example` القديم لسه موجود، أو MainActivity الجديدة مش في مكانها (الخطوة 3) |
| الإشعارات مش بتوصل | افتح لوحة الإدارة وامنح الإذن عشان يتسجّل توكن الجهاز الجديد |
