import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/auth_provider.dart' as app_auth;
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../pages/chat_list_page.dart';
import '../screen/payment_methods_screen.dart';
import '../utils/price_formatter.dart';
import '../widgets/profile_picture_widget.dart';
import '../utils/image_url_helper.dart';
import 'home_purchases_ui.dart';

class DashboardProfile extends StatefulWidget {
  const DashboardProfile({super.key});

  @override
  State<DashboardProfile> createState() => _DashboardProfileState();
}

class _DashboardProfileState extends State<DashboardProfile> {
  Future<void> _pickProfileImage(String userId) async {
    debugPrint('📸 _pickProfileImage called with userId: $userId');

    if (userId.isEmpty) {
      debugPrint('❌ User ID is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User ID is missing'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) {
      debugPrint('❌ Widget not mounted');
      return;
    }

    debugPrint('✅ Showing image source dialog');

    try {
      // Show dialog to choose image source - use Navigator.of to ensure proper context
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        useRootNavigator: false,
        builder: (dialogContext) {
          debugPrint('🔨 Dialog builder called');
          return Material(
            type: MaterialType.transparency,
            child: Center(
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Select Image Source',
                  style: AppTextStyles.heading3(),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        debugPrint('📷 Gallery selected');
                        Navigator.pop(dialogContext, ImageSource.gallery);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.photo_library,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          'Gallery',
                          style: AppTextStyles.bodyLarge(),
                        ),
                      ),
                    ),
                    const Divider(),
                    InkWell(
                      onTap: () {
                        debugPrint('📸 Camera selected');
                        Navigator.pop(dialogContext, ImageSource.camera);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        title: Text('Camera', style: AppTextStyles.bodyLarge()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      debugPrint('📸 Dialog returned with source: $source');

      if (source == null) {
        debugPrint('❌ No image source selected (user cancelled)');
        return;
      }

      debugPrint('📸 Image source selected: $source');

      // Show loading indicator
      if (!mounted) {
        debugPrint('❌ Widget not mounted before showing loading');
        return;
      }

      BuildContext? loadingDialogContext;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingCtx) {
          loadingDialogContext = loadingCtx;
          debugPrint('⏳ Loading dialog shown');
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          );
        },
      );

      try {
        debugPrint('📤 Starting image upload process');
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }

        // Refresh the user's authentication token to ensure it's valid
        try {
          await user.reload();
          final refreshedUser = FirebaseAuth.instance.currentUser;
          if (refreshedUser == null) {
            throw Exception(
              'User authentication expired. Please log in again.',
            );
          }
          debugPrint('✅ User authentication verified: ${refreshedUser.uid}');
        } catch (authError) {
          debugPrint('⚠️ Auth refresh warning: $authError (continuing anyway)');
          // Continue anyway, as the user might still be valid
        }

        // Pick image
        debugPrint(
          '📷 Picking image from ${source == ImageSource.gallery ? "gallery" : "camera"}...',
        );
        final ImagePicker picker = ImagePicker();

        // Add a small delay to ensure dialog is fully closed
        await Future.delayed(const Duration(milliseconds: 300));

        final XFile? image = await picker
            .pickImage(
              source: source,
              maxWidth: 512,
              maxHeight: 512,
              imageQuality: 85,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint('❌ Image picker timeout');
                throw Exception('Image picker timed out. Please try again.');
              },
            );

        if (image == null) {
          // User cancelled
          debugPrint('❌ User cancelled image picker');
          if (mounted && loadingDialogContext != null) {
            Navigator.pop(loadingDialogContext!);
          }
          return;
        }

        debugPrint('✅ Image picked: ${image.path}');
        // Read image as bytes
        debugPrint('📖 Reading image bytes...');
        final Uint8List imageBytes = await image.readAsBytes();
        debugPrint('📖 Image bytes read: ${imageBytes.length} bytes');

        if (imageBytes.isEmpty) {
          throw Exception('Failed to read image data');
        }

        debugPrint('📤 Uploading to Firebase Storage...');
        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');

        await storageRef
            .putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'))
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint('❌ Upload timeout');
                throw Exception(
                  'Upload timeout. Please check your internet connection.',
                );
              },
            );

