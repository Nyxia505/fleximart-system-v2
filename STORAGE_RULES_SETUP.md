# Firebase Storage Rules Setup

## Problem
If profile picture uploads are stuck loading, it's likely because Firebase Storage rules are not configured properly.

## Solution

### Option 1: Deploy via Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **fleximart-system**
3. Navigate to **Storage** in the left sidebar
4. Click on the **Rules** tab
5. Copy and paste the contents of `storage.rules` file
6. Click **Publish**

### Option 2: Deploy via Firebase CLI

If you have Firebase CLI installed:

```bash
firebase deploy --only storage
```

### Option 3: Quick Test Rules (Development Only)

For testing purposes, you can use these permissive rules (NOT for production):

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

⚠️ **Warning**: The above rules allow any authenticated user to read/write any file. Only use for testing!

## Current Rules (from storage.rules)

The `storage.rules` file includes:
- ✅ Profile images: Users can only upload/update/delete their own profile images
- ✅ Product images: Anyone can read, authenticated users can write
- ✅ File size limit: 5MB for profile images
- ✅ Content type validation: Only images allowed

## Verification

After deploying the rules:
1. Try uploading a profile picture again
2. Check the error message if it still fails
3. Verify in Firebase Console > Storage > Rules that the rules are published

