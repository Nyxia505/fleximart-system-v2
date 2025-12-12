import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quotation_model.dart';
import '../models/notification_model.dart';
import '../services/quotation_service.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/quotation_card.dart';
import '../utils/price_formatter.dart';

/// Admin Quotation Screen
/// 
/// Displays all quotations grouped by status
/// Allows admin to override staff updates
class AdminQuotationScreen extends StatefulWidget {
  const AdminQuotationScreen({super.key});

  @override
  State<AdminQuotationScreen> createState() => _AdminQuotationScreenState();
}

class _AdminQuotationScreenState extends State<AdminQuotationScreen>
    with SingleTickerProviderStateMixin {
  final QuotationService _quotationService = QuotationService();
  final NotificationService _notificationService = NotificationService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please log in',
            style: AppTextStyles.heading3(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('All Quotations'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Quoted'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context, user.uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quotations')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
          if (kDebugMode) {
            print('⚠️ OrderBy failed for quotations, using simple query: $error');
          }
          return FirebaseFirestore.instance
              .collection('quotations')
              .snapshots();
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading quotations',
                      style: AppTextStyles.heading3(color: AppColors.error),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No quotations found',
                      style: AppTextStyles.heading3(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Sort manually if orderBy failed
          final quotationsList = List<QueryDocumentSnapshot>.from(
            snapshot.data!.docs,
          );
          
          quotationsList.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreated = aData['createdAt'] as Timestamp?;
            final bCreated = bData['createdAt'] as Timestamp?;
            
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated); // Descending
          });

          final allQuotations = quotationsList
              .map((doc) => Quotation.fromFirestore(doc))
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildQuotationList(allQuotations, user.uid),
              _buildQuotationList(
                allQuotations.where((q) {
                  final status = q.status.toLowerCase();
                  return status == 'pending';
                }).toList(),
                user.uid,
              ),
              _buildQuotationList(
                allQuotations.where((q) {
                  final status = q.status.toLowerCase();
                  return status == 'quoted';
                }).toList(),
                user.uid,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuotationList(List<Quotation> quotations, String adminId) {
    if (quotations.isEmpty) {
      return Center(
        child: Text(
          'No quotations in this category',
          style: AppTextStyles.bodyMedium(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: quotations.length,
        itemBuilder: (context, index) {
          final quotation = quotations[index];
          return QuotationCard(
            quotation: quotation,
            onTap: () => _showQuotationDetails(context, quotation),
            onStatusUpdate: (newStatus) => _updateStatus(
              context,
              quotation.id,
              newStatus,
              adminId,
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String quotationId,
    String newStatus,
    String adminId,
  ) async {
    try {
      await _quotationService.updateQuotationStatus(
        quotationId: quotationId,
        newStatus: newStatus,
        updatedBy: adminId,
        updatedByRole: 'admin',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quotation status updated to $newStatus'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showQuotationDetails(BuildContext context, Quotation quotation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AdminQuotationDetailsPage(quotation: quotation),
      ),
    );
  }

  void _showNotifications(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: AppTextStyles.heading2(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _notificationService.getNotificationsForUser(userId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No notifications',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  final notifications = snapshot.data!.docs
                      .map((doc) => NotificationModel.fromFirestore(doc))
                      .toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: notification.read
                              ? AppColors.background
                              : AppColors.primary,
                          child: Icon(
                            Icons.notifications,
                            color: notification.read
                                ? AppColors.textSecondary
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          notification.title ?? 'Notification',
                          style: AppTextStyles.bodyMedium().copyWith(
                            fontWeight: notification.read
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          notification.message,
                          style: AppTextStyles.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: notification.createdAt != null
                            ? Text(
                                _formatTime(notification.createdAt!),
                                style: AppTextStyles.caption(
                                  color: AppColors.textHint,
                                ),
                              )
                            : null,
                        onTap: () {
                          _notificationService.markAsRead(notification.id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      final hours = difference.inHours;
      if (hours == 0) {
        final minutes = difference.inMinutes;
        return '$minutes min ago';
      }
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Admin Quotation Details Page
/// 
/// Shows quotation details and allows admin to set prices
class _AdminQuotationDetailsPage extends StatefulWidget {
  final Quotation quotation;

  const _AdminQuotationDetailsPage({required this.quotation});

  @override
  State<_AdminQuotationDetailsPage> createState() => _AdminQuotationDetailsPageState();
}

class _AdminQuotationDetailsPageState extends State<_AdminQuotationDetailsPage> {
  final QuotationService _quotationService = QuotationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<TextEditingController> _priceControllers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePriceControllers();
  }

  // Group items by productName/productId + length + width
  Map<String, List<Map<String, dynamic>>> _groupItems(List<dynamic> items) {
    final groups = <String, List<Map<String, dynamic>>>{};
    
    for (var item in items) {
      final itemMap = item as Map<String, dynamic>? ?? {};
      
      // Use productName as primary identifier, fallback to productId
      final productName = (itemMap['productName'] as String? ?? 
                          itemMap['name'] as String? ?? 
                          widget.quotation.productName ?? 
                          '').trim().toLowerCase();
      final productId = (itemMap['productId']?.toString() ?? '').trim();
      
      // Normalize dimensions - handle nulls and convert to consistent format
      String lengthStr = '';
      String widthStr = '';
      
      final lengthValue = itemMap['length'] ?? widget.quotation.length;
      if (lengthValue != null) {
        if (lengthValue is num) {
          lengthStr = lengthValue.toStringAsFixed(0);
        } else {
          lengthStr = lengthValue.toString().trim();
        }
      }
      
      final widthValue = itemMap['width'] ?? widget.quotation.width;
      if (widthValue != null) {
        if (widthValue is num) {
          widthStr = widthValue.toStringAsFixed(0);
        } else {
          widthStr = widthValue.toString().trim();
        }
      }
      
      // Create grouping key: use productName (or productId if name is empty) + dimensions
      final productKey = productName.isNotEmpty ? productName : productId;
      final key = '$productKey|$lengthStr|$widthStr';
      
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(itemMap);
    }
    
    return groups;
  }

  void _initializePriceControllers() {
    final items = widget.quotation.items ?? [];
    if (items.isEmpty) {
      // If no items, create one from quotation data
      _priceControllers.add(TextEditingController(text: '0'));
    } else {
      // Group items and create one controller per group
      final groups = _groupItems(items);
      for (var groupKey in groups.keys) {
        final groupItems = groups[groupKey]!;
        // Get price from first item in group (they should all have same price)
        final firstItem = groupItems.first;
        final price = firstItem['price'] ?? 0;
        _priceControllers.add(TextEditingController(
          text: price is num ? price.toStringAsFixed(2) : '0',
        ));
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _priceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _getItemsWithPrices() {
    final items = widget.quotation.items ?? [];
    if (items.isEmpty) {
      // Create item from quotation-level fields
      final item = <String, dynamic>{
        'productName': widget.quotation.productName ?? 'Product',
        'quantity': 1,
        'price': double.tryParse(_priceControllers[0].text) ?? 0.0,
      };
      if (widget.quotation.length != null) {
        item['length'] = widget.quotation.length;
      }
      if (widget.quotation.width != null) {
        item['width'] = widget.quotation.width;
      }
      if (widget.quotation.productId != null) {
        item['productId'] = widget.quotation.productId;
      }
      if (widget.quotation.productImage != null) {
        item['productImage'] = widget.quotation.productImage;
      }
      return [item];
    } else {
      // Group items and apply group price to all items in each group
      final groups = _groupItems(items);
      final result = <Map<String, dynamic>>[];
      int controllerIndex = 0;
      
      for (var groupKey in groups.keys) {
        final groupItems = groups[groupKey]!;
        final groupPrice = double.tryParse(_priceControllers[controllerIndex].text) ?? 0.0;
        
        // Apply the same price to all items in this group
        for (var originalItem in groupItems) {
          final item = Map<String, dynamic>.from(originalItem);
          item['price'] = groupPrice;
          // Ensure required fields exist
          if (!item.containsKey('productName') && widget.quotation.productName != null) {
            item['productName'] = widget.quotation.productName;
          }
          if (!item.containsKey('quantity')) {
            item['quantity'] = 1;
          }
          result.add(item);
        }
        controllerIndex++;
      }
      
      return result;
    }
  }

  double _calculateTotal() {
    return _getItemsWithPrices().fold(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      return sum + (price * quantity);
    });
  }

  Future<void> _savePrices() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final items = _getItemsWithPrices();
      final totalPrice = _calculateTotal();

      // Save prices
      await _quotationService.updateQuotationWithAdminPrices(
        quotationId: widget.quotation.id,
        items: items,
        adminTotalPrice: totalPrice,
        updatedBy: _auth.currentUser?.uid,
        updatedByRole: 'admin',
      );

      // Also update status to "quoted" when saving prices
      if (widget.quotation.status != 'quoted') {
        await _quotationService.updateQuotationStatus(
          quotationId: widget.quotation.id,
          newStatus: 'quoted',
          updatedBy: _auth.currentUser?.uid ?? '',
          updatedByRole: 'admin',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prices saved and quotation quoted! Total: ${PriceFormatter.formatPrice(totalPrice)}'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving prices: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.quotation.items ?? [];
    final hasItems = items.isNotEmpty;
    
    // Group items by productName/productId + length + width
    final groups = hasItems ? _groupItems(items) : <String, List<Map<String, dynamic>>>{};
    
    // Create display items from groups (one per group)
    // Only show groups that have a productName (exclude component items like "Door Frame", "Hinges", etc.)
    final displayItems = <Map<String, dynamic>>[];
    if (groups.isNotEmpty) {
      for (var groupKey in groups.keys) {
        final groupItems = groups[groupKey]!;
        if (groupItems.isEmpty) continue;
        
        final firstItem = groupItems.first;
        final productName = (firstItem['productName'] as String? ?? 
                            firstItem['name'] as String? ?? 
                            widget.quotation.productName ?? 
                            '').trim();
        
        // Skip component items (items without productName)
        if (productName.isEmpty) continue;
        
        // Calculate total quantity for this group
        int totalQuantity = 0;
        for (var item in groupItems) {
          final qty = item['quantity'];
          if (qty != null) {
            totalQuantity += (qty is num) ? qty.toInt() : int.tryParse(qty.toString()) ?? 1;
          } else {
            totalQuantity += 1;
          }
        }
        
        // Create display item with group info
        final displayItem = Map<String, dynamic>.from(firstItem);
        displayItem['productName'] = productName;
        displayItem['quantity'] = totalQuantity;
        displayItem['_groupItems'] = groupItems; // Store original items for reference
        displayItem['_groupKey'] = groupKey;
        displayItems.add(displayItem);
      }
    } else if (!hasItems) {
      // Fallback if no items
      displayItems.add({
        'productName': widget.quotation.productName ?? 'Product',
        'length': widget.quotation.length ?? 0,
        'width': widget.quotation.width ?? 0,
        'quantity': 1,
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quotation Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.quotation.status != 'quoted')
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _savePrices,
              tooltip: 'Save Prices',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Information',
                      style: AppTextStyles.heading3(),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Name', widget.quotation.customerName ?? 'N/A'),
                    if (widget.quotation.customerEmail != null)
                      _buildDetailRow('Email', widget.quotation.customerEmail!),
                    _buildDetailRow(
                      'Date',
                      widget.quotation.createdAt != null
                          ? '${widget.quotation.createdAt!.day}/${widget.quotation.createdAt!.month}/${widget.quotation.createdAt!.year}'
                          : 'N/A',
                    ),
                    _buildDetailRow('Status', widget.quotation.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Items and Pricing
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Items & Pricing',
                          style: AppTextStyles.heading3(),
                        ),
                        if (widget.quotation.adminTotalPrice != null)
                          Text(
                            'Total: ${PriceFormatter.formatPrice(widget.quotation.adminTotalPrice!)}',
                            style: AppTextStyles.heading3(color: AppColors.primary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...displayItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value as Map<String, dynamic>? ?? {};
                      
                      // Parse productName with fallbacks
                      final productName = item['productName'] as String? ?? 
                                        item['name'] as String? ?? 
                                        widget.quotation.productName ?? 
                                        'Product';
                      
                      // Parse length with null safety
                      double? length;
                      final lengthValue = item['length'] ?? widget.quotation.length;
                      if (lengthValue != null) {
                        length = (lengthValue is num) ? lengthValue.toDouble() : double.tryParse(lengthValue.toString());
                      }
                      
                      // Parse width with null safety
                      double? width;
                      final widthValue = item['width'] ?? widget.quotation.width;
                      if (widthValue != null) {
                        width = (widthValue is num) ? widthValue.toDouble() : double.tryParse(widthValue.toString());
                      }
                      
                      // Parse quantity (this is the total quantity for the group)
                      int quantity = 1;
                      final quantityValue = item['quantity'];
                      if (quantityValue != null) {
                        quantity = (quantityValue is num) ? quantityValue.toInt() : int.tryParse(quantityValue.toString()) ?? 1;
                      }
                      
                      // Format dimensions display
                      String dimensionsText = 'N/A';
                      if (length != null && width != null) {
                        dimensionsText = '${length.toStringAsFixed(0)}" × ${width.toStringAsFixed(0)}"';
                      } else if (length != null) {
                        dimensionsText = '${length.toStringAsFixed(0)}"';
                      } else if (width != null) {
                        dimensionsText = '${width.toStringAsFixed(0)}"';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: AppTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Dimensions: $dimensionsText'),
                            Text('Total Quantity: $quantity'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _priceControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Price per item (₱)',
                                prefixText: '₱',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              enabled: widget.quotation.status != 'quoted',
                              onChanged: (_) => setState(() {}), // Update subtotal on change
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Subtotal: ${PriceFormatter.formatPrice((double.tryParse(_priceControllers[index].text) ?? 0.0) * quantity)}',
                              style: AppTextStyles.bodyMedium(color: AppColors.primary),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Price:',
                          style: AppTextStyles.heading3(),
                        ),
                        Text(
                          PriceFormatter.formatPrice(_calculateTotal()),
                          style: AppTextStyles.heading3(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (widget.quotation.notes != null && widget.quotation.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: AppTextStyles.heading3(),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.quotation.notes!),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.quotation.status != 'quoted') ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _savePrices,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Prices & Quote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.caption(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium(),
            ),
          ),
        ],
      ),
    );
  }
}

