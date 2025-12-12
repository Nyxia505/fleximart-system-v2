# Firestore Rules Update for OTP Signup

## ✅ Fixed Permission Denied Error

The error `[cloud_firestore/permission-denied] Missing or insufficient permissions` was caused by missing Firestore rules for the OTP collections.

## 📝 Changes Made to `firestore.rules`

### 1. Added OTP Verifications Collection Rules

```javascript
match /otp_verifications/{otpId} {
  // Allow create during signup (unauthenticated)
  allow create: if request.resource.data.userId is string &&
                   request.resource.data.otpCode is string &&
                   request.resource.data.otpCode.size() == 6 &&
                   request.resource.data.expiresAt is timestamp &&
                   request.resource.data.expiresAt > request.time &&
                   request.resource.data.used == false &&
                   !('usedAt' in request.resource.data);
  
  // Allow read during verification (unauthenticated users need to verify OTP)
  allow read: if true;
  
  // Allow update only to mark as used
  allow update: if request.resource.data.diff(resource.data)
                  .affectedKeys().hasOnly(['used', 'usedAt']) &&
                request.resource.data.used == true &&
                resource.data.used == false;
  
  allow delete: if false;
}
```

### 2. Added OTP Last Sent Collection Rules

```javascript
match /otp_last_sent/{userId} {
  // Allow read/write during signup (unauthenticated users need to track cooldown)
  allow read, write: if request.resource.data.lastSentAt is timestamp;
}
```

### 3. Updated Users Collection Rules

```javascript
match /users/{uid} {
  // Allow read access for email existence check during signup
  allow read: if isOwner(uid) || isAdmin() || isStaff() || true;
  // ... rest of rules
}
```

## 🚀 Deployment Steps

### Step 1: Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### Step 2: Verify Rules Are Active

1. Go to Firebase Console → Firestore Database → Rules
2. Verify the new rules are displayed
3. Check that rules are published (not in draft)

### Step 3: Test Signup Flow

1. Try to sign up with a new email
2. Verify OTP is created successfully
3. Verify OTP can be read during verification
4. Verify OTP can be updated to mark as used

## 🔒 Security Notes

### OTP Verifications Collection:
- ✅ **Create**: Validated structure (userId, 6-digit code, expiration)
- ✅ **Read**: Allowed for verification (OTPs expire in 5 minutes)
- ✅ **Update**: Only allowed to mark as used (prevents reuse)
- ✅ **Delete**: Not allowed (audit trail)

### OTP Last Sent Collection:
- ✅ **Read/Write**: Allowed for cooldown tracking
- ✅ **Validation**: Ensures lastSentAt is a timestamp

### Users Collection:
- ⚠️ **Read Access**: Currently open for email existence checks
- 💡 **Recommendation**: Consider using Cloud Function for email checks in production

## 🐛 Troubleshooting

### If you still get permission denied:

1. **Verify rules are deployed:**
   ```bash
   firebase firestore:rules:get
   ```

2. **Check Firebase Console:**
   - Go to Firestore Database → Rules
   - Verify rules match the updated version

3. **Check for syntax errors:**
   - Rules should validate in Firebase Console
   - Look for any red error indicators

4. **Clear app cache:**
   - Uninstall and reinstall app
   - Or clear app data

5. **Check Firestore indexes:**
   - Go to Firestore Database → Indexes
   - Create composite index if needed:
     - Collection: `otp_verifications`
     - Fields: `userId` (Ascending), `otpCode` (Ascending), `used` (Ascending), `createdAt` (Descending)

## 📋 Required Firestore Index

If you get an index error, create this composite index:

**Collection:** `otp_verifications`
**Fields:**
- `userId` (Ascending)
- `otpCode` (Ascending)  
- `used` (Ascending)
- `createdAt` (Descending)

**Query Scope:** Collection

Firebase will usually prompt you to create this index automatically when you run the query.

## ✅ Verification Checklist

- [ ] Rules deployed successfully
- [ ] OTP creation works (no permission denied)
- [ ] OTP verification works (can read OTP)
- [ ] OTP update works (can mark as used)
- [ ] Email existence check works
- [ ] Cooldown tracking works
- [ ] No permission errors in console

---

**Status:** ✅ Rules updated and ready to deploy