        debugPrint('✅ Upload completed, getting download URL...');
        // Get download URL
        final downloadUrl = await storageRef.getDownloadURL().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('❌ Get download URL timeout');
            throw Exception('Failed to get download URL. Please try again.');
          },
        );

        if (downloadUrl.isEmpty) {
          throw Exception('Invalid download URL received');
        }

        debugPrint('✅ Download URL: $downloadUrl');
        // Update Firestore - save to both profilePic (primary) and profileImageUrl (backward compatibility)
        debugPrint('💾 Saving to Firestore...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'profilePic': downloadUrl,
              'profileImageUrl': downloadUrl, // Keep for backward compatibility
            });
        debugPrint('✅ Firestore updated with image URL');

        // Verify the update was successful
        final verifyDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final verifyData = verifyDoc.data();
        debugPrint('🔍 Verifying Firestore update:');
        debugPrint('   profilePic: ${verifyData?['profilePic']}');
        debugPrint('   profileImageUrl: ${verifyData?['profileImageUrl']}');

        // Force a rebuild by calling setState
        if (mounted) {
          setState(() {});
          debugPrint('🔄 setState called to force rebuild');
        }

        // Close loading dialog
        if (mounted && loadingDialogContext != null) {
          Navigator.pop(loadingDialogContext!);
          debugPrint('✅ Loading dialog closed');
        }

        if (!mounted) return;
        debugPrint('✅ Profile picture updated successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } catch (e, stackTrace) {
        debugPrint('❌ Error uploading image: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        // Close loading dialog
        if (mounted && loadingDialogContext != null) {
          Navigator.pop(loadingDialogContext!);
        }
        if (!mounted) return;

        // Provide user-friendly error messages
        String errorMessage = 'Failed to upload profile picture';
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('unauthorized') ||
            errorString.contains('permission denied')) {
          errorMessage =
              'Permission denied. Please make sure you are logged in and try again.';
          debugPrint(
            '🔐 Authorization error detected - user may not be authenticated properly',
          );
        } else if (errorString.contains('network') ||
            errorString.contains('connection')) {
          errorMessage =
              'Network error. Please check your internet connection and try again.';
        } else if (errorString.contains('timeout')) {
          errorMessage =
              'Upload timeout. Please check your connection and try again.';
        } else if (errorString.contains('storage') ||
            errorString.contains('firebase')) {
          errorMessage =
              'Storage error. Please check Firebase Storage rules and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _pickProfileImage(userId),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error showing dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your profile')),
      );
    }

    // Stream user profile data from Firestore for real-time updates
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
          );
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final displayName =
            userData['fullName'] as String? ??
            user.displayName ??
            user.email?.split('@')[0] ??
            'User';
        final userEmail = user.email ?? 'No email';
        final userPhone =
            userData['phoneNumber'] as String? ??
            userData['phone'] as String? ??
            'No phone number';
        final profileImageUrl =
            (userData['profilePic'] as String?) ??
            (userData['profileImageUrl'] as String?);

        debugPrint('📸 Profile image URL from Firestore: $profileImageUrl');

        return _buildProfileContent(
          context,
          displayName,
          userEmail,
          userPhone,
          user.uid,
          profileImageUrl,
        );
      },
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    String displayName,
    String userEmail,
    String userPhone,
    String userId,
    String? profileImageUrl,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomNavHeight = 70.0; // Height of bottom navigation bar
            final safeAreaBottom = MediaQuery.of(context).padding.bottom;
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: safeAreaBottom + bottomNavHeight + keyboardHeight + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    decoration: BoxDecoration(
                      gradient: AppColors.mainGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            debugPrint(
                              '👆 Profile picture tapped, userId: $userId',
                            );
                            _pickProfileImage(userId);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                ClipOval(
                                  key: ValueKey(
                                    'profile_avatar_${userId}_$profileImageUrl',
                                  ),
                                  child:
                                      (profileImageUrl != null &&
                                          profileImageUrl.isNotEmpty)
                                      ? _ProfileImageWidget(
                                          imageUrl: profileImageUrl,
                                          userId: userId,
                                          width: 64,
                                          height: 64,
                                        )
                                      : Container(
                                          width: 64,
                                          height: 64,
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.person,
                                            size: 32,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      debugPrint('👆 Camera icon tapped');
                                      _pickProfileImage(userId);
                                    },
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.buttonGradient,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withOpacity(0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white, // Pure white (#FFFFFF)
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.email_outlined,
                                    size: 16,
                                    color: Colors.white, // Pure white (#FFFFFF)
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      userEmail,
                                      style: const TextStyle(
                                        color: Colors
                                            .white, // Pure white (#FFFFFF)
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 16,
                                    color: Colors.white, // Pure white (#FFFFFF)
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      userPhone,
                                      style: const TextStyle(
                                        color: Colors
                                            .white, // Pure white (#FFFFFF)
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  // My Purchases Section - New Clean Design
                  const HomePurchasesUI(),
                  const SizedBox(height: 40),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // User Profile Section
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: StreamBuilder<DocumentSnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots()
                  : null,
              builder: (context, snapshot) {
                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                final fullName =
                    userData?['fullName'] as String? ??
                    user?.displayName ??
                    'User';
                final email =
                    userData?['email'] as String? ?? user?.email ?? 'No email';
                final profileImageUrl = userData?['profileImageUrl'] as String?;

                return InkWell(
                  onTap: () {
                    final phone = userData?['phone'] as String? ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileDetailsScreen(
                          fullName: fullName,
                          email: email,
                          phone: phone,
                          profileImageUrl: profileImageUrl,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      // Profile Picture
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.15),
                              AppColors.secondary.withOpacity(0.12),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child:
                            profileImageUrl != null &&
                                profileImageUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  ImageUrlHelper.encodeUrl(profileImageUrl),
                                  fit: BoxFit.cover,
                                  cacheWidth: kIsWeb ? null : 200,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 32,
                                      color: AppColors.primary,
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        );
                                      },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 32,
                                color: AppColors.primary,
                              ),
                      ),
                      const SizedBox(width: 16),
                      // Name and Email
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName, style: AppTextStyles.heading3()),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Arrow Icon
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingsCard(
            children: [
              _buildSettingItem(
                context,
                icon: Icons.person_outline,
                title: 'Edit Profile',
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditUsernameScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 64),
              _buildSettingItem(
                context,
                icon: Icons.lock_outline,
                title: 'Change Password',
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacySecurityScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 64),
              _buildSettingItem(
                context,
                icon: Icons.credit_card_outlined,
                title: 'Payment Methods',
                color: AppColors.info,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PaymentMethodsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          // Preferences Section
          _buildSectionHeader('Preferences'),
          _buildSettingsCard(
            children: [
              _buildSettingItem(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notification Preferences',
                color: AppColors.toInstall,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsSettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 64),
              _buildSettingItem(
                context,
                icon: Icons.palette_outlined,
                title: 'Theme & Display',
                color: Colors.purple,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Theme settings coming soon'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              ),
            ],
          ),

          // Security & Privacy Section
          _buildSectionHeader('Security & Privacy'),
          _buildSettingsCard(
            children: [
              _buildSettingItem(
                context,
                icon: Icons.lock_outline,
                title: 'Privacy Settings',
                color: AppColors.cancelled,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacySecurityScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 64),
              _buildSettingItem(
                context,
                icon: Icons.block_outlined,
                title: 'Blocked Users',
                color: AppColors.textSecondary,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Blocked users feature coming soon'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              ),
            ],
          ),

          // Support Section
          _buildSectionHeader('Support'),
          _buildSettingsCard(
            children: [
              _buildSettingItem(
                context,
                icon: Icons.help_outline,
                title: 'Help & FAQ',
                color: AppColors.primary,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(
                        'Help & FAQ',
                        style: AppTextStyles.heading3(),
                      ),
                      content: const Text(
                        'Frequently Asked Questions:\n\n'
                        '• How do I place an order?\n'
                        '• How do I track my order?\n'
                        '• What payment methods are accepted?\n'
                        '• How do I request a quotation?\n\n'
                        'For more help, contact support.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'OK',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 64),
              _buildSettingItem(
                context,
                icon: Icons.support_agent_outlined,
                title: 'Contact Support',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListPage()),
                  );
                },
              ),
            ],
          ),

          // Logout Section
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text('Logout', style: AppTextStyles.heading3()),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                  if (shouldLogout == true) {
                    await context.read<app_auth.AuthProvider>().signOut();
                    if (!context.mounted) return;
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                child: Text(
                  'Logout',
                  style: AppTextStyles.buttonMedium(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.heading3().copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: AppTextStyles.bodyLarge()),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

// Edit Username Screen
class EditUsernameScreen extends StatefulWidget {
  const EditUsernameScreen({super.key});

  @override
  State<EditUsernameScreen> createState() => _EditUsernameScreenState();
}

class _EditUsernameScreenState extends State<EditUsernameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;
  bool _uploadingImage = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final authProvider = context.read<app_auth.AuthProvider>();
        _nameController.text = authProvider.displayName ?? '';

        // Load phone number and profile image from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        _phoneController.text = userData?['phone'] as String? ?? '';
        _profileImageUrl = userData?['profileImageUrl'] as String?;
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to upload profile image'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Show dialog to choose image source
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Select Image Source', style: AppTextStyles.heading3()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              title: Text('Gallery', style: AppTextStyles.bodyLarge()),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              title: Text('Camera', style: AppTextStyles.bodyLarge()),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image == null) return;

    // Show loading indicator
    if (!mounted) return;
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        dialogContext = dialogCtx;
        return Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        );
      },
    );

    try {
      // Read image as bytes
      final Uint8List imageBytes = await image.readAsBytes();

      if (imageBytes.isEmpty) {
        throw Exception('Failed to read image data');
      }

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      await storageRef
          .putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Upload timeout. Please check your internet connection.',
              );
            },
          );

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Failed to get download URL. Please try again.');
        },
      );

      if (downloadUrl.isEmpty) {
        throw Exception('Invalid download URL received');
      }

      // Update Firestore - save to both profilePic (primary) and profileImageUrl (backward compatibility)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'profilePic': downloadUrl,
          'profileImageUrl': downloadUrl, // Keep for backward compatibility
        },
      );

      // Update local state
      if (mounted) {
        setState(() {
          _profileImageUrl = downloadUrl;
        });
      }

      // Close loading dialog
      if (mounted && dialogContext != null) {
        Navigator.pop(dialogContext!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (mounted && dialogContext != null) {
        Navigator.pop(dialogContext!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a username')));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'fullName': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
          });

      await user.updateDisplayName(_nameController.text.trim());

      // Refresh AuthProvider to reflect the change
      if (mounted) {
        await context.read<app_auth.AuthProvider>().refreshProfile();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      // Check if address is still needed
      final addressesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .limit(1)
          .get();

      if (addressesSnapshot.docs.isEmpty) {
        // Still need address, show option to add
        if (!mounted) return;
        final addAddress = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add Address'),
            content: const Text(
              'You still need to add an address to complete your profile. Would you like to add one now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Address'),
              ),
            ],
          ),
        );

        if (addAddress == true && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditAddressScreen(),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Image Section
            Center(
              child: Stack(
                children: [
                  // Profile Picture - Use ProfilePictureWidget
                  _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? _uploadingImage
                            ? SizedBox(
                                width: 100,
                                height: 100,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : ProfilePictureWidget(
                                imageUrl: _profileImageUrl!,
                                size: 100,
                                backgroundColor: Colors.grey[300],
                                placeholder: Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, size: 50),
                                ),
                              )
                      : CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          child: _uploadingImage
                              ? const CircularProgressIndicator(
                                  color: AppColors.primary,
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                        ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _uploadingImage ? null : _pickProfileImage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _uploadingImage
                              ? Colors.grey
                              : AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _uploadingImage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap camera icon to change photo',
                style: AppTextStyles.caption(color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                hintText: 'Enter your phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyAddressesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Manage Addresses'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Purchase History Screen
class PurchaseHistoryScreen extends StatelessWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view purchase history'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No purchase history found'));
                }

                // Sort by createdAt in memory (descending - newest first)
                final docs = List<QueryDocumentSnapshot>.from(
                  snapshot.data!.docs,
                );
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aCreated = aData['createdAt'] as Timestamp?;
                  final bCreated = bData['createdAt'] as Timestamp?;

                  if (aCreated == null && bCreated == null) return 0;
                  if (aCreated == null) return 1;
                  if (bCreated == null) return -1;
                  return bCreated.compareTo(aCreated); // Descending
                });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text('Order #${doc.id.substring(0, 8)}'),
                        subtitle: Text(
                          'Total: ${PriceFormatter.formatPrice((data['total'] as num?)?.toDouble() ?? 0.0)}\n'
                          'Status: ${data['status'] ?? 'Unknown'}',
                        ),
                        trailing: Icon(
                          _getStatusIcon(data['status'] ?? 'pending'),
                          color: _getStatusColor(data['status'] ?? 'pending'),
                        ),
                        isThreeLine: true,
                        onTap: () {
                          // Could navigate to order details here
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'processing':
        return Icons.local_shipping;
      case 'shipped':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.accent; // Orange
      case 'processing':
        return AppColors.secondary; // Blue
      case 'shipped':
        return AppColors.secondary; // Blue
      case 'delivered':
        return AppColors.primary; // Green
      default:
        return AppColors.textSecondary; // Gray
    }
  }
}

