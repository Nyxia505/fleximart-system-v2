# Profile Picture Upload System - Usage Guide

## Complete Implementation

This system provides a complete profile picture upload solution with:
- Image picking from gallery or camera
- Firebase Storage upload
- Firestore URL storage
- Clean UI components

## Files Created

1. **`lib/services/profile_picture_service.dart`** - Core service with all functions
2. **`lib/widgets/profile_picture_upload_button.dart`** - Reusable UI button widget

## Service Functions

### 1. `pickImage()` - Pick image from gallery/camera
```dart
final XFile? image = await service.pickImage(
  source: ImageSource.gallery, // or ImageSource.camera
);
```

### 2. `uploadImage()` - Upload to Firebase Storage
```dart
final String downloadUrl = await service.uploadImage(
  imageFile: imageFile,
  uid: user.uid,
);
```

### 3. `saveProfilePic()` - Save URL to Firestore
```dart
await service.saveProfilePic(
  uid: user.uid,
  downloadUrl: downloadUrl,
);
```

### 4. `updateProfilePicture()` - Complete flow (recommended)
```dart
final String? url = await service.updateProfilePicture(
  uid: user.uid,
  context: context,
);
```

## UI Usage

### Option 1: Use the Pre-built Button Widget (Recommended)

```dart
import 'package:your_app/widgets/profile_picture_upload_button.dart';

// In your widget
ProfilePictureUploadButton(
  currentImageUrl: userProfilePicUrl, // Optional: show existing image
  size: 100, // Optional: avatar size
  onUploadComplete: (url) {
    // Handle successful upload
    print('New profile picture URL: $url');
    setState(() {
      // Update your UI
    });
  },
)
```

### Option 2: Custom Button Implementation

```dart
import 'package:your_app/services/profile_picture_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

final ProfilePictureService _service = ProfilePictureService();
final user = FirebaseAuth.instance.currentUser;

// In your button's onPressed:
ElevatedButton(
  onPressed: () async {
    if (user == null) return;
    
    final String? url = await _service.updateProfilePicture(
      uid: user.uid,
      context: context,
    );
    
    if (url != null) {
      // Success! Profile picture updated
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
        ),
      );
    }
  },
  child: const Text('Update Profile Picture'),
)
```

## Firestore Structure

After upload, the Firestore document will have:
```
users/
  {uid}/
    profilePic: "https://firebasestorage.googleapis.com/..."
```

## Firebase Storage Structure

Images are stored at:
```
profile_images/
  {uid}.jpg
```

## Features

✅ Cross-platform (Web & Mobile)  
✅ Image quality: 80%  
✅ Automatic compression (max 1024x1024)  
✅ Unique filename: `{uid}.jpg`  
✅ Error handling  
✅ Loading indicators  
✅ User-friendly dialogs  

## Integration with Admin Dashboard

The admin dashboard will automatically display profile pictures because:
1. Images are saved to `profilePic` field in Firestore
2. The admin dashboard checks for `profilePic` field (as updated in previous fix)
3. Images are accessible via download URL

## Example: Complete Profile Page

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:your_app/widgets/profile_picture_upload_button.dart';

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();
    _loadProfilePic();
  }

  Future<void> _loadProfilePic() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      setState(() {
        _profilePicUrl = doc.data()?['profilePic'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProfilePictureUploadButton(
              currentImageUrl: _profilePicUrl,
              size: 120,
              onUploadComplete: (url) {
                setState(() {
                  _profilePicUrl = url;
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Tap to change profile picture',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Notes

- The service handles both Web and Mobile platforms automatically
- Images are compressed to 80% quality and max 1024x1024 pixels
- Each user gets a unique filename: `{uid}.jpg`
- Old images are automatically overwritten when a new one is uploaded
- The `profilePic` field is used (not `profileImageUrl` or other variants)

