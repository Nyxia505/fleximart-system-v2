# Email Verification Permission Denied Fix

## Problem
Users are getting "Permission denied" error when verifying their email with the correct OTP code.

## Root Cause
The Firestore security rules require the user to be authenticated (`request.auth.uid == uid`) to update their verification status. However, the user may not be properly authenticated when on the verification screen, causing the permission denied error.

## Solution Steps

### 1. Verify User is Authenticated
The code now checks if the user is authenticated before attempting to update Firestore.

### 2. Deploy Updated Firestore Rules
Make sure the Firestore rules in `firestore_rules.txt` are deployed to Firebase:

```bash
firebase deploy --only firestore:rules
```

### 3. Test the Flow
1. Sign up with a new Gmail account
2. Check the browser console for authentication debug logs
3. Enter the OTP code received via email
4. Verification should succeed without permission errors

## Debugging
If the issue persists, check the browser console for these debug logs:
- `=== Verification Screen Auth Status ===`
- Look for `Current User:` and `UID Match:` values

## Expected Behavior
- User signs up → stays authenticated
- User receives OTP via email
- User enters OTP → Firestore update succeeds
- User is verified and can log in

## If Permission Denied Still Occurs

### Option 1: Temporarily relax Firestore rules (NOT RECOMMENDED for production)
Add this rule temporarily for testing:

```javascript
match /users/{uid} {
  // Allow anyone to update verification fields (TEMPORARY - FOR TESTING ONLY)
  allow update: if request.resource.data.diff(resource.data)
                    .changedKeys().hasAll(['emailVerified', 'isVerified']);
}
```

### Option 2: Check Firebase Console
1. Go to Firebase Console → Authentication
2. Verify the user appears in the user list
3. Check Firestore → users collection
4. Verify the user document exists with the correct UID

### Option 3: Check user authentication state
The app now logs authentication status to the console. Check if:
- `Is Authenticated: true`
- `UID Match: true`

If either is false, the user is not properly authenticated.

## Contact Support
If the issue persists after following all steps, please provide:
1. Browser console logs (especially the authentication debug logs)
2. Firebase Console screenshots showing the user in Authentication
3. Firestore Console screenshot showing the user document

