import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/order_service.dart';
import '../services/phone_verification_service.dart';
import '../utils/price_formatter.dart';
import '../dialogs/delivery_address_dialog.dart';
import 'phone_verification_input_page.dart';

/// Proceed to Buy Page
///
/// Creates a direct order with product price and optional size selection.
/// Supports custom dimensions (length and width in cm).
/// Includes size selection from Firestore subcollection if available.
class ProceedToBuyPage extends StatefulWidget {
  const ProceedToBuyPage({super.key});

  @override
  State<ProceedToBuyPage> createState() => _ProceedToBuyPageState();
}

class _ProceedToBuyPageState extends State<ProceedToBuyPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');

  bool _isSubmitting = false;
  Map<String, dynamic>? _productData;

  // Size selection state
  List<Map<String, dynamic>> _sizes = [];
  Map<String, dynamic>? _selectedSize;
  bool _isLoadingSizes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        setState(() {
          _productData = Map<String, dynamic>.from(args);
        });
        // Only load sizes if product is customizable
        final isCustomizable =
            _productData?['isCustomizable'] as bool? ?? false;
        if (isCustomizable) {
          _loadSizes();
        }
      }
    });
  }

  /// Load sizes from Firestore subcollection
  Future<void> _loadSizes() async {
    if (_productData == null) return;

    final productId =
        _productData!['id']?.toString() ??
        _productData!['productId']?.toString() ??
        '';

    if (productId.isEmpty) return;

    setState(() => _isLoadingSizes = true);

    try {
      final sizesSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('sizes')
          .get();

      final sizes = sizesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'width': (data['width'] as num?)?.toDouble() ?? 0.0,
          'height': (data['height'] as num?)?.toDouble() ?? 0.0,
          'addedPrice': (data['addedPrice'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();

      setState(() {
        _sizes = sizes;
        _isLoadingSizes = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSizes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sizes: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  double _parsePrice(String? priceString) {
    if (priceString == null || priceString.isEmpty) return 0.0;
    return double.tryParse(
          priceString.replaceAll('₱', '').replaceAll(',', '').trim(),
        ) ??
        0.0;
  }

  /// Format price with commas and two decimal places
  String _formatPrice(double price) {
    return PriceFormatter.formatPrice(price);
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate size selection (only if product is customizable and sizes are available)
    final isCustomizable = _productData?['isCustomizable'] as bool? ?? false;
    if (isCustomizable && _sizes.isNotEmpty && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a size'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to place an order'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_productData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product information is missing'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check phone verification before proceeding
    final isPhoneVerified = await PhoneVerificationService.isPhoneVerified(user.uid);
    if (!isPhoneVerified) {
      if (!mounted) return;
      final shouldVerify = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone Verification Required'),
          content: const Text(
            'You must verify your phone number before placing an order. '
            'This helps us contact you regarding your order.',
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
              child: const Text('Verify Now'),
            ),
          ],
        ),
      );

      if (shouldVerify == true && mounted) {
        // Navigate to phone verification and wait for result
        final verificationResult = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const PhoneVerificationInputPage(),
          ),
        );
        
        // If verification was successful, retry the order placement
        if (verificationResult == true && mounted) {
          // Re-check verification status
          final isNowVerified = await PhoneVerificationService.isPhoneVerified(user.uid);
          if (isNowVerified) {
            // Verification successful, proceed with order
            // Call the order placement method again
            _placeOrder();
            return;
          } else {
            // Still not verified, show error
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Phone verification incomplete. Please try again.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        }
      }
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

      // Parse product data
      final productId =
          _productData!['id']?.toString() ??
          _productData!['productId']?.toString() ??
          '';
      final productName = _productData!['name']?.toString() ?? 'Product';
      final productImage = _productData!['img']?.toString();
      final priceString = _productData!['price']?.toString() ?? '0';
      final basePrice = _parsePrice(priceString);
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

      // Calculate price with size added price
      final addedPrice = _selectedSize?['addedPrice'] as double? ?? 0.0;
      final unitPrice = basePrice + addedPrice;
      final totalPrice = unitPrice * quantity;

      // Get size dimensions
      final selectedWidth = _selectedSize?['width'] as double?;
      final selectedHeight = _selectedSize?['height'] as double?;

      // Get product dimensions from product document (for non-customizable products)
      final productLength = (_productData!['length'] as num?)?.toDouble();
      final productWidth = (_productData!['width'] as num?)?.toDouble();

      if (unitPrice <= 0) {
        throw Exception('Invalid product price');
      }

      // Show delivery address form
      final deliveryAddress = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const DeliveryAddressDialog(),
      );

      if (deliveryAddress == null) {
        setState(() => _isSubmitting = false);
        return; // User cancelled
      }

      // Create order using OrderService
      final orderService = OrderService();
      await orderService.createOrder(
        customerId: user.uid,
        customerName: customerName,
        customerEmail: user.email ?? '',
        productId: productId,
        productName: productName,
        productImage: productImage,
        quantity: quantity,
        price: unitPrice,
        totalPrice: totalPrice,
        paymentMethod: 'cash_on_delivery', // Default payment method
        installationRequired: true, // Default for window/door products
        // Delivery address fields
        fullName: deliveryAddress['fullName'] as String,
        phoneNumber: (deliveryAddress['phoneNumber'] ?? '').toString(),
        completeAddress: deliveryAddress['completeAddress'] as String,
        landmark: deliveryAddress['landmark'] as String?,
        mapLink: deliveryAddress['mapLink'] as String?,
        selectedWidth: selectedWidth,
        selectedHeight: selectedHeight,
        addedPrice: addedPrice > 0 ? addedPrice : null,
        productLength: productLength,
        productWidth: productWidth,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order placed successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error placing order: ${e.toString()}';
        
        // Handle phone verification error specifically
        if (e.toString().contains('PHONE_NOT_VERIFIED')) {
          errorMessage = 'Please verify your phone number before placing an order.';
          final shouldVerify = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Phone Verification Required'),
              content: const Text(
                'You must verify your phone number before placing an order. '
                'This helps us contact you regarding your order.',
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
                  child: const Text('Verify Now'),
                ),
              ],
            ),
          );

          if (shouldVerify == true && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PhoneVerificationInputPage(),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_productData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Proceed to Buy'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.mainGradient),
          ),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Product information not found')),
      );
    }

    final productName = _productData!['name']?.toString() ?? 'Product';
    final productImage = _productData!['img']?.toString();
    final priceString = _productData!['price']?.toString() ?? '₱0';
    final basePrice = _parsePrice(priceString);
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

    // Calculate price with size added price
    final addedPrice = _selectedSize?['addedPrice'] as double? ?? 0.0;
    final unitPrice = basePrice + addedPrice;
    final totalPrice = unitPrice * quantity;

    // Get product dimensions (fixed from product data)
    final productLength = (_productData!['length'] as num?)?.toDouble();
    final productWidth = (_productData!['width'] as num?)?.toDouble();
    // Check if product is customizable - default to false if not specified
    // Also check if sizes collection exists - if no sizes and has length/width, treat as fixed-size
    final isCustomizable = _productData!['isCustomizable'] as bool? ?? false;
    final hasFixedSize = !isCustomizable && productLength != null && productWidth != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Proceed to Buy'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Info Card
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
                          if (productImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                productImage,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(productName, style: AppTextStyles.heading3()),
                                const SizedBox(height: 8),
                                Text(
                                  _formatPrice(basePrice),
                                  style: AppTextStyles.heading2(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Show fixed size under product image
                      if (hasFixedSize) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.straighten,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Size: ${productLength.toInt()} cm × ${productWidth.toInt()} cm',
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.primary,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
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
              const SizedBox(height: 24),

              // Size Selection Section (only when isCustomizable is true)
              if (isCustomizable) ...[
                Text('Select Size', style: AppTextStyles.heading3()),
                const SizedBox(height: 8),
                if (_isLoadingSizes)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_sizes.isEmpty)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No sizes available for this product',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildSizeSelectionList(),
                if (_selectedSize != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Selected: ${_selectedSize!['width']} x ${_selectedSize!['height']} inches',
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],

              // Quantity Input
              Text('Quantity', style: AppTextStyles.heading3()),
              const SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter quantity',
                  prefixIcon: const Icon(Icons.shopping_cart),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  final qty = int.tryParse(value.trim());
                  if (qty == null || qty <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Order Summary
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
                      Text('Order Summary', style: AppTextStyles.heading2()),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Base Price',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _formatPrice(basePrice),
                            style: AppTextStyles.bodyMedium(),
                          ),
                        ],
                      ),
                      if (_selectedSize != null && addedPrice > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Size Additional',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '+${_formatPrice(addedPrice)}',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Unit Price',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _formatPrice(unitPrice),
                            style: AppTextStyles.bodyMedium().copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quantity',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            quantity.toString(),
                            style: AppTextStyles.bodyMedium(),
                          ),
                        ],
                      ),
                      if (hasFixedSize) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Size',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${productLength.toInt()} cm × ${productWidth.toInt()} cm',
                              style: AppTextStyles.bodyMedium(),
                            ),
                          ],
                        ),
                      ],
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Price', style: AppTextStyles.heading3()),
                          Text(
                            _formatPrice(totalPrice),
                            style: AppTextStyles.heading2(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
                        'This is a fixed-price order. The product will be delivered at the standard price shown above.',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Place Order Button
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
                    onPressed: _isSubmitting ? null : _placeOrder,
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Proceed to Buy',
                            style: AppTextStyles.buttonLarge(),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build scrollable size selection list
  Widget _buildSizeSelectionList() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _sizes.length,
        itemBuilder: (context, index) {
          final size = _sizes[index];
          final isSelected = _selectedSize?['id'] == size['id'];
          final width = size['width'] as double;
          final height = size['height'] as double;
          final addedPrice = size['addedPrice'] as double;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSize = size;
              });
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${width.toInt()} x ${height.toInt()}',
                      style: AppTextStyles.bodyMedium(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'inches',
                      style: AppTextStyles.caption(
                        color: isSelected
                            ? Colors.white.withOpacity(0.9)
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (addedPrice > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+${_formatPrice(addedPrice)}',
                        style: AppTextStyles.caption(
                          color: isSelected
                              ? Colors.white.withOpacity(0.9)
                              : AppColors.primary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
