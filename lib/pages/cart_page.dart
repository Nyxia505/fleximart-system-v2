import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../dialogs/delivery_address_dialog.dart';
import '../utils/price_formatter.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedItems = {};
  final CartService _cartService = CartService();
  final OrderService _orderService = OrderService();
  bool _isProcessingCheckout = false;

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  void _selectAll(List<String> allItemIds) {
    setState(() {
      if (_selectedItems.length == allItemIds.length) {
        _selectedItems.clear();
      } else {
        _selectedItems.addAll(allItemIds);
      }
    });
  }

  Future<void> _processCheckout(List<QueryDocumentSnapshot> cartItems) async {
    if (_selectedItems.isEmpty || _isProcessingCheckout) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to checkout'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isProcessingCheckout = true);

    try {
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final customerName = userData['name'] ?? 
                          userData['fullName'] ?? 
                          user.displayName ?? 
                          user.email ?? 'Customer';

      // Show delivery address form
      final deliveryAddress = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const DeliveryAddressDialog(),
      );

      if (deliveryAddress == null) {
        setState(() => _isProcessingCheckout = false);
        return; // User cancelled
      }

      // Filter selected items
      final selectedCartItems = cartItems
          .where((doc) => _selectedItems.contains(doc.id))
          .toList();

      // Create orders for each selected item
      int successCount = 0;
      for (var cartItemDoc in selectedCartItems) {
        try {
          final cartItemData = cartItemDoc.data() as Map<String, dynamic>;
          final productId = cartItemData['productId'] as String? ?? '';
          final productName = cartItemData['productName'] as String? ?? 'Product';
          final productImage = cartItemData['productImage'] as String?;
          final price = (cartItemData['price'] as num?)?.toDouble() ?? 0.0;
          final quantity = (cartItemData['quantity'] as int?) ?? 1;
          final totalPrice = price * quantity;
          
          // Get size data if available
          final sizeData = cartItemData['sizeData'] as Map<String, dynamic>?;
          final length = cartItemData['length'] as double?;
          final width = cartItemData['width'] as double?;
          final selectedWidth = sizeData?['width'] as double? ?? width;
          final selectedHeight = sizeData?['height'] as double? ?? length;

          await _orderService.createOrder(
            customerId: user.uid,
            customerName: customerName,
            customerEmail: user.email ?? '',
            productId: productId,
            productName: productName,
            productImage: productImage,
            quantity: quantity,
            price: price,
            totalPrice: totalPrice,
            paymentMethod: 'cash_on_delivery',
            installationRequired: true,
            fullName: deliveryAddress['fullName'] as String,
            phoneNumber: (deliveryAddress['phoneNumber'] ?? '').toString(),
            completeAddress: deliveryAddress['completeAddress'] as String,
            landmark: deliveryAddress['landmark'] as String?,
            mapLink: deliveryAddress['mapLink'] as String?,
            latitude: deliveryAddress['latitude'] as double?,
            longitude: deliveryAddress['longitude'] as double?,
            selectedWidth: selectedWidth,
            selectedHeight: selectedHeight,
            productLength: length,
            productWidth: width,
          );

          // Remove item from cart after successful order creation
          await _cartService.removeFromCart(cartItemDoc.id);
          successCount++;
        } catch (e) {
          debugPrint('Error creating order for item ${cartItemDoc.id}: $e');
          // Continue with other items even if one fails
        }
      }

      if (mounted) {
        // Clear selected items
        setState(() {
          _selectedItems.clear();
          _isProcessingCheckout = false;
        });

        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount order(s) placed successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          // Navigate back or refresh
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to place orders. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingCheckout = false);
        String errorMessage = 'Error processing checkout: ${e.toString()}';
        
        // Handle phone verification error specifically
        if (e.toString().contains('PHONE_NOT_VERIFIED')) {
          errorMessage = 'Please verify your phone number before placing an order.';
        }
        
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
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cart'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.mainGradient),
          ),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please log in to view your cart'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cart'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _cartService.getCartItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading cart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add products to your cart to see them here',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final cartItems = snapshot.data!.docs;
          final allItemIds = cartItems.map((doc) => doc.id).toList();
          double totalPrice = 0.0;

          // Calculate total for selected items only
          for (var doc in cartItems) {
            if (_selectedItems.contains(doc.id)) {
              final data = doc.data() as Map<String, dynamic>;
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
              totalPrice += price * quantity;
            }
          }

          return Column(
            children: [
              // Select All Header
              if (cartItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedItems.length == cartItems.length && cartItems.isNotEmpty,
                        onChanged: (value) => _selectAll(allItemIds),
                        activeColor: AppColors.primary,
                        splashRadius: 0,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedItems.length == cartItems.length && cartItems.isNotEmpty
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedItems.length} selected',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  key: const PageStorageKey('cart_list'),
                  itemBuilder: (context, index) {
                    final doc = cartItems[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final productName = data['productName'] as String? ?? 'Product';
                    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
                    final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
                    final productImage = data['productImage'] as String?;
                    final length = (data['length'] as num?)?.toDouble();
                    final width = (data['width'] as num?)?.toDouble();
                    final isSelected = _selectedItems.contains(doc.id);

                    return RepaintBoundary(
                      child: Card(
                        key: ValueKey('cart_item_${doc.id}'),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Checkbox
                              RepaintBoundary(
                                child: Checkbox(
                                  key: ValueKey('checkbox_${doc.id}'),
                                  value: isSelected,
                                  onChanged: (value) => _toggleItemSelection(doc.id),
                                  activeColor: AppColors.primary,
                                  splashRadius: 0,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            const SizedBox(width: 8),
                            // Product Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: productImage != null && productImage.isNotEmpty
                                  ? Image.network(
                                      productImage,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.image),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Product Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (length != null && width != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${length.toStringAsFixed(0)}" × ${width.toStringAsFixed(0)}"',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    PriceFormatter.formatPrice(price * quantity),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity Controls
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    if (quantity > 1) {
                                      _cartService.updateQuantity(doc.id, quantity - 1);
                                    } else {
                                      _cartService.removeFromCart(doc.id);
                                    }
                                  },
                                  color: AppColors.primary,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    _cartService.updateQuantity(doc.id, quantity + 1);
                                  },
                                  color: AppColors.primary,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            // Remove Button
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                _cartService.removeFromCart(doc.id);
                              },
                              color: AppColors.error,
                            ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Total and Checkout Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: AppTextStyles.heading3(),
                        ),
                        Text(
                          PriceFormatter.formatPrice(totalPrice),
                          style: AppTextStyles.heading2(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_selectedItems.isEmpty || _isProcessingCheckout)
                            ? null
                            : () => _processCheckout(cartItems),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isProcessingCheckout
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _selectedItems.isEmpty
                                    ? 'Select items to checkout'
                                    : 'Checkout (${_selectedItems.length} item${_selectedItems.length > 1 ? 's' : ''})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

