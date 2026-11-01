# الوضع المجاني (خطة Spark، من غير بطاقة دفع)

المشروع على الخطة المجانية، فكل اللي بيحتاج **Cloud Functions** مش شغّال لحد ما تترقّى لـ Blaze.

| الميزة | الوضع المجاني | بعد Blaze |
|---|---|---|
| الأرشيف (مفيش حذف نهائي للعملاء) | ✅ شغّال | ✅ |
| القواعد (Rules) | ✅ شغّال | ✅ |
| الخصم وصورة الفاتورة وثوابت الحساب | ✅ شغّال | ✅ |
| **نسخة احتياطية** | ✅ **يدوية** من التطبيق (زرار + تذكير أسبوعي) | ✅ تلقائية يوميًا |
| تنبيهات الأجندة (إشعارات من السيرفر) | ❌ متوقفة | ✅ |

## اللي تنفّذه دلوقتي
انشر **القواعد بس** (الدوال مش هتتنشر على Spark وهتدّي خطأ):
```powershell
firebase deploy --only firestore:rules
```
(متشغّلش `--only functions` ولا deploy كامل.)

لا تحتاج bucket ولا gcloud ولا `functions/.env` في الوضع ده.

## النسخة اليدوية
لوحة الإدارة ← **النسخ الاحتياطي والأرشيف** ← **تصدير نسخة احتياطية الآن**.
هيجهّز ملف `paris_backup_<تاريخ>.jsonl.gz` فيه كل العملاء والمقاسات والفواتير والأرشيف والأسعار، وتبعته لنفسك:
- واتساب (محادثة مع نفسك) أو Google Drive أو الإيميل.
- **احفظ آخر 3 نسخ على الأقل** في مكانين مختلفين.

لازم تكون متصل بالنت (التطبيق بيقرا من السيرفر عشان النسخة متطلعش ناقصة). لو الشبكة وقعت في النص هيقولك وتعيد.
التطبيق بيفكّرك لما يعدّي أسبوع من غير نسخة.

## الاسترجاع (لو حصل مشكلة)
الاسترجاع بيتم من الكمبيوتر بسكريبت `functions/scripts/restore-backup.js` (مجاني، محتاج Node.js):
1. Firebase Console ← Project settings ← **Service accounts** ← **Generate new private key** (نزّل الملف وخبّيه، وماترفعوش على git).
2. ```powershell
   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\service-account.json"
   cd functions
   npm install
   # تجربة من غير كتابة
   node scripts/restore-backup.js "C:\path\paris_backup_2026-11-02_2110.jsonl.gz" --dry-run
   # استرجاع حقيقي (بيرجّع الناقص بس ومبيلمسش الموجود)
   node scripts/restore-backup.js "C:\path\paris_backup_2026-11-02_2110.jsonl.gz"
   ```
   ممكن تحدد collections معيّنة: `--only=clients` أو تكتب فوق الموجود بـ `--overwrite` (بحذر).

## لما تترقّى لـ Blaze
1. نفّذ `docs/BACKUP_SETUP.md` (الـ bucket، `.env`، نشر القواعد والدوال).
2. غيّر في `lib/core/config/app_features.dart`:
   ```dart
   static const bool cloudFunctionsEnabled = true;
   ```
3. ابني التطبيق من جديد. هيظهر النسخ التلقائي وتنبيهات الأجندة، والنسخة اليدوية تختفي.
