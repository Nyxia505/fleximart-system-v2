/**
 * One-time: set Firestore app_config/emailjs for Gmail OTP delivery.
 *
 * Usage (replace YOUR_APP_PASSWORD):
 *   set GMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx
 *   node scripts/seed_firestore_email_config.js
 *
 * Requires: GOOGLE_APPLICATION_CREDENTIALS or firebase login + project.
 */
const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'fleximart-system';
const appPassword = process.env.GMAIL_APP_PASSWORD || process.argv[2];

if (!appPassword) {
  console.error('Usage: GMAIL_APP_PASSWORD=16charpass node scripts/seed_firestore_email_config.js');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

async function main() {
  await db.collection('app_config').doc('emailjs').set(
    {
      serviceId: 'service_1dhvvdp',
      templateId: 'template_ac0np7l',
      publicKey: 'TMXZA9w62NrPr-zjY',
      privateKey: 'mgsii9qp4xF4Fphe19cj_',
      smtpUser: 'queenyvonnedalahay@gmail.com',
      smtpPass: appPassword.replace(/\s/g, ''),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log('✅ app_config/emailjs updated (smtpPass set). Redeploy functions and restart app.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
