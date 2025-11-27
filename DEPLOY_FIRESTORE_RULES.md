# Deploy Firestore Rules to Fix Permission Denied Error

## CRITICAL: You MUST deploy these rules to Firebase!

The "Permission denied" error occurs because the Firestore security rules are not deployed to your Firebase project.

## Quick Fix (Option 1): Deploy via Firebase CLI

### Step 1: Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Initialize Firebase (if not already done)
```bash
firebase init firestore
```
- Select your Firebase project
- Accept the default firestore.rules file

### Step 4: Deploy the rules
```bash
firebase deploy --only firestore:rules
```

### Step 5: Verify deployment
You should see: `✔  Deploy complete!`

---

## Alternative Fix (Option 2): Deploy via Firebase Console

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com/
2. Select your project: **fleximart-system**

### Step 2: Navigate to Firestore Rules
1. Click "Firestore Database" in the left sidebar
2. Click the "Rules" tab at the top

### Step 3: Copy and paste the rules
Copy the entire contents of `firestore.rules` file and paste it into the Firebase Console editor.

### Step 4: Publish the rules
Click the "Publish" button at the top right.

---

## Verify Rules Are Working

### Test the verification flow:
1. Sign up with a new account
2. Enter the OTP code you receive
3. You should see "Email verified successfully!" instead of "Permission denied"

### Check browser console:
Look for these debug logs:
```
=== Verification Screen Auth Status ===
Current User: [some UID]
Is Authenticated: true
UID Match: true
```

If you still see "Permission denied" after deploying:
1. Check that the rules were published (Firebase Console → Firestore → Rules tab)
2. Try signing out and signing up with a new account
3. Clear browser cache and try again

---

## Understanding the Rules

The key rule that allows email verification is:

```javascript
allow update: if (isOwner(uid) && 
                  request.resource.data.diff(resource.data)
                    .changedKeys().hasAll(['emailVerified', 'isVerified']))
```

This means:
- User MUST be authenticated (`isOwner(uid)` checks `request.auth.uid == uid`)
- User can only update `emailVerified` and `isVerified` fields
- This prevents unauthorized users from modifying verification status

---

## Troubleshooting

### Error: "Firebase CLI not found"
Install it: `npm install -g firebase-tools`

### Error: "No project selected"
Run: `firebase use --add` and select your project

### Error: "Permission denied" after deploying
1. Check browser console for auth status logs
2. Verify user is authenticated during verification
3. Try signing out completely and signing up again

### Still not working?
Contact support with:
- Browser console logs
- Firebase Console screenshot of Rules tab
- Screenshot of error message

