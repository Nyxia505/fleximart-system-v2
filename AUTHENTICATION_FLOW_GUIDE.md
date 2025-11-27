# Authentication Flow Guide - FlexiMart

## Overview
This document explains the complete authentication flow for FlexiMart, including email verification and login process.

## Fixed Issues

### Problem
- Users were getting "Permission denied" error when trying to verify their email
- Firestore security rules were too restrictive for the verification process

### Solution
1. **Updated Firestore Security Rules** - Simplified the rules to allow users to update their own documents during verification
2. **Configured firebase.json** - Added proper Firestore rules configuration
3. **Deployed Rules** - Successfully deployed the updated rules to Firebase

## Authentication Flow

### 1. First-Time User Signup

```
User opens app → Welcome Screen → Sign Up Screen
                                        ↓
                        Enter: Full Name, Gmail, Password
                                        ↓
                              Click "Sign Up" button
                                        ↓
                        System checks if email already verified
                                        ↓
                        Firebase Auth creates user account
                                        ↓
                      Firestore creates user document with:
                      - email, fullName, role: 'customer'
                      - emailVerified: false
                      - isVerified: false
                                        ↓
                      6-digit OTP sent to Gmail address
                                        ↓
                      Navigate to Verify Email Screen
```

### 2. Email Verification Process

```
Verify Email Screen
        ↓
User enters 6-digit code
        ↓
System validates code:
- Check if code exists
- Check if code expired
- Check if code matches
        ↓
If valid, update Firestore:
- emailVerified: true
- isVerified: true
- verifiedAt: timestamp
        ↓
Show success message
        ↓
Navigate to Login Screen
```

### 3. Returning User Login

```
User opens app → Login Screen (bypasses Welcome Screen)
                        ↓
              Enter: Gmail, Password
                        ↓
           Click "Sign In" button
                        ↓
         Firebase Auth signs in user
                        ↓
   System checks user's role in Firestore
                        ↓
   For customers: Check if emailVerified = true
                        ↓
   If verified: Navigate to Customer Dashboard
   If not verified: Sign out, show error message
```

### 4. User Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    First Time Users                         │
└─────────────────────────────────────────────────────────────┘
                             ↓
                     Welcome Screen
                             ↓
                ┌────────────┴────────────┐
                ↓                         ↓
         Sign Up Screen            Login Screen
                ↓
    Enter Gmail & Password
                ↓
      Create Firebase Account
                ↓
    Send 6-Digit Code to Gmail
                ↓
     Verify Email Screen
                ↓
      Enter 6-Digit Code
                ↓
    Update Firestore (verified)
                ↓
         Login Screen ──────────────────────┐
                                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Returning Users                           │
└─────────────────────────────────────────────────────────────┘
                             ↓
                      Login Screen
                             ↓
                 Enter Gmail & Password
                             ↓
              Firebase Auth Signs In
                             ↓
         Check Firestore Verification Status
                             ↓
                ┌────────────┴────────────┐
                ↓                         ↓
        If Verified              If Not Verified
                ↓                         ↓
     Customer Dashboard          Sign Out & Show Error
                                 "Email not verified"
```

## Key Features

### 1. Gmail-Only Registration
- System only accepts @gmail.com email addresses during signup
- This ensures all users have a valid Gmail account

### 2. Email Verification Required
- **New users MUST verify their email before they can login**
- Verification is done via 6-digit OTP code sent to Gmail
- Code expires after 10 minutes
- Users can request a new code with 45-second cooldown

### 3. Smart User Recognition
```javascript
// System recognizes verified users automatically
if (email already verified in Firestore) {
  → Redirect to Login Screen
  → User can login directly
} else {
  → User must complete verification first
}
```

### 4. Verification Status Storage
The system stores verification status in **two places**:

1. **Firestore (Source of Truth)**
   ```
   users/{uid}:
     - email: "user@gmail.com"
     - emailVerified: true
     - isVerified: true
     - verifiedAt: timestamp
     - role: "customer"
   ```

2. **Local Cache (SharedPreferences)**
   - Used for faster checks
   - Synced with Firestore

## Security Rules

The updated Firestore rules allow:

```javascript
// Users can create their own document during signup
allow create: if request.auth != null && request.auth.uid == uid;

