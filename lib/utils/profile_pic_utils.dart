/// Reads profile picture URL from Firestore user document fields.
/// Primary: [profilePic], fallback: [profileImageUrl].
String? profilePicUrlFromUserData(Map<String, dynamic>? userData) {
  if (userData == null) return null;
  final profilePic = userData['profilePic'] as String?;
  if (profilePic != null && profilePic.isNotEmpty) return profilePic;
  final profileImageUrl = userData['profileImageUrl'] as String?;
  if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
    return profileImageUrl;
  }
  return null;
}
