import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/profile_pic_utils.dart';
import 'profile_picture_placeholder.dart';
import 'profile_picture_widget.dart';

/// Displays a user's profile picture from Firestore + Storage.
class UserProfileAvatar extends StatelessWidget {
  final String userId;
  final double size;

  const UserProfileAvatar({
    super.key,
    required this.userId,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return CompactProfilePicturePlaceholder(size: size);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>?
            : null;
        final profilePicUrl = profilePicUrlFromUserData(userData);

        return ProfilePictureWidget(
          key: ValueKey('user_avatar_${userId}_$profilePicUrl'),
          storageUserId: userId,
          imageUrl: profilePicUrl,
          size: size,
          placeholder: CompactProfilePicturePlaceholder(size: size),
        );
      },
    );
  }
}