// Users can read/update their own document
allow read, update, write: if isOwner(uid) || isAdmin() || isStaff();
```

This ensures:
- ✅ Users can create their account during signup
- ✅ Users can update verification status after entering OTP
- ✅ Users can read their own data
- ✅ Only the user (or admin/staff) can modify their data
- ❌ Users cannot modify other users' data

## Common Scenarios

### Scenario 1: New User Signs Up
1. User enters details and signs up
2. Receives 6-digit code via Gmail
3. Enters code on verification screen
4. **System marks email as verified in Firestore**
5. User is redirected to login
6. User logs in successfully → Dashboard

### Scenario 2: Returning Verified User
1. User opens app → Goes directly to Login Screen
2. User enters Gmail and password
3. System checks Firestore: `emailVerified = true`
4. User logs in successfully → Dashboard

### Scenario 3: User Tries to Login Without Verification
1. User signs up but doesn't verify email
2. User tries to login
3. System checks Firestore: `emailVerified = false`
4. **Login is blocked**
5. User is signed out with error: "Your email is not verified"
6. User must go through signup → verification process again

### Scenario 4: User Already Verified, Tries to Sign Up Again
1. User enters same Gmail on signup screen
2. System checks: Email already verified in Firestore
3. Shows message: "This email is already verified. Please sign in."
4. Redirects to Login Screen
5. User can login directly

## Technical Implementation

### Files Modified
1. **firestore.rules** - Updated security rules for verification
2. **firebase.json** - Added Firestore rules configuration
3. **lib/screen/signup_screen.dart** - Handles signup and verification initiation
4. **lib/screen/login_screen.dart** - Validates verification before allowing login
5. **lib/screen/verify_email_screen.dart** - Handles OTP verification
6. **lib/services/email_verification_service.dart** - Manages OTP generation and validation

### Key Functions

**Email Verification Service:**
```dart
// Generate and send OTP
EmailVerificationService.requestEmailVerification(
  email: email,
  displayName: fullName,
)

// Verify OTP code
EmailVerificationService.verifyCode(
  email: email,
  code: code,
)

// Check if email is verified in Firestore
EmailVerificationService.isEmailVerifiedInFirestore(email)
```

## Testing the Flow

### Test 1: New User Signup
1. Open app
2. Click "Sign Up"
3. Enter: Name, Gmail, Password
4. Click "Sign Up"
5. ✅ Should receive OTP code in Gmail
6. Enter 6-digit code
7. ✅ Should see "Email verified successfully!"
8. ✅ Should redirect to Login Screen
9. Enter same Gmail and password
10. ✅ Should login successfully → Dashboard

### Test 2: Returning User
1. Close and reopen app
2. ✅ Should go directly to Login Screen (skip Welcome)
3. Enter Gmail and password
4. ✅ Should login successfully → Dashboard

### Test 3: Unverified User
1. Sign up but close app before verifying
2. Reopen app
3. Try to login
4. ✅ Should show error: "Email not verified"
5. ✅ Should be signed out

## Troubleshooting

### Issue: "Permission denied" error
**Solution:** Firestore rules have been updated and deployed. If you still see this error:
1. Wait 1-2 minutes for rules to propagate
2. Restart the app
3. Try signing up again

### Issue: Not receiving OTP code
**Solution:**
1. Check spam/junk folder in Gmail
2. Wait 45 seconds and click "Resend Code"
3. Ensure you're using a valid @gmail.com address

### Issue: "Invalid or expired code"
**Solution:**
1. Code expires after 10 minutes
2. Click "Resend Code" to get a new one
3. Enter all 6 digits correctly

### Issue: User stuck on verification screen
**Solution:**
1. Complete the verification by entering the code
2. If code expired, click "Resend Code"
3. Once verified, you'll be redirected to login

## Deployment Checklist

- [x] Update Firestore security rules
- [x] Configure firebase.json
- [x] Deploy rules to Firebase: `firebase deploy --only "firestore:rules"`
- [x] Test signup flow
- [x] Test verification flow
- [x] Test login flow
- [x] Test returning user flow

## Next Steps

After implementing this authentication flow, users will experience:

1. **Clear Verification Process** - Users know they need to verify email before login
2. **Smart Recognition** - System recognizes verified users automatically
3. **Secure Access** - Only verified users can access the dashboard
4. **Better UX** - Returning users go directly to login, no need to see welcome screen

## Support

If you encounter any issues:
1. Check that Firestore rules are deployed
2. Verify Firebase project is active: `fleximart-system`
3. Check that user has internet connection
4. Review error messages in the app

---
**Last Updated:** November 9, 2025
**Status:** ✅ Fully Functional

