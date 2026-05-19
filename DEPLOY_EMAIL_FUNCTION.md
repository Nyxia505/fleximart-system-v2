# Deploy Email OTP Cloud Function

## Issue
The app is getting a 403 error because EmailJS blocks direct API calls from mobile apps. We've created a Cloud Function to handle this.

## Steps to Fix

### 1. Install Dependencies (if not already done)
```bash
cd functions
npm install
```

### 2. Deploy the Cloud Function
```bash
# From the project root directory
firebase deploy --only functions:sendOtpEmail
```

Or deploy all functions:
```bash
firebase deploy --only functions
```

### 3. Rebuild Your Flutter App
After deploying the Cloud Function, you need to rebuild your Flutter app:

```bash
# Clean the build
flutter clean

# Get dependencies
flutter pub get

# Rebuild the app
flutter run
```

Or if you're building for release:
```bash
flutter build apk  # for Android
flutter build ios  # for iOS
```

### 4. Verify Deployment
After deployment, you should see the function in Firebase Console:
- Go to Firebase Console → Functions
- Look for `sendOtpEmail` function
- It should show as "Deployed"

## Troubleshooting

If you still see the 403 error:
1. Make sure the Cloud Function is deployed (check Firebase Console)
2. Make sure you've rebuilt the app (not just hot reload)
3. Check that you're using the latest code (the email service should call Cloud Functions, not EmailJS directly)
4. Verify your Firebase project is correctly configured

## Testing
After deployment, try signing up again. The email OTP should work from mobile devices.

