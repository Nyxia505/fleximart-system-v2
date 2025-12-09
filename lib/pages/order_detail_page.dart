import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../utils/price_formatter.dart';
import '../dialogs/delivery_schedule_dialog.dart';
import '../utils/role_helper.dart';
import '../services/order_service.dart';
import '../widgets/map_coming_soon_placeholder.dart';
import '../utils/image_url_helper.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  final DocumentReference orderRef;
  const OrderDetailPage({
    super.key,
    required this.orderId,
    required this.orderRef,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  String? _userRole;
  bool _isCheckingRole = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final role = await RoleHelper.getUserRole();
    setState(() {
      _userRole = role;
      _isCheckingRole = false;
    });
  }

  bool get _isAdminOrStaff => _userRole == 'admin' || _userRole == 'staff';

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }

  Future<void> _markAsDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Delivered'),
        content: const Text('Are you sure you want to mark this order as delivered?'),
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.orderRef.update({
        'scheduleStatus': 'completed',
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as delivered'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRole) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Order #${widget.orderId.substring(0, 8).toUpperCase()}'),
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8).toUpperCase()}'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: widget.orderRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];
          final statusRaw = (data['status'] as String? ?? 'pending').toString();
          // Normalize status to lowercase
          final status = statusRaw.toLowerCase();
          // Get totalPrice from Firestore, or compute from items if missing
          final totalPriceValue = data['totalPrice'];
          double? totalPrice;
          if (totalPriceValue is num) {
            totalPrice = totalPriceValue.toDouble();
          } else if (totalPriceValue is String) {
            totalPrice = double.tryParse(totalPriceValue);
          }

          // Compute from items if totalPrice doesn't exist
          double computedTotal = 0.0;
          if (items.isNotEmpty) {
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final priceValue = item['price'];
                double price = 0.0;
                if (priceValue is num) {
                  price = priceValue.toDouble();
                } else if (priceValue is String) {
                  price = double.tryParse(priceValue) ?? 0.0;
                }

                final quantityValue = item['quantity'];
                int quantity = 1;
                if (quantityValue is num) {
                  quantity = quantityValue.toInt();
                } else if (quantityValue is String) {
                  quantity = int.tryParse(quantityValue) ?? 1;
                }

                computedTotal += price * quantity;
              }
            }
          }

          final totalAmount = (totalPrice ?? computedTotal) as num;

          // Ensure status is in the valid list
          final validStatuses = const [
            'pending',
            'quoted',
            'processing',
            'completed',
            'delivered',
          ];
          final currentStatus = validStatuses.contains(status)
              ? status
              : 'pending';

          // Address fields
          final fullName = data['fullName'] as String? ?? '';
          final phoneNumber = (data['phoneNumber'] ?? '').toString();
          final completeAddress = data['completeAddress'] as String? ?? '';
          final landmark = data['landmark'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Address Card (at the top)
                if (fullName.isNotEmpty || completeAddress.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Delivery Address',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (fullName.isNotEmpty)
                            _buildInfoRow('Name', fullName),
                          if (phoneNumber.isNotEmpty)
                            _buildInfoRow('Phone', phoneNumber),
                          if (completeAddress.isNotEmpty)
                            _buildInfoRow('Address', completeAddress),
                          if (landmark != null && landmark.isNotEmpty)
                            _buildInfoRow('Landmark', landmark),
                          // View Map button (if coordinates exist)
                          if (data['latitude'] != null && data['longitude'] != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const MapComingSoonPlaceholder(
                                        title: 'Order Location',
                                        message: 'Map view for order delivery location is coming soon!',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.map),
                                label: const Text('View on Map'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (fullName.isNotEmpty || completeAddress.isNotEmpty)
                  const SizedBox(height: 16),

                // Order Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Customer Name',
                          data['customerName'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Order Date',
                          _formatDate(data['createdAt'] ?? data['timestamp']),
                        ),
                        _buildInfoRow('Status', currentStatus),
                        // Update Status dropdown - Only for Admin/Staff
                        if (_isAdminOrStaff) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: currentStatus,
                            decoration: const InputDecoration(
                              labelText: 'Update Status',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'quoted',
                                child: Text('Quoted'),
                              ),
                              DropdownMenuItem(
                                value: 'processing',
                                child: Text('Processing'),
                              ),
                              DropdownMenuItem(
                                value: 'completed',
                                child: Text('Completed'),
                              ),
                              DropdownMenuItem(
                                value: 'delivered',
                                child: Text('Delivered'),
                              ),
                            ],
                            onChanged: (newStatus) {
                              if (newStatus != null) {
                                widget.orderRef.update({
                                  'status': newStatus,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Status updated to $newStatus'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Delivery Schedule Section (Admin/Staff only)
                if (_isAdminOrStaff) _buildDeliveryScheduleSection(data),
                if (_isAdminOrStaff) const SizedBox(height: 16),
                // Rate Order Section (Customer only, when status is "Delivered")
                if (!_isAdminOrStaff && 
                    (statusRaw.toLowerCase() == 'delivered' || currentStatus == 'delivered'))
                  _buildRateOrderSection(),
                if (!_isAdminOrStaff && 
                    (statusRaw.toLowerCase() == 'delivered' || currentStatus == 'delivered'))
                  const SizedBox(height: 16),
                // Items Section
                const Text(
                  'Product Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  final productName =
                      itemMap['productName'] ?? 'Unknown Product';
                  final qty = itemMap['qty'] ?? itemMap['quantity'] ?? 1;
                  final price = (itemMap['price'] ?? 0.0) as num;
                  final glassType = itemMap['glassType'] ?? 'Standard';
                  final length = itemMap['length'] ?? 'N/A';
                  final width = itemMap['width'] ?? 'N/A';
                  final productImage = itemMap['productImage'] as String? ?? 
                                      itemMap['image'] as String? ?? 
                                      itemMap['imageUrl'] as String?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Image
                          if (productImage != null && productImage.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                ImageUrlHelper.encodeUrl(productImage),
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                cacheHeight: kIsWeb ? null : 400,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 200,
                                    color: AppColors.border,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 200,
                                  color: AppColors.border,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          if (productImage != null && productImage.isNotEmpty)
                            const SizedBox(height: 12),
                          // Product Name
                          Text(
                            productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow('Glass Type', glassType.toString()),
                          _buildInfoRow('Length', '$length cm'),
                          _buildInfoRow('Width', '$width cm'),
                          _buildInfoRow('Quantity', qty.toString()),
                          _buildInfoRow(
                            'Price',
                            PriceFormatter.formatPrice(price.toDouble()),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                PriceFormatter.formatPrice(
                                  price * (qty as num).toDouble(),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                // Total Card
                Card(
                  color: AppColors.primary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          PriceFormatter.formatPrice(totalAmount.toDouble()),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryScheduleSection(Map<String, dynamic> data) {
    final scheduleStatus = (data['scheduleStatus'] as String?) ?? 'pending';
    final orderStatus = (data['status'] as String?) ?? '';
    final deliveryDate = data['deliveryDate'] as Timestamp?;
    final deliveryTime = data['deliveryTime'] as String?;
    final assignedStaffName = data['assignedStaffName'] as String?;
    final scheduleNote = data['scheduleNote'] as String?;
    final customerId = data['customerId'] as String? ?? '';
    
    // Show "Set Schedule" button if status is "pending_delivery" or scheduleStatus is "pending"
    final needsScheduling = orderStatus == 'pending_delivery' || scheduleStatus == 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Delivery Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (needsScheduling) ...[
              const Text(
                'No delivery schedule set yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (context) => DeliveryScheduleDialog(
                        orderId: widget.orderId,
                        orderRef: widget.orderRef,
                        customerId: customerId,
                      ),
                    );
                    if (result == true && mounted) {
                      setState(() {}); // Refresh
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Set Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else if (scheduleStatus == 'scheduled') ...[
              if (deliveryDate != null)
                _buildInfoRow(
                  'Date',
                  _formatDate(deliveryDate),
                ),
              if (deliveryTime != null)
                _buildInfoRow('Time', deliveryTime),
              if (assignedStaffName != null)
                _buildInfoRow('Assigned Staff', assignedStaffName),
              if (scheduleNote != null && scheduleNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Notes:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scheduleNote,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _markAsDelivered,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark as Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else if (scheduleStatus == 'completed') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 8),
                    const Text(
                      'Delivery Completed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              if (deliveryDate != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow('Delivered Date', _formatDate(deliveryDate)),
              ],
              if (assignedStaffName != null)
                _buildInfoRow('Delivered By', assignedStaffName),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRateOrderSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.orderRef.collection('rating').limit(1).snapshots(),
      builder: (context, ratingSnapshot) {
        final hasRating = ratingSnapshot.hasData && 
                         ratingSnapshot.data != null && 
                         ratingSnapshot.data!.docs.isNotEmpty;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Rate Order',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (hasRating) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success),
                        const SizedBox(width: 8),
                        const Text(
                          'Thank you for your rating!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  _RatingForm(orderRef: widget.orderRef),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RatingForm extends StatefulWidget {
  final DocumentReference orderRef;

  const _RatingForm({required this.orderRef});

  @override
  State<_RatingForm> createState() => _RatingFormState();
}

class _RatingFormState extends State<_RatingForm> {
  int _selectedStars = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final orderService = OrderService();
      await orderService.updateOrderRating(
        orderId: widget.orderRef.id,
        rating: _selectedStars,
        review: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How would you rate this order?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starNumber = index + 1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedStars = starNumber;
                });
              },
              child: Icon(
                starNumber <= _selectedStars
                    ? Icons.star
                    : Icons.star_border,
                color: AppColors.primary,
                size: 40,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Optional: Share your experience...',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitRating,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                    'Submit Rating',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
