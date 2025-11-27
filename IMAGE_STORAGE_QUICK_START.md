# Image Storage - Quick Start Guide

## 🎯 3 Ways to Use

### Method 1: Use the Demo Screen (Easiest!)

```dart
// Navigate to the demo screen from anywhere in your app
Navigator.pushNamed(context, '/image-demo');
```

**This gives you:**
- ✅ Button to pick & upload images
- ✅ Display of uploaded images
- ✅ Full UI with instructions
- ✅ Error handling built-in

---

### Method 2: Use the Service Directly

```dart
import 'package:fleximart_new/services/image_storage_service.dart';

// In your widget
final ImageStorageService imageService = ImageStorageService();

// Pick and upload
ElevatedButton(
  onPressed: () async {
    final String? docId = await imageService.pickAndStoreImage();
    if (docId != null) {
      print('Uploaded! ID: $docId');
    }
  },
  child: const Text('Upload Image'),
)
```

---

### Method 3: Use the Display Widget

```dart
import 'package:fleximart_new/widgets/image_display_widget.dart';

// In your screen
const ImageDisplayWidget()  // That's it!
```

**This automatically:**
- ✅ Fetches latest image from Firestore
- ✅ Decodes Base64 to image
- ✅ Displays with loading/error states
- ✅ Shows image metadata

---

## 📦 What You Get

### 1. ImageStorageService
```dart
// Pick image → Convert to Base64 → Store in Firestore
await imageService.pickAndStoreImage()

// Get first stored image
await imageService.getFirstStoredImage()

// Get all images
await imageService.getAllStoredImages()

// Delete image
await imageService.deleteImage(documentId)
```

### 2. ImageDisplayWidget
- Automatic loading
- Error handling
- Retry functionality
- Metadata display

### 3. ImageDemoScreen
- Complete working example
- Instructions
- Upload status
- Live preview

---

## 🚀 How It Works

```
1. User taps button
   ↓
2. Opens gallery (image_picker)
   ↓
3. User selects image
   ↓
4. Convert to Base64 (base64Encode)
   ↓
5. Store in Firestore collection "images"
   ↓
6. Retrieve from Firestore
   ↓
7. Decode Base64 (base64Decode)
   ↓
8. Display with Image.memory()
```

---

## 📝 Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:fleximart_new/services/image_storage_service.dart';
import 'package:fleximart_new/widgets/image_display_widget.dart';

class MyImageScreen extends StatelessWidget {
  final ImageStorageService imageService = ImageStorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Images'),
      ),
      body: Column(
        children: [
          // Upload button
          ElevatedButton(
            onPressed: () async {
              final docId = await imageService.pickAndStoreImage();
              if (docId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Uploaded! ID: $docId')),
                );
              }
            },
            child: const Text('Pick & Upload Image'),
          ),
          
          // Display widget
          const Expanded(
            child: ImageDisplayWidget(),
          ),
        ],
      ),
    );
  }
}
```

---

## 🎨 Customize

### Change Compression Quality
```dart
// In image_storage_service.dart, line 27:
imageQuality: 70,  // Lower = smaller file
```

### Use Camera Instead
```dart
// In image_storage_service.dart, line 26:
source: ImageSource.camera,  // Instead of gallery
```

### Style the Display Widget
```dart
// Wrap in your own styling
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    boxShadow: [...],
  ),
  child: const ImageDisplayWidget(),
)
```

---

## ⚠️ Important

### Image Size Limit
- **Firestore limit:** 1 MB per document
- **Default compression:** 85% quality
- **Tip:** Lower quality for smaller files

### Permissions Required

**iOS** - Add to `ios/Runner/Info.plist`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to select images</string>
```

**Android** - Already configured in AndroidManifest.xml

### Firestore Rules
Already deployed! ✅

If you need to redeploy:
```bash
firebase deploy --only "firestore:rules"
```

---

## 🧪 Test Now!

### Quick Test (2 minutes):

1. Run your app:
   ```bash
   flutter run
   ```

2. Navigate to demo screen:
   ```dart
   Navigator.pushNamed(context, '/image-demo');
   ```

3. Click "Pick & Upload Image"

4. Select an image from gallery

5. See it uploaded and displayed!

---

## 📊 Firestore Structure

**Collection:** `images`

```json
{
  "base64String": "iVBORw0KGgo...",  // The image
  "timestamp": "2025-11-09 10:30:00", // When uploaded
  "fileName": "image_123.jpg",         // Original name
  "fileSizeBytes": 245678,             // Size in bytes
  "uploadedAt": "2025-11-09T10:30:00"  // ISO timestamp
}
```

---

## 💡 Common Use Cases

### Profile Picture Upload
```dart
// In profile screen
ElevatedButton(
  onPressed: () async {
    final docId = await imageService.pickAndStoreImage();
    // Save docId to user profile in Firestore
  },
  child: const Text('Change Profile Picture'),
)
```

### Product Images (E-commerce)
```dart
// When adding product
final imageDocId = await imageService.pickAndStoreImage();
// Store imageDocId with product data
```

### Gallery/Portfolio
```dart
// Display all images
FutureBuilder<List<Map<String, dynamic>>>(
  future: imageService.getAllStoredImages(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    return GridView.builder(...);
  },
)
```

---

## 🎉 That's It!

You now have a complete image storage solution with:
- ✅ Image picking from gallery
- ✅ Base64 encoding
- ✅ Firestore storage
- ✅ Image display
- ✅ Error handling
- ✅ Full documentation

**Start testing:** `Navigator.pushNamed(context, '/image-demo')`

---

**Need more details?** Read `IMAGE_STORAGE_GUIDE.md`

**Having issues?** Check the troubleshooting section in the guide

**Ready to customize?** All code is well-commented and easy to modify!