// Orders Filter Screen
class OrdersFilterScreen extends StatelessWidget {
  final String filterKey; // to_pay, to_install, to_receive, to_rate

  const OrdersFilterScreen({super.key, required this.filterKey});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final titleMap = {
      'to_pay': 'To Pay',
      'to_install': 'To Install',
      'to_receive': 'To Receive',
      'to_rate': 'To Rate',
    };
    final statusTitle = titleMap[filterKey] ?? 'Orders';

    return Scaffold(
      appBar: AppBar(
        title: Text('Orders - $statusTitle'),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view orders'))
          : StreamBuilder<QuerySnapshot>(
              stream: _buildOrdersQuery(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No orders with status: $statusTitle',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter orders by status in memory (to avoid composite index requirements)
                final allDocs = snapshot.data!.docs;
                final filteredDocs = _filterOrdersByStatus(allDocs);

                // Sort by createdAt in memory (descending - newest first)
                final sortedDocs = List<QueryDocumentSnapshot>.from(
                  filteredDocs,
                );
                sortedDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aCreated = aData['createdAt'] as Timestamp?;
                  final bCreated = bData['createdAt'] as Timestamp?;

                  if (aCreated == null && bCreated == null) return 0;
                  if (aCreated == null) return 1;
                  if (bCreated == null) return -1;
                  return bCreated.compareTo(aCreated); // Descending
                });

                if (sortedDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No orders with status: $statusTitle',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: AppColors.dashboardCard,
                      child: ListTile(
                        title: Text(
                          'Order #${doc.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Total: ${PriceFormatter.formatPrice(((data['totalPrice'] ?? data['totalAmount'] ?? data['total']) as num?)?.toDouble() ?? 0.0)}\n'
                          'Items: ${(data['items'] as List?)?.length ?? 0}\n'
                          'Status: ${(data['status'] as String?) ?? 'Pending'}\n'
                          'Date: ${_formatDate(data['createdAt'])}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: Icon(
                          _getStatusIcon((data['status'] as String?) ?? ''),
                          color: _getStatusColor(
                            (data['status'] as String?) ?? '',
                          ),
                        ),
                        isThreeLine: true,
                        onTap: () {
                          // Could navigate to order details here
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'processing':
        return Icons.local_shipping;
      case 'shipped':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.accent; // Orange
      case 'processing':
        return AppColors.secondary; // Blue
      case 'shipped':
        return AppColors.secondary; // Blue
      case 'delivered':
        return AppColors.primary; // Green
      default:
        return AppColors.textSecondary; // Gray
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown date';
  }

  List<QueryDocumentSnapshot> _filterOrdersByStatus(
    List<QueryDocumentSnapshot> docs,
  ) {
    switch (filterKey) {
      case 'to_pay':
        // Already filtered by query, but double-check
        return docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? '';
          return status.toLowerCase() == 'pending';
        }).toList();
      case 'to_install':
        // Orders ready for installation
        final installStatuses = [
          'processing',
          'Processing',
          'approved',
          'Approved',
          'install_scheduled',
          'to_install',
          'To Install',
        ];
        return docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? '';
          return installStatuses.contains(status);
        }).toList();
      case 'to_receive':
        // Shipped orders awaiting receipt
        final receiveStatuses = ['shipped', 'Shipped', 'Out for Delivery'];
        return docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? '';
          return receiveStatuses.contains(status);
        }).toList();
      case 'to_rate':
        // Completed orders that can be rated
        final rateStatuses = [
          'delivered',
          'Delivered',
          'completed',
          'Completed',
        ];
        return docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? '';
          return rateStatuses.contains(status);
        }).toList();
      default:
        return docs;
    }
  }
}

