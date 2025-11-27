# Firebase Custom Claims Setup Script

This script sets custom claims (roles) for admin and staff users in Firebase Authentication.

## Prerequisites

1. **Node.js** installed (v14 or higher)
2. **Firebase Project** with Admin SDK enabled
3. **Service Account Key** from Firebase Console

## Setup Instructions

### Step 1: Install Dependencies

Navigate to the `scripts` directory and install dependencies:

```bash
cd scripts
npm install
```

### Step 2: Get Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** (gear icon) > **Service Accounts**
4. Click **"Generate New Private Key"**
5. Save the downloaded JSON file as `serviceAccountKey.json` in the `scripts` directory

**⚠️ Important:** Never commit `serviceAccountKey.json` to version control! Add it to `.gitignore`.

### Step 3: Run the Script

```bash
node set_custom_claims.js
```

Or use the npm script:

```bash
npm run set-claims
```

## What the Script Does

1. **Sets Admin Role** for UID: `902rmTO6DCY0OCuBoOJ6BrtXiaL2`
2. **Sets Staff Role** for UID: `tFQOi3Di1uZnds4cGfiBL7Nq9ys1`

## Expected Output

```
✅ Firebase Admin SDK initialized with service account key

🚀 Starting custom claims assignment...

==================================================

1️⃣ Setting ADMIN role for UID: 902rmTO6DCY0OCuBoOJ6BrtXiaL2
📋 User found: admin@example.com
✅ ADMIN role applied successfully
   Custom claims: {"role":"admin"}

2️⃣ Setting STAFF role for UID: tFQOi3Di1uZnds4cGfiBL7Nq9ys1
📋 User found: staff@example.com
✅ STAFF role applied successfully
   Custom claims: {"role":"staff"}

==================================================

📊 Summary:
   ✅ Success: 2
   ❌ Failed: 0

🎉 All roles assigned successfully!

⚠️  IMPORTANT: Users must refresh their tokens to see the new role.
   In Flutter app, call: await user.getIdTokenResult(true)
   Or users can sign out and sign in again.

✨ Script completed
```

## After Running the Script

Users need to refresh their authentication tokens to see the new role:

### Option 1: Force Token Refresh (Recommended)
In your Flutter app, call:
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  await user.getIdTokenResult(true); // Force refresh
}
```

### Option 2: Sign Out and Sign In
Users can simply sign out and sign in again to get a new token with the updated claims.

## Troubleshooting

### Error: "Could not initialize Firebase Admin SDK"
- Make sure `serviceAccountKey.json` exists in the `scripts` directory
- Verify the JSON file is valid
- Check that the service account has the necessary permissions

### Error: "User not found"
- Verify the UIDs are correct
- Make sure the users exist in Firebase Authentication

### Error: "Permission denied"
- Ensure the service account has "Firebase Admin" role
- Check that the service account key is not expired

## Security Notes

- **Never commit** `serviceAccountKey.json` to version control
- Keep service account keys secure and private
- Rotate keys periodically
- Use environment variables in production/CI environments

## Alternative: Using Environment Variable

Instead of using a file, you can set the service account as an environment variable:

```bash
export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
node set_custom_claims.js
```

This is recommended for CI/CD pipelines.

