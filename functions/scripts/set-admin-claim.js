'use strict';

/**
 * بيمنح (أو بيسحب) صلاحية الأدمن لحساب عن طريق custom claim.
 *
 * الاستخدام:
 *   node scripts/set-admin-claim.js your-email@example.com
 *   node scripts/set-admin-claim.js your-email@example.com --remove
 *
 * محتاج GOOGLE_APPLICATION_CREDENTIALS يشاور على service-account.json.
 * بعد التنفيذ: اعمل خروج ودخول في التطبيق عشان التوكن يتجدد.
 */

const admin = require('firebase-admin');

async function main() {
  const email = process.argv[2];
  const remove = process.argv.includes('--remove');

  if (!email || email.startsWith('--')) {
    console.error('الاستخدام: node scripts/set-admin-claim.js <email> [--remove]');
    process.exit(1);
  }

  admin.initializeApp();

  const user = await admin.auth().getUserByEmail(email);
  const claims = Object.assign({}, user.customClaims || {});

  if (remove) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }

  await admin.auth().setCustomUserClaims(user.uid, claims);
  console.log(
    `${remove ? 'تم سحب' : 'تم منح'} صلاحية الأدمن: ${email} (uid: ${user.uid})`,
  );
}

main().catch((e) => {
  console.error('فشل:', e.message || e);
  process.exit(1);
});
