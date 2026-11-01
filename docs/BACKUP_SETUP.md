# النسخ الاحتياطي: التشغيل والاسترجاع

الفكرة: **مفيش بيانات بتتمسح نهائي، وفيه 3 طبقات حماية.**

| الطبقة | بتحمي من إيه | مدتها |
|---|---|---|
| **أرشيف العملاء** (جوه التطبيق) | حذف عميل بالغلط | دايمًا |
| **نسخة يومية JSON** (Cloud Function ← Storage) | أي خطأ أو مسح بيانات | سنة على الأقل (Retention) |
| **Firestore PITR + Backup Schedule** (من جوجل) | رجوع قاعدة البيانات لأي لحظة | 7 أيام PITR + 14 أسبوع نسخ |

> محتاج خطة Blaze (عندك بالفعل لأن الـ Functions شغالة). التكلفة لحجم بيانات زي بتاعك: قروش في الشهر.

كل الأوامر في PowerShell، ومعاك `gcloud` (https://cloud.google.com/sdk/docs/install) وعامل `gcloud auth login` و`gcloud config set project parisapp-7c377`.

## 1) Bucket النسخ (مع منع الحذف)
```powershell
gcloud storage buckets create gs://parisapp-7c377-backups --location=europe-west1 --uniform-bucket-level-access --public-access-prevention

# مفيش حد (ولا حتى إنت) يقدر يمسح أو يعدّل أي نسخة قبل سنة
gcloud storage buckets update gs://parisapp-7c377-backups --retention-period=31536000s
```
- **متعملش** `--lock-retention-period` دلوقتي: القفل مبيتفكش أبدًا. ممكن تقفله بعد ما تتأكد إن كل حاجة شغالة.

صلاحية الدالة: تكتب وتقرا بس (من غير حذف):
```powershell
$SA = "881801623559-compute@developer.gserviceaccount.com"
gcloud storage buckets add-iam-policy-binding gs://parisapp-7c377-backups --member="serviceAccount:$SA" --role="roles/storage.objectCreator"
gcloud storage buckets add-iam-policy-binding gs://parisapp-7c377-backups --member="serviceAccount:$SA" --role="roles/storage.objectViewer"
```

## 2) إعداد الدالة
ضيف في `functions/.env` (جنب بيانات Cloudinary):
```
BACKUP_BUCKET=parisapp-7c377-backups
```
ثم انشر القواعد والدوال (القواعد الأول مهمة، فيها الأرشيف وحالة النسخ):
```powershell
firebase deploy --only firestore:rules,functions
```
هيتنشر: `dailyBackup` (كل يوم 3 الفجر بتوقيت القاهرة) و`runBackupNow` (زرار التطبيق).

## 3) طبقة جوجل (مستقلة عن الكود بتاعنا)
```powershell
# رجوع لأي لحظة في آخر 7 أيام
gcloud firestore databases update --database="(default)" --enable-pitr

# نسخة يومية بتفضل 14 أسبوع
gcloud firestore backups schedules create --database="(default)" --recurrence=daily --retention=14w
```
(لو صيغة الأوامر اتغيّرت عندك، نفس الإعدادين متاحين في Firebase Console ← Firestore ← Disaster recovery.)

## 4) جرّب
1. التطبيق ← لوحة الإدارة ← **النسخ الاحتياطي والأرشيف** ← **نسخة احتياطية الآن**.
2. لازم تظهر "آخر نسخة ناجحة" وعدد المستندات.
3. في Cloud Storage ← `parisapp-7c377-backups` ← `backups/<التاريخ>/` هتلاقي `firestore.jsonl.gz` و`manifest.json`.

لو الحالة بقت **"قديمة"** (برتقالي) أو **"فشلت"** (أحمر) في التطبيق، معناها النسخة التلقائية مش شغالة: شوف `firebase functions:log`.

## 5) الاسترجاع
محتاج ملف مفتاح حساب الخدمة (نفس اللي بتستخدمه في `set-admin`):
```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\service-account.json"
cd functions
npm install

# تجربة بس (مبيكتبش حاجة): بيقولك هيرجّع كام مستند
node scripts/restore-backup.js gs://parisapp-7c377-backups/backups/2026-10-31_010000/firestore.jsonl.gz --dry-run

# استرجاع حقيقي: بيرجّع المستندات الناقصة بس ومبيلمسش الموجود
node scripts/restore-backup.js gs://parisapp-7c377-backups/backups/2026-10-31_010000/firestore.jsonl.gz

# عملاء بس
node scripts/restore-backup.js gs://.../firestore.jsonl.gz --only=clients

# لو عايز تكتب فوق الموجود (بحذر)
node scripts/restore-backup.js gs://.../firestore.jsonl.gz --only=clients --overwrite
```
(`--only` بيحدد الـ collections، زي `clients` أو `clients_archive` أو `settings`.)

اختبر الاسترجاع على الأقل مرة (`--dry-run`)، لأن النسخة اللي مجرّبتش ترجعها مش مضمونة.
