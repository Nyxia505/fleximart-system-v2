import 'package:flutter/material.dart';
import 'user_profile_avatar.dart';

/// Customer profile avatar — delegates to [UserProfileAvatar].
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
    return UserProfileAvatar(userId: customerId, size: size);
  }
}
