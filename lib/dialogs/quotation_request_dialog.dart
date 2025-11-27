import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../constants/app_colors.dart';

class QuotationRequestDialog extends StatefulWidget {
  final Map<String, String> product;
  const QuotationRequestDialog({super.key, required this.product});

  @override
  State<QuotationRequestDialog> createState() => _QuotationRequestDialogState();
}

class _QuotationRequestDialogState extends State<QuotationRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedGlassType = 'Tempered Glass';
  bool _isSubmitting = false;
  
  // Image picker and upload
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  String? _uploadedImageUrl;
  double _uploadProgress = 0.0;

  final List<String> _glassTypes = [
    'Tempered Glass',
    'Clear Glass',
    'Frosted Glass',
    'Tinted Glass',
    'Mirror Glass',
    'Laminated Glass',
    'Double Pane Glass',
  ];

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = image;
        _uploadedImageUrl = null;
        _uploadProgress = 0.0;
      });

      await uploadImageToFirebase(image);
    }
  }

  Future<String?> uploadImageToFirebase(XFile image) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child("quotation_images/${DateTime.now().millisecondsSinceEpoch}.jpg");

    final uploadTask = storageRef.putFile(File(image.path));

    uploadTask.snapshotEvents.listen((event) {
      if (mounted) {
        setState(() {
          _uploadProgress = (event.bytesTransferred / event.totalBytes) * 100;
        });
      }
    });

    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    if (mounted) {
      setState(() {
        _uploadedImageUrl = downloadUrl;
        _uploadProgress = 100.0;
      });
    }

    return downloadUrl;
  }

  Future<void> _submitQuotation() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to request a quotation')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get customer info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final customerName = userData['fullName'] ?? user.email ?? 'Customer';

      // Upload image if selected
      String? imageUrl = _uploadedImageUrl;
      if (_selectedImage != null && imageUrl == null) {
        try {
          imageUrl = await uploadImageToFirebase(_selectedImage!);
        } catch (e) {
          debugPrint('Image upload error: $e');
          // Show error dialog but allow continuing without image
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Image Upload Failed'),
              content: Text(
                'Failed to upload image: $e\n\nWould you like to continue without the image?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue Without Image'),
                ),
              ],
            ),
          );
          if (shouldContinue != true) {
            setState(() => _isSubmitting = false);
            return;
          }
        }
      }

      // Save quotation to Firestore
      final quotationRef = await FirebaseFirestore.instance.collection('quotations').add({
        'customerId': user.uid,
        'customerName': customerName,
        'customerEmail': user.email ?? '',
        'productName': widget.product['name'] ?? '',
        'productImage': widget.product['img'] ?? '',
        'imageUrl': imageUrl ?? '', // Add uploaded image URL
        'glassType': _selectedGlassType,
        'length': double.tryParse(_lengthController.text) ?? 0.0,
        'width': double.tryParse(_widthController.text) ?? 0.0,
        'notes': _notesController.text.trim(),
        'status': 'Pending',
        'estimatedPrice': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify staff and admin about new quotation request
      try {
        debugPrint('📢 Starting notification process for quotation: ${quotationRef.id}');
        final batch = FirebaseFirestore.instance.batch();
        
        // Notify all admins
        final adminsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        
        debugPrint('👑 Found ${adminsSnapshot.docs.length} admin(s) to notify');
        
        for (var adminDoc in adminsSnapshot.docs) {
          final notificationRef = FirebaseFirestore.instance
              .collection('notifications')
              .doc();
          batch.set(notificationRef, {
            'userId': adminDoc.id,
            'type': 'new_quotation',
            'title': 'New Quotation Request',
            'message': 'New Quotation Request from $customerName',
            'quotationId': quotationRef.id,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ Added notification for admin: ${adminDoc.id}');
        }
        
        // Notify all staff
        final staffSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'staff')
            .get();
        
        debugPrint('👥 Found ${staffSnapshot.docs.length} staff member(s) to notify');
        
        for (var staffDoc in staffSnapshot.docs) {
          final notificationRef = FirebaseFirestore.instance
              .collection('notifications')
              .doc();
          batch.set(notificationRef, {
            'userId': staffDoc.id,
            'type': 'new_quotation',
            'title': 'New Quotation Request',
            'message': 'New Quotation Request from $customerName',
            'quotationId': quotationRef.id,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ Added notification for staff: ${staffDoc.id}');
        }
        
        await batch.commit();
        debugPrint('✅ Successfully committed ${adminsSnapshot.docs.length + staffSnapshot.docs.length} notifications');
      } catch (e, stackTrace) {
        debugPrint('❌ Error notifying staff/admin: $e');
        debugPrint('Stack trace: $stackTrace');
        // Don't fail the quotation submission if notification fails
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation request submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting quotation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Request Quotation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.product['name'] ?? 'Product',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedGlassType,
                          decoration: const InputDecoration(
                            labelText: 'Glass Type',
                            border: OutlineInputBorder(),
                          ),
                          items: _glassTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedGlassType = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Image Upload Section
                        const Text(
                          'Upload Reference Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload a photo of your existing window or door for a more accurate quote.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: pickImage,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: _selectedImage == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                                      SizedBox(height: 10),
                                      Text("Tap to upload image"),
                                      SizedBox(height: 5),
                                      Text("Gallery or Camera", style: TextStyle(fontSize: 12)),
                                    ],
                                  )
                                : Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          File(_selectedImage!.path),
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (_uploadProgress < 100)
                                        Container(
                                          color: Colors.black.withOpacity(0.5),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const CircularProgressIndicator(
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  "Uploading: ${_uploadProgress.toStringAsFixed(0)}%",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _lengthController,
                                decoration: const InputDecoration(
                                  labelText: 'Length (cm)',
                                  border: OutlineInputBorder(),
                                  hintText: 'e.g., 100',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter length';
                                  }
                                  if (double.tryParse(value) == null ||
                                      double.parse(value) <= 0) {
                                    return 'Please enter a valid length';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _widthController,
                                decoration: const InputDecoration(
                                  labelText: 'Width (cm)',
                                  border: OutlineInputBorder(),
                                  hintText: 'e.g., 100',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter width';
                                  }
                                  if (double.tryParse(value) == null ||
                                      double.parse(value) <= 0) {
                                    return 'Please enter a valid width';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Additional Notes (Optional)',
                            border: OutlineInputBorder(),
                            hintText: 'Any special requirements or details...',
                          ),
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitQuotation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

