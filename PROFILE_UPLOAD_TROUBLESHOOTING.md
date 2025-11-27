# 🔧 Profile Image Upload Troubleshooting Guide

## ✅ What I Fixed

1. **Updated Storage Rules** - Added explicit `delete` permission
2. **Improved Error Handling** - Now shows detailed error dialogs
3. **Better Debugging** - Prints errors to console for debugging
4. **Retry Functionality** - Added retry button in error dialog

## 🔍 Step-by-Step Troubleshooting

### Step 1: Check Firebase Storage Rules Are Deployed

**IMPORTANT:** Rules must be deployed to Firebase Console!

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Storage** → **Rules** tab
4. Verify the rules match your `storage.rules` file:
   ```javascript
   match /profile_images/{fileName} {
     allow read: if true;
     allow write: if request.auth != null && 
                     fileName == request.auth.uid + '.jpg';
     allow delete: if request.auth != null && 
                      fileName == request.auth.uid + '.jpg';
   }
   ```
5. If different, **copy and paste** from `storage.rules`
6. Click **Publish**

### Step 2: Check User Authentication

Make sure the user is logged in:
- Check Firebase Auth console
- Verify user has a valid UID
- Try logging out and back in

### Step 3: Check Console Logs

When you try to upload, check the Flutter console for:
```
❌ Profile Image Upload Error:
   Error: [error details]
   StackTrace: [stack trace]
```

Common errors and solutions:

#### Error: "Permission denied" or "403"
**Solution:** 
- Storage rules not deployed → Deploy rules to Firebase Console
- Wrong file name format → Should be `{userId}.jpg`
- User not authenticated → Check Firebase Auth

#### Error: "Network error" or "timeout"
**Solution:**
- Check internet connection
- Check Firebase project is active
- Try again after a few moments

#### Error: "storage/object-not-found"
**Solution:**
- This is normal for first upload (old image doesn't exist)
- The upload should still work

### Step 4: Test Storage Rules Manually

1. Go to Firebase Console → Storage
2. Try uploading a test file manually
3. Check if you see any permission errors

### Step 5: Verify File Path

The code uploads to:
```
profile_images/{userId}.jpg
```

Make sure:
- `{userId}` matches your Firebase Auth UID
- File extension is `.jpg`
- Path is exactly `profile_images/` (not `profile_image/` or `profile/`)

## 🧪 Quick Test

Add this test function to verify everything works:

```dart
Future<void> testProfileUpload() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ User not logged in');
    return;
  }
  
  print('✅ User ID: ${user.uid}');
  print('✅ Email: ${user.email}');
  
  // Test Storage reference
  final storageRef = FirebaseStorage.instance
      .ref()
      .child('profile_images')
      .child('${user.uid}.jpg');
  
  print('✅ Storage path: profile_images/${user.uid}.jpg');
  
  // Try to check if file exists
  try {
    await storageRef.getMetadata();
    print('✅ Old image exists');
  } catch (e) {
    print('ℹ️ No old image (this is OK): $e');
  }
}
```

## 📱 Platform-Specific Issues

### Android
- Check `AndroidManifest.xml` has internet permission:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```
- Check camera/gallery permissions are granted

### iOS
- Check `Info.plist` has camera/gallery permissions:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>We need camera access to upload profile photos</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>We need photo library access to upload profile photos</string>
  ```

### Web
- Check browser console for CORS errors
- Make sure Firebase Storage is enabled for web

## 🔄 Still Not Working?

1. **Check Firebase Console Logs:**
   - Go to Firebase Console → Storage → Files
   - Check if file appears after upload attempt
   - Check for any error messages

2. **Try Manual Upload:**
   - Upload a test image via Firebase Console
   - If that works, the issue is with the code
   - If that fails, the issue is with Storage rules

3. **Check Firestore:**
   - After upload, check if `profileImageUrl` is updated in Firestore
   - Go to Firestore → `users/{userId}`
   - Check `profileImageUrl` field

4. **Verify User Document:**
   - Make sure user document exists in `users` collection
   - Check user has correct `uid` in Firestore

## 💡 Common Solutions

### Solution 1: Redeploy Storage Rules
```bash
firebase deploy --only storage
```

### Solution 2: Clear App Data
- Uninstall and reinstall app
- Or clear app data/cache

### Solution 3: Check Firebase Project
- Make sure you're using the correct Firebase project
- Check `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)

### Solution 4: Update Firebase Packages
```bash
flutter pub upgrade firebase_storage firebase_auth cloud_firestore
```

## 📞 Need More Help?

If still not working, provide:
1. Exact error message from console
2. Screenshot of Firebase Storage rules
3. User UID (from Firebase Auth)
4. Platform (Android/iOS/Web)

