import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../constants/app_colors.dart';
import '../pages/quotations_page.dart';

class RequestQuotationScreen extends StatefulWidget {
  const RequestQuotationScreen({super.key});

  @override
  State<RequestQuotationScreen> createState() => _RequestQuotationScreenState();
}

class _RequestQuotationScreenState extends State<RequestQuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedGlassType;
  String? _selectedAluminumType;
  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _isSubmitting = false;
  bool _isPickingImage = false;
  bool _isUploadingImage = false;
  double? _uploadProgress;
  bool _isMaterialBreakdownExpanded = false;

  final List<String> _glassTypes = [
    'Clear Glass',
    'Frosted Glass',
    'Tinted Glass',
    'Laminated Glass',
    'Tempered Glass',
  ];

  final List<String> _aluminumTypes = [
    'Silver Anodized',
    'Black Powder-Coated',
    'White Powder-Coated',
    'Bronze Finish',
  ];

  Map<String, dynamic>? _productData;

  /// Check if the product is a door (categoryGroup == "doors")
  bool get _isDoorProduct {
    if (_productData == null) return false;
    
    // Check multiple possible field names for category
    final categoryGroup = (_productData!['categoryGroup'] as String? ?? 
                          _productData!['category'] as String? ?? 
                          '').toLowerCase().trim();
    
    // Debug logging
    debugPrint('🔍 Product Data: ${_productData?.keys.toList()}');
    debugPrint('🔍 categoryGroup field: ${_productData?['categoryGroup']}');
    debugPrint('🔍 category field: ${_productData?['category']}');
    debugPrint('🔍 _isDoorProduct: ${categoryGroup == 'doors'}');
    
    return categoryGroup == 'doors';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        setState(() {
          _productData = Map<String, dynamic>.from(args);
          debugPrint('📦 Product data loaded: ${_productData?.keys.toList()}');
          debugPrint('📦 categoryGroup: ${_productData?['categoryGroup']}');
          debugPrint('📦 category: ${_productData?['category']}');
          debugPrint('📦 Is Door Product: $_isDoorProduct');
        });
      } else {
        debugPrint('⚠️ No product data passed to RequestQuotationScreen');
      }
    });
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return; // Prevent multiple simultaneous picks
    
    setState(() => _isPickingImage = true);
    
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) {
        setState(() => _isPickingImage = false);
        return;
      }

      // Pick image with timeout
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Image picker timed out. Please try again.');
        },
      );

      if (image != null) {
        // Read image bytes with timeout
        final bytes = await image.readAsBytes().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Failed to read image. Please try again.');
          },
        );
        
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _imageFileName = image.name;
            _isPickingImage = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image selected successfully'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _isPickingImage = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Upload image to Firebase Storage with progress tracking
  Future<String?> _uploadImage(Uint8List imageBytes, String fileName, String userId) async {
    if (_isUploadingImage) return null; // Prevent multiple simultaneous uploads
    
    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0.0;
    });

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('quotation_images')
          .child('${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Upload with timeout and progress tracking
      final uploadTask = storageRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() => _uploadProgress = progress);
        }
      });

      // Wait for upload to complete with timeout
      // UploadTask implements Future<TaskSnapshot>, so we can await it directly
      await (uploadTask as Future<TaskSnapshot>).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Image upload timed out. Please check your internet connection and try again.');
        },
      );

      // Get download URL with timeout
      final imageUrl = await storageRef.getDownloadURL().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Failed to get image URL. Please try again.');
        },
      );

      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadProgress = null;
        });
      }

      return imageUrl;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadProgress = null;
        });
        debugPrint('❌ Error uploading image: $e');
        rethrow; // Re-throw to be caught by caller
      }
      return null;
    }
  }

  String? _validateLength(String? value) {
    if (value == null || value.isEmpty) {
      return 'Length (Height) is required';
    }
    final length = double.tryParse(value);
    if (length == null) {
      return 'Please enter a valid number';
    }
    if (length < 48) {
      return 'Length (Height) must be at least 48 inches';
    }
    if (length <= 0) {
      return 'Length must be greater than 0';
    }
    return null;
  }

  String? _validateWidth(String? value) {
    if (value == null || value.isEmpty) {
      return 'Width is required';
    }
    final width = double.tryParse(value);
    if (width == null) {
      return 'Please enter a valid number';
    }
    if (width > 70) {
      return 'Width must not exceed 70 inches';
    }
    if (width <= 0) {
      return 'Width must be greater than 0';
    }
    return null;
  }

  String? _validateNotes(String? value) {
    // Notes are only required for windows, not doors
    if (_isDoorProduct) return null;
    if (value == null || value.trim().isEmpty) {
      return 'Additional notes are required';
    }
    return null;
  }

  String? _validateGlassType(String? value) {
    // Glass type is only required for windows, not doors
    if (_isDoorProduct) return null;
    if (value == null || value.isEmpty) {
      return 'Please select a glass type';
    }
    return null;
  }

  String? _validateAluminumType(String? value) {
    // Aluminum type is only required for windows, not doors
    if (_isDoorProduct) return null;
    if (value == null || value.isEmpty) {
      return 'Please select an aluminum frame type';
    }
    return null;
  }


  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to request a quotation'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;
      
      // Upload image if provided (only for windows, not doors)
      if (!_isDoorProduct && _imageBytes != null && _imageFileName != null) {
        try {
          imageUrl = await _uploadImage(_imageBytes!, _imageFileName!, user.uid);
          if (imageUrl == null) {
            throw Exception('Failed to upload image. Please try again.');
          }
          debugPrint('✅ Image uploaded successfully: $imageUrl');
        } catch (e) {
          debugPrint('❌ Image upload error: $e');
          // Ask user if they want to continue without image
          if (mounted) {
            final continueWithoutImage = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Image Upload Failed'),
                content: Text(
                  'Failed to upload image: ${e.toString()}\n\nWould you like to continue without the image?',
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
            
            if (continueWithoutImage != true) {
              setState(() => _isSubmitting = false);
              return; // User cancelled
            }
            // Continue without image
            imageUrl = null;
          }
        }
      }

      // Get customer info from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final customerName = userData['fullName'] ?? 
                          userData['name'] ?? 
                          user.displayName ?? 
                          user.email?.split('@')[0] ?? 
                          'Customer';
      final phoneNumber = (userData['phoneNumber'] ?? 
                          userData['phone'] ?? 
                          '').toString();
      final completeAddress = userData['completeAddress'] ?? 
                             userData['address'] ?? 
                             '';

      // Validate required fields based on product type
      if (!_isDoorProduct) {
        // For windows, validate glass and aluminum types
        if (_selectedGlassType == null || _selectedAluminumType == null) {
          throw Exception('Please select glass type and aluminum type');
        }
      }

      final length = double.tryParse(_lengthController.text.trim());
      final width = double.tryParse(_widthController.text.trim());
      final notes = _notesController.text.trim();

      // For doors, only length and width are required
      if (length == null || width == null) {
        throw Exception('Please fill in all required fields');
      }

      // For windows, notes are also required
      if (!_isDoorProduct && notes.isEmpty) {
        throw Exception('Please fill in all required fields');
      }

      // Build items array with material breakdown
      // Create only ONE item per quotation request
      final productId = _productData?['id']?.toString() ?? 
                       _productData?['productId']?.toString() ?? '';
      final productName = _productData?['name']?.toString() ?? 
                        (_isDoorProduct ? 'Custom Door' : 'Custom Window');
      
      // Single item with product information
      final singleItem = <String, dynamic>{
        'productId': productId,
        'productName': productName,
        'quantity': 1, // Default quantity is 1
        'length': length,
        'width': width,
        'price': 0, // Price will be set by admin/staff
      };
      
      // Add product-specific fields
      if (!_isDoorProduct && _selectedGlassType != null) {
        singleItem['glassType'] = _selectedGlassType;
      }
      if (!_isDoorProduct && _selectedAluminumType != null) {
        singleItem['aluminumType'] = _selectedAluminumType;
      }
      
      // Ensure items array contains exactly ONE item
      final List<Map<String, dynamic>> items = [singleItem];

      // Prepare quotation data
      final quotationData = <String, dynamic>{
        'customerId': user.uid,
        'customerName': customerName,
        'customerEmail': user.email ?? '',
        'phoneNumber': phoneNumber.toString().trim(),
        'completeAddress': completeAddress,
        'productId': _productData?['id']?.toString() ?? 
                     _productData?['productId']?.toString() ?? '',
        'productName': _productData?['name']?.toString() ?? 'Custom Product',
        'productImage': imageUrl ?? _productData?['img']?.toString() ?? '', // Use uploaded image if available
        'items': items, // Material breakdown array
        'length': length,
        'width': width,
        'notes': notes,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add product-specific fields
      if (_isDoorProduct) {
        quotationData['type'] = 'door-quotation';
      } else {
        quotationData.addAll({
          'glassType': _selectedGlassType!,
          'aluminumType': _selectedAluminumType!,
        });
      }

      // Save quotation to Firestore
      final quotationRef = await FirebaseFirestore.instance
          .collection('quotations')
          .add(quotationData);

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
          SnackBar(
            content: const Text('Quotation request submitted successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        // Redirect to My Quotations page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const QuotationsPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting quotation: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  TableRow _buildTableRow(String component, String description, String qty, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? AppColors.primary.withOpacity(0.1) : null,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            component,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: isHeader ? 14 : 13,
              color: isHeader ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            qty,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: isHeader ? 14 : 13,
              color: isHeader ? AppColors.primary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.dashboardBackground,
      appBar: AppBar(
        title: const Text('Request Quotation'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: keyboardHeight > 0 ? keyboardHeight + 16 : 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section - Different for Windows vs Doors
              if (_isDoorProduct) ...[
                // Simple header for doors
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Please input the exact Length and Width so we can compute your custom quotation.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                // Full header for windows
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.mainGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Quotation – Sliding Window',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please provide the following details to help us prepare an accurate quotation for your sliding window.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Product Info Card
              if (_productData != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_productData?['img'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _productData!['img'].toString(),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _productData?['name']?.toString() ?? 'Product',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _productData?['price']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (_productData != null) const SizedBox(height: 24),

              // Type of Glass - Only for windows
              if (!_isDoorProduct) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Type of Glass',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedGlassType,
                          decoration: const InputDecoration(
                            hintText: 'Choose your preferred glass type',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _glassTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          validator: _validateGlassType,
                          onChanged: (value) {
                            setState(() => _selectedGlassType = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Type of Aluminum Frame - Only for windows
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Aluminum Frame Finish',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedAluminumType,
                          decoration: const InputDecoration(
                            hintText: 'Select your aluminum frame type',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _aluminumTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          validator: _validateAluminumType,
                          onChanged: (value) {
                            setState(() => _selectedAluminumType = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Dimensions
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Dimensions (in inches)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Length (Height)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _lengthController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Minimum 48 inches',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: _validateLength,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Width',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _widthController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Maximum 70 inches',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: _validateWidth,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Upload an Image - Only for windows (optional)
              if (!_isDoorProduct) ...[
                Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Upload Reference Image',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload a photo of your existing window or door for a more accurate quote.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _isPickingImage || _isUploadingImage ? null : () async {
                          await _pickImage();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: _isPickingImage
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 12),
                                      Text('Selecting image...'),
                                    ],
                                  ),
                                )
                              : _isUploadingImage
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value: _uploadProgress,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _uploadProgress != null
                                                ? 'Uploading: ${(_uploadProgress! * 100).toStringAsFixed(0)}%'
                                                : 'Uploading image...',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _imageBytes != null
                                      ? Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.memory(
                                                _imageBytes!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _imageBytes = null;
                                                    _imageFileName = null;
                                                    _uploadProgress = null;
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate_outlined,
                                              size: 48,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Tap to upload image',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Gallery or Camera',
                                              style: TextStyle(
                                                color: AppColors.textHint,
                                                fontSize: 12,
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
              const SizedBox(height: 20),
              ],

              // Material Breakdown - Different for windows and doors
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  title: Text(
                    _isDoorProduct
                        ? 'Material Breakdown for Door'
                        : 'Material Breakdown for Sliding Window',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  leading: Icon(
                    Icons.inventory_2,
                    color: AppColors.primary,
                  ),
                  initiallyExpanded: _isMaterialBreakdownExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isMaterialBreakdownExpanded = expanded;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(3),
                          2: FlexColumnWidth(1),
                        },
                        children: _isDoorProduct
                            ? [
                                // Door Material Breakdown
                                _buildTableRow('Component', 'Description', 'Qty', isHeader: true),
                                _buildTableRow('Door Slab', 'Aluminum / Wood / Steel', '1 pc'),
                                _buildTableRow('Door Frame', 'Aluminum or steel frame', '1 set'),
                                _buildTableRow('Hinges', 'Door hinges', '2–3 pcs'),
                                _buildTableRow('Lockset / Door Knob', 'Locking mechanism', '1 set'),
                                _buildTableRow('Screws & Bolts', 'Installation hardware', 'As needed'),
                                _buildTableRow('Rubber Seal', 'Weatherproofing seal', 'As needed'),
                                _buildTableRow('Threshold', 'Door threshold (if needed)', '1 pc'),
                              ]
                            : [
                                // Window Material Breakdown
                                _buildTableRow('Component', 'Description', 'Qty', isHeader: true),
                                _buildTableRow('Top Rail', 'Aluminum top frame rail', '1 pc'),
                                _buildTableRow('Bottom Rail', 'Aluminum bottom track', '1 pc'),
                                _buildTableRow('Side Frames', 'Vertical aluminum frame', '2 pcs'),
                                _buildTableRow('Glass Panel', _selectedGlassType ?? 'Selected glass type', '1–2'),
                                _buildTableRow('Rollers', 'Sliding rollers', '2–4'),
                                _buildTableRow('Handle & Lock Set', 'Locking/handle', '1 set'),
                                _buildTableRow('Rubber Seal', 'Insulation', 'As needed'),
                              ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Additional Notes - For both windows and doors (optional)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Additional Notes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: _isDoorProduct
                              ? 'Enter any additional details or custom requests (e.g., door style, color preference, installation site).'
                              : 'Enter any additional details or custom requests (e.g., handle type, color preference, installation site).',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: _validateNotes,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button - For both doors and windows
              SizedBox(
                height: 50,
                child: Container(
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
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
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
                            'Submit Quotation Request',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Instructions - Only for doors
              if (_isDoorProduct) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Once all fields are complete, click "Request Quotation" to submit your details. Our team will review your request and get back to you with a custom quote.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

