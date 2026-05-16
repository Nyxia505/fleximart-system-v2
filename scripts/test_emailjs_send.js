/**
 * Test EmailJS send. Usage:
 *   node scripts/test_emailjs_send.js template_YOUR_ID_HERE
 *
 * Get template ID: EmailJS → Email Templates → Contact Us → Settings tab
 */
const axios = require('axios');

const templateId = process.argv[2];
if (!templateId) {
  console.error('Usage: node scripts/test_emailjs_send.js template_XXXXXXX');
  process.exit(1);
}

const payload = {
  service_id: 'service_mdzkdnm',
  template_id: templateId,
  user_id: 'TA-nBrmAS_CGj5HOc',
  accessToken: 'mROztJNx0PKTEVy3bnhu_',
  template_params: {
    to_email: process.argv[3] || 'sapinitmelane84@gmail.com',
    to_name: 'Test',
    otp: '123456',
  },
};

axios
  .post('https://api.emailjs.com/api/v1.0/email/send', payload, {
    headers: { 'Content-Type': 'application/json' },
  })
  .then((r) => console.log('SUCCESS', r.status, r.data))
  .catch((e) =>
    console.error('FAILED', e.response?.status, e.response?.data?.text || e.message)
  );
