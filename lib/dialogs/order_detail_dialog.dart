import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../utils/price_formatter.dart';
import '../services/notification_service.dart';

class OrderDetailDialog extends StatefulWidget {
  final DocumentReference orderRef;
  const OrderDetailDialog({super.key, required this.orderRef});

  @override
  State<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<OrderDetailDialog> {
  final List<String> _statuses = const [
    'pending',
    'processing',
    'approved',
    'install_scheduled',
    'to_install',
    'shipped',
    'completed',
    'delivered',
  ];

  final List<String> _paymentStatuses = const [
    'unpaid',
    'paid',
    'partial',
  ];

  Map<String, dynamic>? _order;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await widget.orderRef.get();
    setState(() {
      _order = (snap.data() as Map<String, dynamic>?) ?? {};
    });
  }

  Future<void> _save() async {
    if (_order == null) return;
    setState(() => _saving = true);
    try {
      final oldStatus = _order!['status'] as String?;
      final newStatus = _order!['status'] as String?;
      
      await widget.orderRef.update({
        'status': _order!['status'],
        'paymentStatus': _order!['paymentStatus'],
        'statusLabel': _getStatusLabel(_order!['status']),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to customer if status changed
      if (newStatus != null && oldStatus != newStatus) {
        try {
          final customerId = _order!['customerId'] as String? ?? 
                            _order!['userId'] as String? ?? '';
          
          if (customerId.isNotEmpty) {
            final notificationService = NotificationService.instance;
            await notificationService.notifyOrderStatusChange(
              customerId: customerId,
              orderId: widget.orderRef.id,
              orderData: _order!,
              newStatus: newStatus,
            );
          }
        } catch (e) {
          // Don't fail the order update if notification fails
          if (kDebugMode) {
            print('⚠️ Error creating notification: $e');
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'approved':
        return 'Approved';
      case 'install_scheduled':
        return 'Install Scheduled';
      case 'to_install':
        return 'To Install';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      default:
        return status.toUpperCase();
    }
  }

  /// Get total price from order data, computing from items if totalPrice doesn't exist
  double _getTotalPrice(Map<String, dynamic> orderData) {
    // Get totalPrice from Firestore
    final totalPriceValue = orderData['totalPrice'];
    double? totalPrice;
    if (totalPriceValue is num) {
      totalPrice = totalPriceValue.toDouble();
    } else if (totalPriceValue is String) {
      totalPrice = double.tryParse(totalPriceValue);
    }
    
    // Compute from items if totalPrice doesn't exist
    if (totalPrice == null) {
      double computedTotal = 0.0;
      final items = (orderData['items'] as List?) ?? [];
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
      return computedTotal;
    }
    
    return totalPrice;
  }

  String _formatOrderId(String id) {
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
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
          child: _order == null
              ? const SizedBox(
                  height: 400,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${_formatOrderId(widget.orderRef.id)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _saving ? null : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer Information Section
                            _buildSection(
                              'Customer Information',
                              [
                                _infoRow('Customer', _order!['customerName'] ?? _order!['customer'] ?? 'N/A'),
                                _infoRow('Email', _order!['customerEmail'] ?? _order!['email'] ?? 'N/A'),
                                _infoRow('Address', _order!['shippingAddress'] ?? _order!['address'] ?? 'N/A'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Order Status Section
                            _buildSection(
                              'Order Status',
                              [
                                _infoRow('Status', (_order!['status'] as String? ?? 'pending').toUpperCase()),
                                _infoRow('Payment', (_order!['paymentStatus'] as String? ?? 'unpaid').toUpperCase()),
                                _infoRow('Total', PriceFormatter.formatPrice(_getTotalPrice(_order!))),
                                _infoRow('Date', _formatDate(_order!['createdAt'] ?? _order!['timestamp'])),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Items Section
                            _buildItemsSection(),
                            const SizedBox(height: 24),
                            // Status Controls
                            _buildStatusControls(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => Navigator.of(context).pop(),
                          child: const Text('Close', style: TextStyle(color: AppColors.secondary)),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.dashboardCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    final items = _order!['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) {
      return _buildSection('Items', [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No items found', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.dashboardCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: items.map<Widget>((item) {
              final itemMap = item as Map<String, dynamic>;
              final productName = itemMap['productName'] ?? 
                                  itemMap['title'] ?? 
                                  itemMap['name'] ?? 
                                  'Unknown Product';
              final quantity = itemMap['quantity'] ?? itemMap['qty'] ?? 1;
              final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
              final subtotal = price * (quantity as num).toDouble();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty: $quantity • ${PriceFormatter.formatPrice(price)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      PriceFormatter.formatPrice(subtotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Update Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.dashboardCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: (_order!['status'] as String?) ?? 'pending',
                decoration: const InputDecoration(
                  labelText: 'Order Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                items: _statuses.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.toUpperCase().replaceAll('_', ' ')),
                  );
                }).toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _order!['status'] = v);
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: (_order!['paymentStatus'] as String?) ?? 'unpaid',
                decoration: const InputDecoration(
                  labelText: 'Payment Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                items: _paymentStatuses.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.toUpperCase()),
                  );
                }).toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _order!['paymentStatus'] = v);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
