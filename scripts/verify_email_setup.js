/**
 * Checks EmailJS + SMTP setup. Run from project root:
 *   cd functions && npm install
 *   cd .. && node scripts/verify_email_setup.js
 */
const path = require('path');
const fs = require('fs');
const axios = require(path.join(__dirname, '../functions/node_modules/axios'));

const cfgPath = path.join(__dirname, '../assets/config/emailjs.json');
const secretsPath = path.join(__dirname, '../assets/config/emailjs.secrets.json');

const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
let secrets = {};
try {
  secrets = JSON.parse(fs.readFileSync(secretsPath, 'utf8'));
} catch (_) {}

const SERVICE_ID = cfg.serviceId || 'service_1dhvvdp';
const TEMPLATE_ID = cfg.templateId || 'template_ac0np7l';
const PUBLIC_KEY = cfg.publicKey || 'TMXZA9w62NrPr-zjY';
const PRIVATE_KEY = cfg.privateKey || '';
const smtpPass = secrets.smtpPass || '';

console.log('\n=== FlexiMart email setup check ===\n');
console.log('serviceId:', SERVICE_ID);
console.log('templateId:', TEMPLATE_ID);
console.log('publicKey:', PUBLIC_KEY ? `${PUBLIC_KEY.slice(0, 8)}...` : '(missing)');
console.log('privateKey:', PRIVATE_KEY ? '(set)' : '(missing)');
console.log('smtpPass:', smtpPass ? '(set in secrets)' : '(NOT SET — need Gmail App Password)\n');

async function testEmailJs(usePrivate) {
  const payload = {
    service_id: SERVICE_ID,
    template_id: TEMPLATE_ID,
    user_id: PUBLIC_KEY,
    template_params: {
      to_email: secrets.smtpUser || cfg.smtpUser || 'test@example.com',
      to_name: 'FlexiMart Test',
      otp: '123456',
    },
  };
  if (usePrivate && PRIVATE_KEY) payload.accessToken = PRIVATE_KEY;
  const r = await axios.post(
    'https://api.emailjs.com/api/v1.0/email/send',
    payload,
    { timeout: 20000, validateStatus: () => true }
  );
  return r;
}

(async () => {
  console.log('1) EmailJS server API (private key)...');
  if (!PRIVATE_KEY) {
    console.log('   SKIP — no privateKey in emailjs.json\n');
  } else {
    try {
      const r = await testEmailJs(true);
      if (r.status >= 200 && r.status < 300) {
        console.log('   OK — email sent. Check inbox.\n');
        process.exit(0);
      }
      const body = r.data?.text || JSON.stringify(r.data);
      console.log('   FAIL', r.status, body);
      if (String(body).includes('non-browser')) {
        console.log('\n   FIX: https://dashboard.emailjs.com/admin/account/security');
        console.log('        → Enable "Allow non-browser API requests"\n');
      }
      if (String(body).toLowerCase().includes('insufficient authentication')) {
        console.log('\n   FIX: https://dashboard.emailjs.com/admin');
        console.log('        → Email Services → Gmail → Reconnect account\n');
      }
    } catch (e) {
      console.log('   ERROR', e.message);
    }
  }

  console.log('2) Gmail SMTP (recommended)...');
  if (!smtpPass) {
    console.log('   NOT CONFIGURED');
    console.log('   Run: .\\scripts\\setup_gmail_smtp.ps1 "your 16-char app password"');
    console.log('   Get App Password: Google Account → Security → App passwords\n');
  } else {
    console.log('   smtpPass present — deploy functions and test signup in app.\n');
  }

  console.log('EmailJS login password ≠ Gmail App Password. Do not put EmailJS password in smtpPass.\n');
})();
