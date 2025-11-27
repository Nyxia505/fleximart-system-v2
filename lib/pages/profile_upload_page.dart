import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Profile Upload Page
/// 
/// A dedicated page for uploading profile images and editing profile information
class ProfileUploadPage extends StatefulWidget {
  const ProfileUploadPage({super.key});

  @override
  State<ProfileUploadPage> createState() => _ProfileUploadPageState();
}

class _ProfileUploadPageState extends State<ProfileUploadPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String? _profileImageUrl;
  bool _loading = false;
  bool _uploadingImage = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Load current profile data from Firestore
  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _nameController.text = data['fullName'] as String? ?? user.displayName ?? '';
        _phoneController.text = data['phone'] as String? ?? '';
        _emailController.text = data['email'] as String? ?? user.email ?? '';
        _profileImageUrl = data['profileImageUrl'] as String?;
      } else {
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Pick and upload profile image
  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to upload profile image'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show dialog to choose image source
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
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
              title: Text(
                'Gallery',
                style: AppTextStyles.bodyLarge(),
              ),
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
              title: Text(
                'Camera',
                style: AppTextStyles.bodyLarge(),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _uploadingImage = true);

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

      // Delete old image if exists (optional - Firebase will overwrite)
      try {
        await storageRef.delete().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Timeout is OK, file might not exist
            debugPrint('⚠️ Timeout deleting old image (this is OK if file doesn\'t exist)');
          },
        );
      } catch (e) {
        // Ignore if file doesn't exist - this is normal for first upload
        debugPrint('ℹ️ Old image not found (this is OK): $e');
      }

      // Upload new image
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

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileImageUrl': downloadUrl});

      // Update local state
      if (mounted) {
        setState(() {
          _profileImageUrl = downloadUrl;
          _uploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated successfully!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Print detailed error for debugging
      debugPrint('❌ Profile Image Upload Error:');
      debugPrint('   Error: $e');
      debugPrint('   StackTrace: $stackTrace');
      
      if (mounted) {
        setState(() => _uploadingImage = false);

        String errorMessage = 'Error uploading image';
        String detailedError = e.toString();
        
        if (detailedError.contains('permission') || 
            detailedError.contains('403') ||
            detailedError.contains('unauthorized') ||
            detailedError.contains('Permission denied')) {
          errorMessage =
              'Permission denied. Please check Firebase Storage rules are deployed.';
        } else if (detailedError.contains('network') ||
            detailedError.contains('timeout') ||
            detailedError.contains('SocketException')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (detailedError.contains('storage/object-not-found')) {
          errorMessage = 'File not found. This is normal for first upload.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }

        // Show error dialog with more details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Upload Failed',
                  style: AppTextStyles.heading3(color: AppColors.error),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage,
                  style: AppTextStyles.bodyLarge(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Details:',
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    detailedError,
                    style: AppTextStyles.caption(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '💡 Tips:',
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Make sure Firebase Storage rules are deployed\n'
                  '• Check your internet connection\n'
                  '• Try again in a few moments',
                  style: AppTextStyles.caption(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(); // Retry
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Save profile information
  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save profile'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth display name
      await user.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

        // Navigate back after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context, true); // Return true to indicate success
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: AppTextStyles.heading3(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading && _profileImageUrl == null
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Profile Image Section
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _uploadingImage
                                ? Container(
                                    color: AppColors.background,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : _profileImageUrl != null &&
                                        _profileImageUrl!.isNotEmpty
                                    ? Image.network(
                                        _profileImageUrl!,
                                        width: 140,
                                        height: 140,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: AppColors.background,
                                            child: const Icon(
                                              Icons.person,
                                              size: 60,
                                              color: AppColors.textSecondary,
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            color: AppColors.background,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                        loadingProgress.expectedTotalBytes!
                                                    : null,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.primary.withOpacity(0.7),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                      ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _uploadingImage ? null : _pickAndUploadImage,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _uploadingImage
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Center(
                    child: Text(
                      'Tap camera icon to change photo',
                      style: AppTextStyles.caption(
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Name Field
                  Text(
                    'Full Name',
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textPrimary,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: AppTextStyles.bodyLarge(),
                    decoration: InputDecoration(
                      hintText: 'Enter your full name',
                      hintStyle: AppTextStyles.bodyMedium(
                        color: AppColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Phone Field
                  Text(
                    'Phone Number',
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textPrimary,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: AppTextStyles.bodyLarge(),
                    decoration: InputDecoration(
                      hintText: 'Enter your phone number',
                      hintStyle: AppTextStyles.bodyMedium(
                        color: AppColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: AppColors.primary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Email Field (read-only)
                  Text(
                    'Email Address',
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textPrimary,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    enabled: false,
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textSecondary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Email address',
                      hintStyle: AppTextStyles.bodyMedium(
                        color: AppColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Save Button
                  ElevatedButton(
                    onPressed: _loading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
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
                        : Text(
                            'Save Profile',
                            style: AppTextStyles.buttonLarge(
                              color: Colors.white,
                            ),
                          ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

