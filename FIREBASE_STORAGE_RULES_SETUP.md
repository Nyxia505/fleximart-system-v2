# 🔐 Firebase Storage Rules Setup

## ✅ Current Storage Rules

Your `storage.rules` file already has the correct rules for profile image uploads:

```javascript
match /profile_images/{fileName} {
  allow read: if true;  // Anyone can view profile pictures
  // Users can only upload/update their own profile image
  // File name format: {userId}.jpg
  allow write: if request.auth != null && 
                  fileName == request.auth.uid + '.jpg';
}
```

## 🚀 How to Deploy Rules

### Option 1: Using Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Storage** in the left menu
4. Click **Rules** tab
5. Copy and paste the rules from `storage.rules`
6. Click **Publish**

### Option 2: Using Firebase CLI

```bash
# Install Firebase CLI if not installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy storage rules
firebase deploy --only storage
```

## ✅ Rules Explanation

The current rules allow:
- ✅ **Read**: Anyone can view profile pictures (for displaying in app)
- ✅ **Write**: Only authenticated users can upload
- ✅ **Security**: Users can only upload files named `{theirUserId}.jpg`

This means:
- User with UID `abc123` can only upload `abc123.jpg`
- User with UID `abc123` CANNOT upload `xyz789.jpg`
- This prevents users from overwriting other users' profile pictures

## 🔍 Testing Rules

After deploying, test by:
1. Logging in as a customer
2. Going to Profile → Edit Profile
3. Tapping the camera icon
4. Selecting an image from gallery/camera
5. Image should upload successfully

## ❌ Common Issues

### Issue: "Permission denied" error
**Solution**: Make sure you've deployed the storage rules to Firebase

### Issue: "File not found" error
**Solution**: This is normal if it's the first upload. The code tries to delete old images first.

### Issue: Upload timeout
**Solution**: Check internet connection. The timeout is set to 30 seconds.

## 📝 Current Implementation

The profile image upload is already implemented in:
- `lib/customer/dashboard_profile.dart` - Main profile screen
- `EditUsernameScreen` - Edit profile screen

Both screens have:
- ✅ Image picker (Gallery/Camera)
- ✅ Loading indicator
- ✅ Error handling
- ✅ Success notification
- ✅ Real-time updates via StreamBuilder

## 🎉 No Additional Setup Needed!

The code is already complete. You just need to:
1. **Deploy the storage rules** (if not already deployed)
2. **Test the upload** by tapping the camera icon in the profile

The rules are already correct in your `storage.rules` file!

