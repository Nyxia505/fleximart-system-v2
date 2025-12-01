import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../pages/order_detail_page.dart';
import '../utils/price_formatter.dart';
import '../services/order_service.dart';
import '../customer/rating_dialog.dart';
import 'order_tracking_page.dart';

class OrdersPage extends StatefulWidget {
  final String? initialFilterKey; // null or one of: to_pay, to_install, to_receive, to_rate
  const OrdersPage({super.key, this.initialFilterKey});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  final List<String> _tabs = ['all', 'to_pay', 'to_install', 'to_receive', 'to_rate'];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialFilterKey != null
        ? _tabs.indexOf(widget.initialFilterKey!)
        : 0;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
          ),
        ),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.white,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.white,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'To Pay'),
            Tab(text: 'To Install'),
            Tab(text: 'To Receive'),
            Tab(text: 'To Rate'),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: user == null
            ? Center(
                child: Text(
                  'Please log in to view orders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: _tabs.map((key) {
                  return _OrdersList(filterKey: key);
                }).toList(),
              ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final String filterKey; // all, to_pay, to_install, to_receive, to_rate
  const _OrdersList({required this.filterKey});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final query = _buildOrdersQuery(user.uid, filterKey);
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots().handleError((error) {
        debugPrint('⚠️ Error loading orders: $error');
        // Return empty snapshot on error to show empty state instead of crashing
        return FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user.uid)
            .limit(0)
            .snapshots();
      }),
      builder: (context, snapshot) {
        // Handle errors gracefully
        if (snapshot.hasError) {
          debugPrint('⚠️ StreamBuilder error: ${snapshot.error}');
          return SafeArea(
            child: Center(
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
                    'Error loading orders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _emptyText(filterKey),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Filter orders by status in memory (to avoid composite index requirements)
        final allDocs = snapshot.data!.docs;
        final filteredDocs = _filterOrders(allDocs, filterKey);
        
        // Sort by createdAt in memory (descending - newest first)
        final docs = List<QueryDocumentSnapshot>.from(filteredDocs);
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
        
        if (docs.isEmpty) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _emptyText(filterKey),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = (data['status'] as String?) ?? 'pending';
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
                    final items = (data['items'] as List?) ?? [];
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
                    
                    final total = totalPrice ?? computedTotal;
                    final createdAt = data['createdAt'];
                    final deliveryDate = data['deliveryDate'] ?? data['deliveryDateTime'];
                    // Get rating data
                    final rating = (data['rating'] as num?)?.toInt() ?? 0;
                    final review = data['review'] as String? ?? '';
                    final ratingImageUrl =
                        (data['ratingImageUrl'] as String?) ??
                        (data['rating_image_url'] as String?) ??
                        (data['imageUrl'] as String?) ??
                        (data['image_url'] as String?);
                    
                    // Get order quantity - sum all item quantities
                    int totalQuantity = 0;
                    if (items.isNotEmpty) {
                      for (var item in items) {
                        if (item is Map<String, dynamic>) {
                          final qtyValue = item['quantity'];
                          if (qtyValue is num) {
                            totalQuantity += qtyValue.toInt();
                          } else if (qtyValue is String) {
                            totalQuantity += int.tryParse(qtyValue) ?? 0;
                          }
                        }
                      }
                    }
                    
                    // Get first item for display
                    final firstItem = items.isNotEmpty ? items[0] as Map<String, dynamic> : null;
                    final productImage = firstItem?['productImage']?.toString() ?? 
                                        firstItem?['image']?.toString() ?? 
                                        '';
                    final productName = firstItem?['productName']?.toString() ?? 
                                      firstItem?['name']?.toString() ?? 
                                      data['productName']?.toString() ??
                                      'Custom Product';
                    final glassType = firstItem?['glassType']?.toString() ?? 'N/A';
                    final aluminumType = firstItem?['aluminumType']?.toString() ?? 'N/A';
                    final length = (firstItem?['length'] as num?)?.toDouble() ?? 0.0;
                    final width = (firstItem?['width'] as num?)?.toDouble() ?? 0.0;
                    
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderDetailPage(
                              orderId: doc.id,
                              orderRef: doc.reference,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with Order Number and Status Badge
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.05),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order #${doc.id.substring(0, 8).toUpperCase()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _statusColor(status),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _statusIcon(status),
                                          size: 16,
                                          color: _statusColor(status),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatStatus(status),
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Product Details
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image
                                  if (productImage.toString().isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        productImage.toString(),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey[400],
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  const SizedBox(width: 16),
                                  
                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          productName.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        if (length > 0 && width > 0)
                                          Text(
                                            'Dimensions: ${length.toStringAsFixed(0)}" × ${width.toStringAsFixed(0)}"',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Glass: $glassType',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Frame: $aluminumType',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (totalQuantity > 0)
                                          Text(
                                            'Quantity: $totalQuantity',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        Text(
                                          PriceFormatter.formatPrice(total),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Order Date and Delivery Date
                            if (createdAt != null || deliveryDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  border: Border(
                                    top: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (createdAt != null) ...[
                                      Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ordered: ${_formatDate(createdAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                    if (deliveryDate != null) ...[
                                      if (createdAt != null) const SizedBox(width: 16),
                                      Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delivery: ${_formatScheduleDate(deliveryDate)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            
                            // Delivery Schedule Section (if scheduled)
                            if (data['scheduleStatus'] == 'scheduled' || data['scheduleStatus'] == 'completed') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.05),
                                  border: Border(
                                    top: BorderSide(color: Colors.grey[200]!),
                                    bottom: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (data['deliveryDate'] != null)
                                            Text(
                                              _formatScheduleDate(data['deliveryDate']),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          if (data['deliveryTime'] != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Time: ${data['deliveryTime']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                          if (data['assignedStaffName'] != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Staff: ${data['assignedStaffName']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (data['scheduleStatus'] == 'scheduled')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Scheduled',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12, // Increased for clarity
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else if (data['scheduleStatus'] == 'completed')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.success,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Delivered',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12, // Increased for clarity
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            
                            // Rating Section (if rating exists)
                            if (rating > 0) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.03),
                                  border: Border(
                                    top: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Your Rating',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const Spacer(),
                                        // Star rating display
                                        Row(
                                          children: List.generate(5, (index) {
                                            return Icon(
                                              index < rating
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: AppColors.primary,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    if (review.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.primary.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.format_quote,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                review,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (ratingImageUrl != null && ratingImageUrl.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          ratingImageUrl,
                                          width: double.infinity,
                                          height: 150,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              height: 150,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Icon(Icons.broken_image, size: 32),
                                              ),
                                            );
                                          },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              height: 150,
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                          loadingProgress.expectedTotalBytes!
                                                      : null,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            
                            // Order Info and Actions
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Order Date: ${_formatDate(createdAt)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => OrderDetailPage(
                                                  orderId: doc.id,
                                                  orderRef: doc.reference,
                                                ),
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: AppColors.primary),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          child: const Text(
                                            'View Details',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _handleStatusAction(context, status, doc.reference);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          child: Text(
                                            _getActionButtonText(status),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Query _buildOrdersQuery(String uid, String key) {
    final col = FirebaseFirestore.instance.collection('orders');
    // Query by customerId only - sort in memory to avoid composite index requirements
    return col.where('customerId', isEqualTo: uid);
  }
  
  static List<QueryDocumentSnapshot> _filterOrders(
    List<QueryDocumentSnapshot> docs,
    String key,
  ) {
    switch (key) {
      case 'to_pay':
        // Already filtered by query
        return docs;
      case 'to_install': {
        final statuses = [
          'to_install',
          'installation_scheduled',
          'in_progress',
        ];
        return docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? '';
          return statuses.contains(status.toLowerCase());
        }).toList();
      }
      case 'to_receive': {
        final statuses = ['to_receive'];
        return docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? '';
          return statuses.contains(status.toLowerCase());
        }).toList();
      }
      case 'to_rate': {
        final statuses = [
          'delivered',
        ];
        return docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? '';
          final hasRated = data['customerHasRated'] as bool? ?? false;
          return statuses.contains(status.toLowerCase()) && !hasRated;
        }).toList();
      }
      case 'all':
      default:
        return docs;
    }
  }

  static String _formatScheduleDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return 'N/A';
  }

  static String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown date';
  }

  static String _emptyText(String key) {
    switch (key) {
      case 'to_pay':
        return 'No orders to pay';
      case 'to_install':
        return 'No orders to install';
      case 'to_receive':
        return 'No orders to receive';
      case 'to_rate':
        return 'No orders to rate';
      default:
        return 'No orders yet';
    }
  }

  static IconData _statusIcon(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'to_pay':
        return Icons.account_balance_wallet_outlined;
      case 'payment_review':
        return Icons.payment_outlined;
      case 'to_install':
      case 'installation_scheduled':
      case 'in_progress':
        return Icons.build_outlined;
      case 'to_receive':
        return Icons.local_shipping_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  static Color _statusColor(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'to_pay':
        return AppColors.pending; // Yellow
      case 'payment_review':
        return AppColors.info; // Blue
      case 'to_install':
      case 'installation_scheduled':
      case 'in_progress':
        return AppColors.toInstall; // Orange
      case 'to_receive':
        return AppColors.info; // Blue
      case 'completed':
      case 'delivered':
        return AppColors.primary; // Crimson Red
      case 'cancelled':
        return AppColors.cancelled; // Red
      default:
        return AppColors.textSecondary; // Gray
    }
  }

  static String _formatStatus(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'to_pay':
        return 'To Pay';
      case 'payment_review':
        return 'Payment Review';
      case 'to_install':
      case 'installation_scheduled':
      case 'in_progress':
        return 'To Install';
      case 'to_receive':
        return 'To Receive';
      case 'completed':
      case 'delivered':
        return 'To Rate';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ').split(' ').map((word) => 
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  static String _getActionButtonText(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'to_pay':
        return 'Proceed to Buy';
      case 'payment_review':
        return 'View Payment';
      case 'to_install':
      case 'installation_scheduled':
      case 'in_progress':
        return 'Track Installation';
      case 'to_receive':
        return 'Track Delivery';
      case 'completed':
      case 'delivered':
        return 'Rate & Review';
      case 'cancelled':
        return 'View Details';
      default:
        return 'View';
    }
  }

  static Future<void> _handleStatusAction(BuildContext context, String status, DocumentReference orderRef) async {
    final statusLower = status.toLowerCase();
    if (statusLower == 'to_pay') {
      // Navigate to payment screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment feature coming soon'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else if (statusLower == 'completed' || statusLower == 'delivered') {
      // Show rating dialog for completed/delivered orders
      final orderDoc = await orderRef.get();
      final orderData = orderDoc.data() as Map<String, dynamic>?;
      final hasRating = orderData?['hasRating'] as bool? ?? false;
      
      if (!hasRating) {
        // Show rating dialog
        final firstItem = (orderData?['items'] as List?)?.isNotEmpty == true
            ? (orderData!['items'] as List)[0] as Map<String, dynamic>?
            : null;
        final productName = firstItem?['productName'] ?? 
                           orderData?['productName'] ?? 
                           'Product';
        
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => RatingDialog(
            orderId: orderRef.id,
            productName: productName.toString(),
          ),
        );

        if (result != null) {
          final imageBytes = result['imageBytes'] as Uint8List?;
          try {
            final orderService = OrderService();
            if (imageBytes == null) {
              throw Exception('Rating photo is required.');
            }
            await orderService.updateOrderRating(
              orderId: orderRef.id,
              rating: result['rating'] as int,
              imageBytes: imageBytes,
              imageName: result['imageName'] as String?,
              review: result['review'] as String?,
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your rating!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error submitting rating: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
      } else {
        // Already rated, show message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already rated this order'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      }
    } else {
      // Track order timeline
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrackOrderTimeline(
            orderId: orderRef.id,
          ),
        ),
      );
    }
  }
}


