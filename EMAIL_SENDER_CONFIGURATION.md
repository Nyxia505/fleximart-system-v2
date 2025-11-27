# Email Sender Configuration Guide

## ✅ Code Changes Applied

The email service has been updated to use FlexiMart branding:
- **Sender Name**: FlexiMart
- **Sender Email**: fleximart.app@gmail.com
- **Reply-To**: no-reply@fleximart.com

## ⚠️ Important: EmailJS Dashboard Configuration Required

To ensure emails show "FlexiMart" as the sender (not your personal Gmail), you **MUST** configure your EmailJS service settings:

### Step 1: Configure EmailJS Service

1. Go to [EmailJS Dashboard](https://dashboard.emailjs.com/)
2. Navigate to **Email Services** → Select your service (`service_e76lq6a`)
3. Click **Edit** or **Settings**

### Step 2: Update Service Connection

**For Gmail Service:**
- **Service ID**: `service_e76lq6a`
- **From Name**: Set to `FlexiMart`
- **From Email**: Set to `fleximart.app@gmail.com` (or your configured FlexiMart email)
- **Reply-To**: Set to `no-reply@fleximart.com`

**Important Notes:**
- The "From Email" must be the email address connected to your EmailJS service
- If using Gmail, you need to connect `fleximart.app@gmail.com` (not your personal Gmail)
- The sender name will appear as "FlexiMart" in recipient's inbox

### Step 3: Update Email Template

1. Go to **Email Templates** → Select template (`template_9lir44r`)
2. Update the template to use these variables:
   - `{{from_name}}` → Will show "FlexiMart"
   - `{{from_email}}` → Will show "fleximart.app@gmail.com"
   - `{{reply_to}}` → Will show "no-reply@fleximart.com"

### Step 4: Template Variables Available

The following variables are now passed to your EmailJS template:

```javascript
{
  "to_email": "user@example.com",
  "to_name": "User Name",
  "otp": "123456",
  "from_name": "FlexiMart",
  "from_email": "fleximart.app@gmail.com",
  "reply_to": "no-reply@fleximart.com",
  "company_name": "FlexiMart",
  "app_name": "FlexiMart"
}
```

### Step 5: Update Template HTML (Optional but Recommended)

In your EmailJS template, you can use:

```html
From: {{from_name}} <{{from_email}}>
Reply-To: {{reply_to}}
```

Or in the template settings:
- **Subject**: `FlexiMart - Email Verification Code`
- **From Name**: `{{from_name}}` or hardcode `FlexiMart`
- **From Email**: Use the service's configured email (fleximart.app@gmail.com)

## 🔒 Security & Privacy

✅ **No Personal Data Exposed:**
- All emails now use FlexiMart branding
- No personal Gmail account information in sender fields
- Professional sender identity maintained

## 📧 Alternative: Use Custom Domain Email

If you have a custom domain, you can use:
- **From Email**: `no-reply@fleximart.com` (or your domain)
- **Reply-To**: `support@fleximart.com`

This requires:
1. Setting up email service for your domain
2. Configuring EmailJS to use SMTP with your domain
3. Updating the `_senderEmail` constant in `lib/services/email_service.dart`

## 🧪 Testing

After configuration:
1. Send a test verification email
2. Check the email in recipient's inbox
3. Verify sender shows as "FlexiMart" (not personal name)
4. Verify sender email is fleximart.app@gmail.com
5. Check that no personal Google account info appears

## 📝 Current Configuration

**File**: `lib/services/email_service.dart`

```dart
static const String _senderName = 'FlexiMart';
static const String _senderEmail = 'fleximart.app@gmail.com';
static const String _replyTo = 'no-reply@fleximart.com';
```

**Note**: The actual sender email is controlled by your EmailJS service connection. The code passes the display name, but the service must be connected to the correct email account.