extension on OrdersFilterScreen {
  Query _buildOrdersQuery(String userId) {
    final col = FirebaseFirestore.instance.collection('orders');
    // Query by customerId only - sort in memory to avoid composite index requirements
    switch (filterKey) {
      case 'to_pay':
        // Unpaid orders or pending orders - filter by status in memory
        return col.where('customerId', isEqualTo: userId);
      case 'to_install':
      case 'to_receive':
      case 'to_rate':
      default:
        // Query all customer orders and filter/sort in memory
        return col.where('customerId', isEqualTo: userId);
    }
  }
}

// My Addresses Screen
class MyAddressesScreen extends StatelessWidget {
  const MyAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditAddressScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view addresses'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('addresses')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No addresses saved',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AddEditAddressScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Address'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isDefault = data['isDefault'] ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: isDefault
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          data['label'] ?? 'Address',
                          style: TextStyle(
                            fontWeight: isDefault
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(data['address'] ?? ''),
                            if (data['city'] != null) Text(data['city'] ?? ''),
                            if (data['postalCode'] != null)
                              Text(data['postalCode'] ?? ''),
                            if (isDefault)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEB593C,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 12, // Increased for clarity
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Edit'),
                              onTap: () {
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddEditAddressScreen(
                                              addressId: doc.id,
                                              initialData: data,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Set as Default'),
                              onTap: () async {
                                final batch = FirebaseFirestore.instance
                                    .batch();

                                // Remove default from all addresses
                                final allAddresses = await FirebaseFirestore
                                    .instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('addresses')
                                    .get();

                                for (var addrDoc in allAddresses.docs) {
                                  batch.update(addrDoc.reference, {
                                    'isDefault': false,
                                  });
                                }

                                // Set this as default
                                batch.update(doc.reference, {
                                  'isDefault': true,
                                });
                                await batch.commit();
                              },
                            ),
                            PopupMenuItem(
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: AppColors.error),
                              ),
                              onTap: () async {
                                await doc.reference.delete();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Address deleted'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// Add/Edit Address Screen
class AddEditAddressScreen extends StatefulWidget {
  final String? addressId;
  final Map<String, dynamic>? initialData;

  const AddEditAddressScreen({super.key, this.addressId, this.initialData});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  bool _isDefault = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _labelController.text = widget.initialData!['label'] ?? '';
      _addressController.text = widget.initialData!['address'] ?? '';
      _cityController.text = widget.initialData!['city'] ?? '';
      _postalCodeController.text = widget.initialData!['postalCode'] ?? '';
      _isDefault = widget.initialData!['isDefault'] ?? false;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final addressData = {
        'label': _labelController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'isDefault': _isDefault,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.addressId == null) {
        addressData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .add(addressData);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .doc(widget.addressId)
            .update(addressData);
      }

      // If setting as default, remove default from others
      if (_isDefault) {
        final batch = FirebaseFirestore.instance.batch();
        final allAddresses = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .get();

        for (var addrDoc in allAddresses.docs) {
          if (addrDoc.id != widget.addressId) {
            batch.update(addrDoc.reference, {'isDefault': false});
          }
        }
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.addressId == null
                ? 'Address added successfully'
                : 'Address updated successfully',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.addressId == null ? 'Add Address' : 'Edit Address'),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (e.g., Home, Office)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Please enter a label' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Street Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
              validator: (value) => value?.trim().isEmpty ?? true
                  ? 'Please enter an address'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Please enter a city' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _postalCodeController,
              decoration: const InputDecoration(
                labelText: 'Postal Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.markunread_mailbox),
              ),
              validator: (value) => value?.trim().isEmpty ?? true
                  ? 'Please enter postal code'
                  : null,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Set as Default Address'),
              subtitle: const Text(
                'Use this address as default for deliveries',
              ),
              value: _isDefault,
              onChanged: (value) => setState(() => _isDefault = value),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.addressId == null
                          ? 'Add Address'
                          : 'Update Address',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Notifications Settings Screen
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _orderUpdates = true;
  bool _promotions = false;
  bool _newsletter = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final data = doc.data() ?? {};

    if (mounted) {
      setState(() {
        _pushEnabled = data['notif_pushEnabled'] ?? true;
        _emailEnabled = data['notif_emailEnabled'] ?? true;
        _orderUpdates = data['notif_orderUpdates'] ?? true;
        _promotions = data['notif_promotions'] ?? false;
        _newsletter = data['notif_newsletter'] ?? false;
      });
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'notif_$key': value,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Manage how you receive notifications',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive push notifications on your device'),
            value: _pushEnabled,
            onChanged: (value) {
              setState(() => _pushEnabled = value);
              _updateSetting('pushEnabled', value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive notifications via email'),
            value: _emailEnabled,
            onChanged: (value) {
              setState(() => _emailEnabled = value);
              _updateSetting('emailEnabled', value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Order Updates'),
            subtitle: const Text('Get notified about your order status'),
            value: _orderUpdates,
            onChanged: (value) {
              setState(() => _orderUpdates = value);
              _updateSetting('orderUpdates', value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Promotions'),
            subtitle: const Text('Receive promotional offers'),
            value: _promotions,
            onChanged: (value) {
              setState(() => _promotions = value);
              _updateSetting('promotions', value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Newsletter'),
            subtitle: const Text('Receive our monthly newsletter'),
            value: _newsletter,
            onChanged: (value) {
              setState(() => _newsletter = value);
              _updateSetting('newsletter', value);
            },
          ),
        ],
      ),
    );
  }
}

// Chat Settings Screen
class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _chatEnabled = true;
  bool _soundEnabled = true;
  bool _readReceipts = true;
  String _status = 'Available';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final data = doc.data() ?? {};

    if (mounted) {
      setState(() {
        _chatEnabled = data['chat_enabled'] ?? true;
        _soundEnabled = data['chat_sound'] ?? true;
        _readReceipts = data['chat_readReceipts'] ?? true;
        _status = data['chat_status'] ?? 'Available';
      });
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'chat_$key': value,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Settings'),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Customize your chat preferences',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Chat'),
            subtitle: const Text('Allow others to message you'),
            value: _chatEnabled,
            onChanged: (value) {
              setState(() => _chatEnabled = value);
              _updateSetting('enabled', value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Sound Notifications'),
            subtitle: const Text('Play sound for new messages'),
            value: _soundEnabled,
            onChanged: (value) {
              setState(() => _soundEnabled = value);
              _updateSetting('sound', value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Read Receipts'),
            subtitle: const Text(
              'Let others know when you read their messages',
            ),
            value: _readReceipts,
            onChanged: (value) {
              setState(() => _readReceipts = value);
              _updateSetting('readReceipts', value);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Status'),
            subtitle: Text(_status),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Status'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('Available'),
                        onTap: () {
                          setState(() => _status = 'Available');
                          _updateSetting('status', 'Available');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        title: const Text('Busy'),
                        onTap: () {
                          setState(() => _status = 'Busy');
                          _updateSetting('status', 'Busy');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        title: const Text('Away'),
                        onTap: () {
                          setState(() => _status = 'Away');
                          _updateSetting('status', 'Away');
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Privacy & Security Screen
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Manage your privacy and security settings',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Profile Visibility'),
            subtitle: const Text('Who can see your profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Profile Visibility'),
                  content: const Text(
                    'Profile visibility settings allow you to control who can see your profile information.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.data_usage),
            title: const Text('Data & Privacy'),
            subtitle: const Text('Manage your data usage'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Data & Privacy'),
                  content: const Text(
                    'We respect your privacy. Your data is securely stored and only used to improve your experience.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Change Password Screen
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Error changing password';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (value) => value?.isEmpty ?? true
                  ? 'Please enter current password'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter new password';
                }
                if (value!.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please confirm password';
                }
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
}

// Profile Details Screen - Shows user profile information
class ProfileDetailsScreen extends StatelessWidget {
  final String fullName;
  final String email;
  final String phone;
  final String? profileImageUrl;

  const ProfileDetailsScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.phone,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      appBar: AppBar(
        title: const Text(
          'Profile Details',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Profile Image
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.pink[100],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: profileImageUrl != null && profileImageUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        ImageUrlHelper.encodeUrl(profileImageUrl!),
                        fit: BoxFit.cover,
                        cacheWidth: kIsWeb ? null : 400,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.pink[300],
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 3,
                              color: Colors.pink[300],
                            ),
                          );
                        },
                      ),
                    )
                  : Icon(Icons.person, size: 60, color: Colors.pink[300]),
            ),
            const SizedBox(height: 32),
            // Profile Information Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Name
                  _buildInfoRow(
                    icon: Icons.person_outline,
                    label: 'Name',
                    value: fullName,
                  ),
                  const Divider(height: 1, indent: 64),
                  // Email
                  _buildInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                  ),
                  const Divider(height: 1, indent: 64),
                  // Phone Number
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: phone.isNotEmpty ? phone : 'No phone number',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Edit Profile Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditUsernameScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.heading3(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that handles profile image loading with retry and URL refresh logic
class _ProfileImageWidget extends StatefulWidget {
  final String imageUrl;
  final String userId;
  final double width;
  final double height;

  const _ProfileImageWidget({
    required this.imageUrl,
    required this.userId,
    required this.width,
    required this.height,
  });

  @override
  State<_ProfileImageWidget> createState() => _ProfileImageWidgetState();
}

class _ProfileImageWidgetState extends State<_ProfileImageWidget> {
  String? _currentImageUrl;
  String? _cacheBustToken;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.imageUrl;
    _cacheBustToken = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void didUpdateWidget(_ProfileImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _currentImageUrl = widget.imageUrl;
        _cacheBustToken = DateTime.now().millisecondsSinceEpoch.toString();
        _retryCount = 0;
        _isRetrying = false;
      });
      debugPrint('🔄 Profile image URL updated: ${widget.imageUrl}');
    }
  }

  /// Regenerate download URL from Firebase Storage
  Future<String?> _regenerateDownloadUrl() async {
    try {
      // Get reference to the profile image
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${widget.userId}.jpg');

      // Get fresh download URL
      final newUrl = await storageRef.getDownloadURL();
      debugPrint('✅ Regenerated download URL for profile image');
      return newUrl;
    } catch (e) {
      debugPrint('❌ Failed to regenerate URL: $e');
      return null;
    }
  }

  /// Handle image load error with retry logic
  Future<void> _handleImageError(Object error) async {
    if (_retryCount >= _maxRetries || _isRetrying) {
      debugPrint('❌ Image load failed after $_retryCount retries: $error');
      return;
    }

    _isRetrying = true;
    _retryCount++;

    debugPrint('🔄 Retrying image load (attempt $_retryCount/$_maxRetries)...');

    // Wait a bit before retrying
    await Future.delayed(Duration(milliseconds: 500 * _retryCount));

    // Try to regenerate the URL
    final newUrl = await _regenerateDownloadUrl();

    if (mounted && newUrl != null && newUrl != _currentImageUrl) {
      setState(() {
        _currentImageUrl = newUrl;
      });

      // Update Firestore with new URL
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update({'profilePic': newUrl, 'profileImageUrl': newUrl});
      } catch (e) {
        debugPrint('⚠️ Failed to update Firestore with new URL: $e');
      }
    }

    _isRetrying = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: Icon(
          Icons.person,
          size: widget.width * 0.5,
          color: Colors.grey[400],
        ),
      );
    }

    // Add cache busting parameter to force reload when URL changes
    final imageUrlWithCacheBust = _currentImageUrl!.contains('?')
        ? '$_currentImageUrl&_t=$_cacheBustToken'
        : '$_currentImageUrl?_t=$_cacheBustToken';

    // Encode URL for safe web loading
    final safeImageUrl = Uri.encodeFull(imageUrlWithCacheBust);

    return Image.network(
      safeImageUrl,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      key: ValueKey(
        'profile_image_${_currentImageUrl}_${widget.userId}_$_cacheBustToken',
      ),
      // Only use cacheWidth/cacheHeight on mobile, not on web
      cacheWidth: kIsWeb ? null : (widget.width * 2).round().clamp(200, 800),
      cacheHeight: kIsWeb ? null : (widget.height * 2).round().clamp(200, 800),
      headers: kIsWeb ? null : {'Cache-Control': 'no-cache'},
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Handle error and retry
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleImageError(error);
        });

        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: widget.width * 0.5,
            color: Colors.grey[400],
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }
}
