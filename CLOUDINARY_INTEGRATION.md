# ☁️ Cloudinary Integration - Complete Guide

## ✅ Files Created

1. **`lib/services/cloudinary_service.dart`** - Main Cloudinary service
2. **`lib/examples/cloudinary_upload_example.dart`** - Complete examples

## 🔧 Configuration

Replace `YOUR_CLOUD_NAME_HERE` with your actual Cloudinary cloud name in:
- `lib/services/cloudinary_service.dart` (if you want to set default)
- `lib/examples/cloudinary_upload_example.dart`

Or pass it when creating the service:
```dart
final cloudinary = CloudinaryService(
  cloudName: 'your-actual-cloud-name',
  uploadPreset: 'flutter_upload',
);
```

## 📝 Usage Examples

### 1. Basic Upload Function

```dart
import 'package:fleximart/examples/cloudinary_upload_example.dart';

// Simple pick and upload
final imageUrl = await pickAndUpload();
if (imageUrl != null) {
  print('Uploaded: $imageUrl');
}
```

### 2. Upload Product with Image

```dart
import 'package:fleximart/examples/cloudinary_upload_example.dart';

// Upload product to Firestore with Cloudinary image
await uploadProductWithImage();
```

### 3. Display Cloudinary Image

```dart
import 'package:fleximart/examples/cloudinary_upload_example.dart';

// In your widget
CloudinaryImageWidget(
  imageUrl: 'https://res.cloudinary.com/your-cloud/image/upload/...',
  width: 200,
  height: 200,
)
```

### 4. Complete Product Upload Screen

```dart
import 'package:fleximart/examples/cloudinary_upload_example.dart';

// Navigate to product upload screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const ProductUploadExample(),
  ),
);
```

## 🎯 Quick Start

### Step 1: Initialize Service

```dart
final cloudinary = CloudinaryService(
  cloudName: 'your-cloud-name', // Replace this!
  uploadPreset: 'flutter_upload',
);
```

### Step 2: Pick and Upload

```dart
final imageUrl = await cloudinary.pickAndUploadImage(
  source: ImageSource.gallery,
  folder: 'products',
);
```

### Step 3: Save to Firestore

```dart
await FirebaseFirestore.instance.collection('products').add({
  'name': 'Product Name',
  'imageUrl': imageUrl, // Cloudinary URL
  'price': 1000,
  'createdAt': FieldValue.serverTimestamp(),
});
```

### Step 4: Display Image

```dart
Image.network(imageUrl)
```

## 📋 Complete Code Snippets

### Simple Upload

```dart
import 'package:fleximart/services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';

Future<String?> uploadProductImage() async {
  final cloudinary = CloudinaryService(
    cloudName: 'your-cloud-name',
    uploadPreset: 'flutter_upload',
  );

  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);

  if (image == null) return null;

  return await cloudinary.uploadImage(image, folder: 'products');
}
```

### Save Product with Image

```dart
Future<void> addProduct() async {
  final cloudinary = CloudinaryService(
    cloudName: 'your-cloud-name',
    uploadPreset: 'flutter_upload',
  );

  // Upload image
  final imageUrl = await cloudinary.pickAndUploadImage(
    source: ImageSource.gallery,
    folder: 'products',
  );

  if (imageUrl == null) return;

  // Save to Firestore
  await FirebaseFirestore.instance.collection('products').add({
    'name': 'My Product',
    'category': 'Windows',
    'price': 2500,
    'imageUrl': imageUrl,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
```

### Display Image Widget

```dart
Image.network(
  imageUrl,
  loadingBuilder: (context, child, progress) {
    if (progress == null) return child;
    return CircularProgressIndicator();
  },
  errorBuilder: (context, error, stack) {
    return Icon(Icons.broken_image);
  },
)
```

## ⚙️ Service Details

### CloudinaryService Methods

1. **`uploadImage(file, folder?)`**
   - Uploads File or XFile
   - Returns secure URL
   - Throws exception on error

2. **`pickAndUploadImage(source, folder?)`**
   - Picks image from gallery/camera
   - Uploads automatically
   - Returns URL or null if cancelled

## 🔐 Security

- Uses **unsigned upload preset** (no API key needed)
- Upload preset must be set to `unsigned` in Cloudinary dashboard
- Images are organized in `products` folder (optional)

## 📦 Dependencies

Already installed:
- ✅ `http: ^1.2.2`
- ✅ `image_picker: ^1.0.4`

## 🎨 All Examples Included

1. ✅ `pickAndUpload()` - Simple upload function
2. ✅ `uploadProductWithImage()` - Save product to Firestore
3. ✅ `CloudinaryImageWidget` - Display widget with loading/error
4. ✅ `ProductUploadExample` - Complete upload screen

All code is null-safe and ready to use!

