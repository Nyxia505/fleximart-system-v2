# FlexiMart OTP Email & Push Setup

Signup **requires** a 6-digit code in the user's **Gmail inbox** before they can verify and create an account. Push notification is optional backup.

## Quick setup (required once)

1. **Gmail App Password** → Firestore `app_config/emailjs` field `smtpPass`
2. **EmailJS** → enable non-browser API (backup if SMTP fails)
3. **Deploy functions** (PowerShell — use quotes):

```powershell
firebase deploy --only "functions:sendOtpEmail,functions:sendOtpNotification,functions:onOtpVerificationCreated"
```

4. **Seed Firestore** (optional script):

```powershell
$env:GMAIL_APP_PASSWORD="your16charapppassword"
cd functions
node ../scripts/seed_firestore_email_config.js
```

---

## 1. Gmail App Password (recommended — most reliable)

1. Use a Google account with **2-Step Verification** enabled.
2. Google Account → Security → **App passwords** → create one for "Mail".
3. Copy the **16-character** password (no spaces).

### Where to put it (do NOT commit real passwords to git)

| Location | Fields |
|----------|--------|
| `assets/config/emailjs.json` | `smtpUser`, `smtpPass` (local dev only) |
| Firestore `app_config/emailjs` | `smtpUser`, `smtpPass` (production) |
| Firebase Functions config | `firebase functions:config:set gmail.user="..." gmail.pass="..."` |

Example Firestore document `app_config/emailjs`:

```json
{
  "serviceId": "service_1dhvvdp",
  "templateId": "template_ac0np7l",
  "publicKey": "TMXZA9w62NrPr-zjY",
  "privateKey": "YOUR_PRIVATE_KEY",
  "smtpUser": "queenyvonnedalahay@gmail.com",
  "smtpPass": "YOUR_16_CHAR_APP_PASSWORD"
}
```

Copy from `assets/config/emailjs.example.json` and replace placeholders.

---

## 2. EmailJS dashboard

Template: **template_ac0np7l** · Service: **service_1dhvvdp**

### Template variables (Content tab)

| Variable | Value in template |
|----------|-------------------|
| To Email | `{{to_email}}` |
| To Name | `{{to_name}}` |
| Body | include `{{otp}}` |

### Required security setting

**Account → Security → Allow non-browser API requests = ON**

Without this, mobile/server sends return **403** and email will not arrive.

---

## 3. Firebase

### Deploy Cloud Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions:sendOtpEmail,functions:sendOtpNotification,functions:onOtpVerificationCreated
```

### Deploy Firestore rules (includes `pending_signup` for FCM tokens)

```bash
firebase deploy --only firestore:rules
```

### Optional: Trigger Email extension

If SMTP and EmailJS both fail, the app queues documents in the **`mail`** collection. That only sends email if you install the official **Firebase Trigger Email** extension. Otherwise use SMTP or EmailJS.

### Debug delivery

After signup, open **Firestore → `otp_verifications`** (latest doc):

| Field | Meaning |
|-------|---------|
| `emailSent: true` | Email delivered |
| `emailError` | Why email failed |
| `pushSent: true` | Push delivered |
| `pushError` | Why push failed (e.g. no FCM token) |

---

## 4. Test EmailJS from terminal

```bash
node scripts/test_emailjs_send.js template_ac0np7l your.email@gmail.com
```

Success = `SUCCESS 200`. Check inbox and spam.

---

## 5. Test on Android device

1. Use a **physical phone** (not Chrome web) — `flutter run` on connected device.
2. **Settings → Apps → FlexiMart → Notifications → Allow**.
3. Sign up with a real email you can open in Gmail on the same phone.
4. Look for:
   - Notification in the **status bar** (push)
   - Email in **Gmail** app (inbox + spam)
5. If nothing arrives, tap **Resend** and check Firestore fields above.

---

## 6. Security

- Never show OTP in-app dialogs or "Show code here".
- Do not commit `smtpPass` or EmailJS private keys to public repos.
- Rotate keys if they were shared in chat or committed by mistake.
