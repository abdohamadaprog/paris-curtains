# تغيير معرّف التطبيق (applicationId) قبل النشر

الاسم الحالي `com.example.paris_curtian_app` اسم تجريبي، ومعرّف التطبيق بيتثبّت للأبد بعد النشر على Google Play. المقترح: `com.pariscurtains.app`.

> لا تغيّره في الكود قبل ما تعمل خطوة 1 و2، وإلا بيلد أندرويد هيفشل (ملف `google-services.json` لازم يطابق المعرّف).

1. Firebase Console ← Project settings ← Your apps ← **Add app (Android)** بالمعرّف الجديد.
2. نزّل `google-services.json` الجديد وحطه مكان القديم في `android/app/`.
3. شغّل `flutterfire configure` عشان يتحدّث `lib/firebase_options.dart`.
4. في `android/app/build.gradle.kts` غيّر `namespace` و`applicationId` للمعرّف الجديد.
5. انقل `MainActivity.kt` من `android/app/src/main/kotlin/com/example/paris_curtian_app/` إلى `.../kotlin/com/pariscurtains/app/` وغيّر أول سطر `package com.pariscurtains.app`.
6. ضيف بصمة SHA-256 لمفتاح التوقيع للتطبيق الجديد (Project settings) وسجّله في App Check.
7. `flutter clean && flutter pub get && flutter run`.

التطبيق الجديد في Firebase يعني إن الحساب والبيانات (Firestore/Auth) هي هي، لكن النسخة المثبتة القديمة بتعتبر تطبيق مختلف.
