/**
 * Test EmailJS OTP template delivery.
 *
 * Usage:
 *   node scripts/test_emailjs_send.js
 *   node scripts/test_emailjs_send.js template_ac0np7l recipient@gmail.com
 *
 * Prerequisites:
 *   - EmailJS Account → Security → "Allow non-browser API requests" = ON
 *   - Template To Email field = {{to_email}}
 */
const axios = require('axios');

const templateId = process.argv[2] || 'template_ac0np7l';
const toEmail = process.argv[3] || process.env.TEST_EMAIL || 'queenyvonnedalahay@gmail.com';

const SERVICE_ID = process.env.EMAILJS_SERVICE_ID || 'service_1dhvvdp';
const PUBLIC_KEY = process.env.EMAILJS_PUBLIC_KEY || 'TMXZA9w62NrPr-zjY';
const PRIVATE_KEY = process.env.EMAILJS_PRIVATE_KEY || 'mgsii9qp4xF4Fphe19cj_';

const payload = {
  service_id: SERVICE_ID,
  template_id: templateId,
  user_id: PUBLIC_KEY,
  accessToken: PRIVATE_KEY,
  template_params: {
    to_email: toEmail,
    to_name: 'FlexiMart Test',
    otp: '847291',
  },
};

console.log('Sending test OTP email...');
console.log('  service:', SERVICE_ID);
console.log('  template:', templateId);
console.log('  to:', toEmail);

axios
  .post('https://api.emailjs.com/api/v1.0/email/send', payload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: 25000,
  })
  .then((r) => {
    console.log('\n✅ SUCCESS', r.status);
    console.log('Check inbox and spam for code 847291');
    process.exit(0);
  })
  .catch((e) => {
    const status = e.response?.status;
    const body = e.response?.data?.text || e.response?.data || e.message;
    console.error('\n❌ FAILED', status || '', body);
    if (String(body).includes('non-browser')) {
      console.error('\nFix: EmailJS → Account → Security → Enable non-browser API requests');
    }
    if (String(body).toLowerCase().includes('template')) {
      console.error('\nFix: Verify template ID and To Email = {{to_email}}');
    }
    process.exit(1);
  });
