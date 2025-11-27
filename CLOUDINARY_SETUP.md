# ☁️ Cloudinary Setup Guide

## ✅ STEP 1 — Verify Packages

The required packages are already installed in your `pubspec.yaml`:
- ✅ `http: ^1.2.2`
- ✅ `image_picker: ^1.0.4`

## ✅ STEP 2 — Create Unsigned Upload Preset

1. Go to [Cloudinary Dashboard](https://console.cloudinary.com/)
2. Left menu → **Settings**
3. Click **Upload** tab
4. Scroll to **Upload presets**
5. Click **Add upload preset**
6. Set:
   - **Preset name**: `flutter_upload`
   - **Signing mode**: `unsigned` ✔
   - **Folder**: `products` (optional)
7. Click **Save**

📌 **Copy your upload preset name** → `flutter_upload`

## ✅ STEP 3 — Get Your Cloud Name

1. In Cloudinary Dashboard, go to **Settings** → **Product Environment Credentials**
2. Copy your **Cloud Name** (e.g., `dxyz123abc`)

## 📱 STEP 4 — Use in Flutter

### Basic Usage

```dart
import 'package:fleximart/services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';

// Initialize service
final cloudinary = CloudinaryService(
  cloudName: 'your-cloud-name',  // Replace with your cloud name
  uploadPreset: 'flutter_upload',
);

// Upload image from picker
final imageUrl = await cloudinary.pickAndUploadImage(
  source: ImageSource.gallery,
  folder: 'products',  // Optional
);

if (imageUrl != null) {
  print('Image uploaded: $imageUrl');
  // Use imageUrl in your app
}
```

### Upload Existing File

```dart
// If you already have a File or XFile
final imageUrl = await cloudinary.uploadImage(
  imageFile,
  folder: 'products',
);
```

### Example: Upload Product Image

```dart
Future<void> addProductWithImage() async {
  final cloudinary = CloudinaryService(
    cloudName: 'your-cloud-name',
    uploadPreset: 'flutter_upload',
  );

  // Pick and upload image
  final imageUrl = await cloudinary.pickAndUploadImage(
    source: ImageSource.gallery,
    folder: 'products',
  );

  if (imageUrl == null) {
    // User cancelled
    return;
  }

  // Save product with image URL
  await FirebaseFirestore.instance.collection('products').add({
    'name': 'Product Name',
    'imageUrl': imageUrl,  // Cloudinary URL
    'price': 1000,
    // ... other fields
  });
}
```

## 🔧 Configuration

### Environment Variables (Recommended)

Create a config file or use environment variables:

```dart
// lib/config/cloudinary_config.dart
class CloudinaryConfig {
  static const String cloudName = 'your-cloud-name';
  static const String uploadPreset = 'flutter_upload';
}
```

Then use:
```dart
final cloudinary = CloudinaryService(
  cloudName: CloudinaryConfig.cloudName,
  uploadPreset: CloudinaryConfig.uploadPreset,
);
```

## 📝 Service Features

✅ **Unsigned Uploads** - No API key needed  
✅ **Automatic Image Optimization** - Cloudinary optimizes images  
✅ **Folder Organization** - Organize images in folders  
✅ **Error Handling** - Comprehensive error messages  
✅ **Debug Logging** - Helpful debug output  

## 🎯 Response Format

Cloudinary returns:
```json
{
  "public_id": "products/abc123",
  "secure_url": "https://res.cloudinary.com/your-cloud/image/upload/v123/products/abc123.jpg",
  "url": "http://res.cloudinary.com/your-cloud/image/upload/v123/products/abc123.jpg",
  "width": 1920,
  "height": 1080,
  "format": "jpg",
  "bytes": 123456
}
```

The service returns the `secure_url` (HTTPS) by default.

## ⚠️ Important Notes

1. **Unsigned Upload Preset**: Must be set to `unsigned` mode
2. **Cloud Name**: Required - get it from Cloudinary dashboard
3. **File Size**: Cloudinary has free tier limits (check your plan)
4. **Security**: Unsigned uploads are public - use folders to organize
5. **Deletion**: Image deletion requires API authentication (not included in unsigned preset)

## 🐛 Troubleshooting

### Error: "Invalid upload preset"
- Check preset name matches exactly: `flutter_upload`
- Verify preset is set to `unsigned` mode
- Make sure preset is saved in Cloudinary dashboard

### Error: "Invalid cloud name"
- Verify cloud name is correct (no spaces, lowercase)
- Check Cloudinary dashboard → Settings → Product Environment Credentials

### Upload fails
- Check internet connection
- Verify image file is valid
- Check Cloudinary service status
- Review debug console output

## 📚 Resources

- [Cloudinary Documentation](https://cloudinary.com/documentation)
- [Flutter Image Picker](https://pub.dev/packages/image_picker)
- [HTTP Package](https://pub.dev/packages/http)

