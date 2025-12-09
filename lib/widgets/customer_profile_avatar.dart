import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_picture_placeholder.dart';
import 'profile_picture_widget.dart';

/// Widget to display customer profile picture from Firestore
/// Shows actual profile picture if available, otherwise shows placeholder
class CustomerProfileAvatar extends StatelessWidget {
  final String customerId;
  final double size;

  const CustomerProfileAvatar({
    super.key,
    required this.customerId,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (customerId.isEmpty) {
      return CompactProfilePicturePlaceholder(size: size);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>?
            : null;
        final profilePicUrl = 
            (userData?['profileImageUrl'] as String?) ??
            (userData?['profilePic'] as String?);
        
        if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
          return ProfilePictureWidget(
            imageUrl: profilePicUrl,
            size: size,
            placeholder: CompactProfilePicturePlaceholder(size: size),
          );
        }
        // Show placeholder if no profile picture
        return CompactProfilePicturePlaceholder(size: size);
      },
    );
  }
}

