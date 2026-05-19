# Gmail App Password Setup for Email OTP

## Issue
EmailJS blocks server-side API calls, so we've switched to using Gmail SMTP with Nodemailer for sending OTP emails.

## Setup Steps

### 1. Enable 2-Step Verification on Gmail
1. Go to your Google Account: https://myaccount.google.com/
2. Navigate to **Security**
3. Enable **2-Step Verification** if not already enabled

### 2. Generate App Password
1. Go to: https://myaccount.google.com/apppasswords
2. Or navigate: Google Account > Security > 2-Step Verification > App passwords
3. Select "Mail" as the app
4. Select "Other (Custom name)" as the device
5. Enter "FlexiMart Cloud Functions" as the name
6. Click "Generate"
7. **Copy the 16-character app password** (it will look like: `abcd efgh ijkl mnop`)

### 3. Configure Firebase Functions
Run this command in your terminal (replace `YOUR_APP_PASSWORD` with the password from step 2):

```bash
firebase functions:config:set gmail.user="fleximart.app@gmail.com" gmail.pass="YOUR_APP_PASSWORD"
```

**Important:** Remove spaces from the app password when setting it. If the password is `abcd efgh ijkl mnop`, use `abcdefghijklmnop`.

### 4. Deploy the Function
```bash
firebase deploy --only functions:sendOtpEmailHttp
```

### 5. Test
Try signing up with a new email address. The OTP email should be sent via Gmail SMTP.

## Troubleshooting

### Error: "Gmail authentication failed"
- Make sure 2-Step Verification is enabled
- Verify the app password is correct (no spaces)
- Check that the email address matches: `fleximart.app@gmail.com`

### Error: "Email service error"
- Check Firebase Functions logs: `firebase functions:log --only sendOtpEmailHttp`
- Verify the app password is set: `firebase functions:config:get`

### To view current config:
```bash
firebase functions:config:get
```

### To update config:
```bash
firebase functions:config:set gmail.pass="new-password"
firebase deploy --only functions:sendOtpEmailHttp
```

## Security Note
The app password is stored securely in Firebase Functions config and is not exposed in your code.

