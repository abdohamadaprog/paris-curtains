# إعداد الأمان وتشغيله فعليًا

> الترتيب مهم. لو نشرت الـ Rules قبل ما تعمل مستند الأدمن (الخطوة 1)، هتتقفل برا بياناتك لحد ما ترجّع القواعد القديمة.

## 0) تجهيز
```bash
flutter pub get          # firebase_app_check وcloud_functions متضافين في pubspec.yaml أصلًا
npm install -g firebase-tools
firebase login
```
ملف `.firebaserc` جاهز على المشروع `parisapp-7c377`.

## 1) اعمل الأدمن (قبل أي نشر)
1. Firebase Console ← Authentication ← Users ← انسخ **User UID** لحسابك.
2. Firestore Database ← Start collection ← اسمها `admins` ← Document ID = الـ UID اللي نسخته ← أي حقل (مثلًا `role` = `owner`).

بديل بدون قراءة إضافية من Firestore (اختياري): custom claim.
```bash
cd functions && npm install
# PowerShell:
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\service-account.json"
node scripts/set-admin-claim.js your-email@example.com
```
(بعدها تعمل خروج ودخول عشان التوكن يتجدد.)

## 2) انشر القواعد والفهارس
```bash
firebase deploy --only firestore:rules,firestore:indexes
```
اختبار: سجّل دخول من التطبيق ← العملاء بتظهر وتتعدّل. وجرّب حساب مش أدمن: لازم يترفض.

## 3) App Check (من غير Enforce لسه)
1. Firebase Console ← App Check ← Apps ← سجّل تطبيق Android بـ **Play Integrity**.
2. Project settings ← Your apps ← ضيف **SHA-256** بتاع توقيع التطبيق.
3. شغّل التطبيق debug ← هتلاقي في اللوج `Firebase App Check debug token` ← ضيفه في App Check ← Manage debug tokens.
4. سيب التطبيق يشتغل كام يوم وراقب App Check ← Metrics: لازم أغلب الطلبات تبقى Verified.

## 4) Cloud Function للرفع الموقّع (محتاجة خطة Blaze)
```bash
cd functions
npm install
firebase functions:secrets:set CLOUDINARY_API_SECRET
```
وانسخ `functions/.env.example` إلى `functions/.env` واكتب فيه:
```
CLOUDINARY_API_KEY=ضع_الـAPI_key_هنا
CLOUDINARY_CLOUD_NAME=ضع_اسم_الـcloud_هنا
```
(الـ API key والـ secret من Cloudinary ← Settings ← API Keys، واسم الـ cloud من لوحة Cloudinary الرئيسية.)
```bash
firebase deploy --only functions
```
النشر بيرفع دالتين: `getCloudinarySignature` (توقيع الرفع) و`deleteCloudinaryAsset` (حذف الصورة من Cloudinary عند حذفها من التطبيق). الاتنين للأدمن فقط ومعاهم `enforceAppCheck: true`، والـ region لازم يفضل `europe-west1` (مطابق لـ `lib/core/services/cloudinary_service.dart`).

ملحوظة: الدالة `enforceAppCheck: true`، فلازم الخطوة 3 تكون خلصت (وتوكن الـ debug متضاف) قبل ما الرفع يشتغل من التطبيق.

## 5) قفل Cloudinary
بعد ما تجرّب رفع صورة معرض وصورة عرض ويشتغلوا:
- Cloudinary ← Settings ← Upload ← Upload presets ← **احذف أو عطّل** `curtains_upload` (الـ unsigned preset المكشوف). لو سيبته شغال، أي حد يطلّعه من الـ APK يقدر يرفع على حسابك.
- مفيش حاجة لازم تتغير في التطبيق: هو دلوقتي بيرفع بتوقيع من الدالة، والدالة بتفرض الفولدر والصيغ المسموحة.

## 6) تفعيل الحماية (Enforce)
بعد أيام من المراقبة وتأكدك إن طلباتك Verified: App Check ← APIs ← **Cloud Firestore** ← Enforce.
- لو بتوزّع التطبيق كملف APK مباشرة (مش من Google Play)، جرّب الأول على نسخة release متثبتة بنفس طريقتك قبل الـ Enforce: Play Integrity ممكن يرفض التطبيقات المثبتة من خارج المتجر.

## 7) مفتاح توقيع الإصدار (بدل debug)
```bash
keytool -genkey -v -keystore D:\keys\paris-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias paris
```
اكتب ملف `android/key.properties` (مش بيترفع على Git):
```
storePassword=كلمة_السر
keyPassword=كلمة_السر
keyAlias=paris
storeFile=D:\\keys\\paris-release.jks
```
- خد نسخة احتياطية من الملف `.jks` وكلمة السر. لو ضاعوا، مش هتقدر تحدّث التطبيق.
- هات بصمة SHA-256: `keytool -list -v -keystore D:\keys\paris-release.jks -alias paris` وضيفها في Firebase ← Project settings ← Your apps (دي اللي App Check والـ Play Integrity بيعتمدوا عليها).
- أول مرة هتغيّر التوقيع، لازم تمسح النسخة القديمة من الموبايل وتثبّت الجديدة (أندرويد مبيقبلش تحديث بتوقيع مختلف).
- لو هترفع على Google Play، البصمة اللي لازم تتضاف هي بصمة **App signing key** من Play Console.
- التطبيق لسه مسجّل بالاسم `com.example.paris_curtian_app` (اسم تجريبي). غيّره قبل النشر الرسمي، بس ده محتاج تسجيل التطبيق من جديد في Firebase وتحميل `google-services.json` الجديد.

## الفهارس
`firestore.indexes.json` فاضي لأن الاستعلامات الحالية كلها على حقل واحد (فهرسه تلقائي). لما تضيف استعلام فيه `where` مع `orderBy` على حقلين مختلفين، Firestore هيطلّع في اللوج رابط لعمل الفهرس، وتضيفه هنا بعدها.

## رجوع سريع لو حصلت مشكلة
Firebase Console ← Firestore ← Rules ← History ← اختر النسخة القديمة ← Publish.
