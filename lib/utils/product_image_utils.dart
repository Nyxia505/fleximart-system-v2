import 'image_url_helper.dart';

/// Resolves a displayable product image string from Firestore product data.
/// Prefers [imageUrl], then [image]. Supports existing Firebase/Cloudinary URLs.
String resolveProductImageString(Map<String, dynamic> product) {
  final candidates = [
    product['imageUrl']?.toString(),
    product['image']?.toString(),
    product['img']?.toString(),
  ];

  for (final value in candidates) {
    if (value == null) continue;
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    return trimmed;
  }
  return '';
}

/// True when [value] should be loaded with [Image.network] / [ProductImageWidget].
bool isNetworkProductImage(String value) {
  if (value.startsWith('data:image/')) return false;
  if (value.length > 100 && !value.startsWith('http')) {
    return false; // likely raw base64
  }
  return ImageUrlHelper.isValidImageUrl(value);
}

/// Writes [imageUrl] to both `imageUrl` and `image` on Firestore product maps.
void applyProductImageFields(Map<String, dynamic> data, String imageUrl) {
  final url = imageUrl.trim();
  if (url.isEmpty) return;
  data['imageUrl'] = url;
  data['image'] = url;
}

/// Writes product display name to both `name` and `title`.
void applyProductNameFields(Map<String, dynamic> data, String name) {
  final n = name.trim();
  if (n.isEmpty) return;
  data['name'] = n;
  data['title'] = n;
}
