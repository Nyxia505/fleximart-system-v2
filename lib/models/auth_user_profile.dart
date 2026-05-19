/// Firestore user profile fields used during signup and verification.
class AuthUserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String role;
  final bool emailVerified;

  const AuthUserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.emailVerified = false,
  });

  factory AuthUserProfile.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    return AuthUserProfile(
      uid: uid,
      fullName: (data['fullName'] as String?) ??
          (data['name'] as String?) ??
          '',
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'customer',
      emailVerified: data['emailVerified'] == true ||
          data['isVerified'] == true,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'fullName': fullName,
      'email': email,
      'role': role,
      'emailVerified': emailVerified,
      'isVerified': emailVerified,
      'profilePic': '',
      'profileImageUrl': '',
      'phoneNumber': '',
      'address': '',
      'createdAt': null, // set with FieldValue.serverTimestamp() in service
    };
  }
}
