/// HTTP proxy for Firebase Storage reads on Flutter Web (avoids bucket CORS).
class StorageProxyConfig {
  StorageProxyConfig._();

  static const String projectId = 'fleximart-system';
  static const String region = 'us-central1';

  static String get baseUrl =>
      'https://$region-$projectId.cloudfunctions.net/serveStorageImage';

  static String imageUrl(String storagePath) {
    return '$baseUrl?path=${Uri.encodeComponent(storagePath)}';
  }
}
