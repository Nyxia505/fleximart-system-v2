import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'order_card_widget.dart';
import 'payment_flow.dart';
import 'rating_dialog.dart';
import '../services/order_service.dart';

class MyPurchasesPage extends StatefulWidget {
  const MyPurchasesPage({super.key});

  @override
  State<MyPurchasesPage> createState() => _MyPurchasesPageState();
}

class _MyPurchasesPageState extends State<MyPurchasesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
          child: Text('Please log in', style: AppTextStyles.heading3()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Purchases'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'To Pay'),
            Tab(text: 'To Receive'),
            Tab(text: 'To Install'),
            Tab(text: 'To Rate'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ToPayTab(userId: user.uid, orderService: _orderService),
          _ToReceiveTab(userId: user.uid),
          _ToInstallTab(userId: user.uid),
          _ToRateTab(userId: user.uid, orderService: _orderService),
        ],
      ),
    );
  }
}

class _ToPayTab extends StatelessWidget {
  final String userId;
  final OrderService orderService;

  const _ToPayTab({required this.userId, required this.orderService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading orders',
                  style: AppTextStyles.heading3(color: AppColors.error),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No orders to pay');
        }

        final allOrders = snapshot.data!.docs;
        final filteredOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String? ?? '').toLowerCase();
          return status == 'pending_payment';
        }).toList();
        
        // Sort by createdAt in memory (descending - newest first)
        final orders = List<QueryDocumentSnapshot>.from(filteredOrders);
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'] as Timestamp?;
          final bCreated = bData['createdAt'] as Timestamp?;
          
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return bCreated.compareTo(aCreated); // Descending
        });

        if (orders.isEmpty) {
          return _buildEmptyState('No orders to pay');
        }

        return RefreshIndicator(
          onRefresh: () async {},
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              return OrderCard(
                orderId: doc.id,
                orderData: data,
                actionButtons: [
                  OrderActionButton(
                    label: 'Pay',
                    icon: Icons.payment,
                    color: AppColors.primary,
                    onPressed: () => _handlePayment(context, doc.id, data),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handlePayment(
    BuildContext context,
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => PaymentFlowDialog(
          orderId: orderId,
          amount:
              (orderData['totalPrice'] as num?)?.toDouble() ??
              (orderData['totalAmount'] as num?)?.toDouble() ??
              0.0,
        ),
      );

      if (result == true) {
        await orderService.updateOrderStatus(
          orderId: orderId,
          newStatus: 'paid',
          updateTimestamp: 'paidAt',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payment successful'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.heading3(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ToReceiveTab extends StatelessWidget {
  final String userId;

  const _ToReceiveTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading orders',
                  style: AppTextStyles.heading3(color: AppColors.error),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No orders to receive');
        }

        final allOrders = snapshot.data!.docs;
        final filteredOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String? ?? '').toLowerCase();
          return status == 'shipped';
        }).toList();
        
        // Sort by createdAt in memory (descending - newest first)
        final orders = List<QueryDocumentSnapshot>.from(filteredOrders);
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'] as Timestamp?;
          final bCreated = bData['createdAt'] as Timestamp?;
          
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return bCreated.compareTo(aCreated); // Descending
        });

        if (orders.isEmpty) {
          return _buildEmptyState('No orders to receive');
        }

        return RefreshIndicator(
          onRefresh: () async {},
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              return OrderCard(
                orderId: doc.id,
                orderData: data,
                actionButtons: [
                  OrderActionButton(
                    label: 'Confirm Received',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    onPressed: () =>
                        _handleConfirmReceived(context, doc.id, data),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleConfirmReceived(
    BuildContext context,
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    try {
      final orderService = OrderService();
      final requiresInstallation =
          orderData['installationRequired'] as bool? ?? false;

      final newStatus = requiresInstallation ? 'awaiting_installation' : 'completed';
      
      if (kDebugMode) {
        debugPrint('✅ Confirming order receipt: $orderId');
        debugPrint('   - New status: $newStatus');
        debugPrint('   - Requires installation: $requiresInstallation');
      }
      
      await orderService.updateOrderStatus(
        orderId: orderId,
        newStatus: newStatus,
        updateTimestamp: 'deliveredAt',
      );

      if (kDebugMode) {
        debugPrint('✅ Order status updated successfully. Order should now appear in Order History.');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              requiresInstallation
                  ? 'Order received. Awaiting installation. Check Order History!'
                  : 'Order received and completed. Check Order History!',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.heading3(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ToInstallTab extends StatelessWidget {
  final String userId;

  const _ToInstallTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading orders',
                  style: AppTextStyles.heading3(color: AppColors.error),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No orders awaiting installation');
        }

        final allOrders = snapshot.data!.docs;
        final filteredOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final installationRequired =
              data['installationRequired'] as bool? ?? false;
          final deliveredAt = data['deliveredAt'];
          return installationRequired && deliveredAt != null;
        }).toList();
        
        // Sort by createdAt in memory (descending - newest first)
        final orders = List<QueryDocumentSnapshot>.from(filteredOrders);
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'] as Timestamp?;
          final bCreated = bData['createdAt'] as Timestamp?;
          
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return bCreated.compareTo(aCreated); // Descending
        });

        if (orders.isEmpty) {
          return _buildEmptyState('No orders awaiting installation');
        }

        return RefreshIndicator(
          onRefresh: () async {},
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              return OrderCard(
                orderId: doc.id,
                orderData: data,
                actionButtons: [
                  OrderActionButton(
                    label: 'Confirm Delivery',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    onPressed: () =>
                        _handleConfirmDelivery(context, doc.id),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleConfirmDelivery(
    BuildContext context,
    String orderId,
  ) async {
    try {
      final orderService = OrderService();
      await orderService.updateOrderStatus(
        orderId: orderId,
        newStatus: 'delivered',
        updateTimestamp: 'deliveredAt',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Delivery confirmed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.build_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.heading3(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ToRateTab extends StatelessWidget {
  final String userId;
  final OrderService orderService;

  const _ToRateTab({required this.userId, required this.orderService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading orders',
                  style: AppTextStyles.heading3(color: AppColors.error),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No orders to rate');
        }

        final allOrders = snapshot.data!.docs;
        final filteredOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String? ?? '').toLowerCase();
          final rating = data['rating'] as num?;
          return (status == 'completed' || status == 'delivered') && rating == null;
        }).toList();
        
        // Sort by createdAt in memory (descending - newest first)
        final orders = List<QueryDocumentSnapshot>.from(filteredOrders);
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'] as Timestamp?;
          final bCreated = bData['createdAt'] as Timestamp?;
          
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return bCreated.compareTo(aCreated); // Descending
        });

        if (orders.isEmpty) {
          return _buildEmptyState('No orders to rate');
        }

        return RefreshIndicator(
          onRefresh: () async {},
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              return OrderCard(
                orderId: doc.id,
                orderData: data,
                actionButtons: [
                  OrderActionButton(
                    label: 'Rate & Review',
                    icon: Icons.star,
                    color: AppColors.primary,
                    onPressed: () => _showRatingDialog(context, doc.id, data),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showRatingDialog(
    BuildContext context,
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RatingDialog(
        orderId: orderId,
        productName: (orderData['productName'] as String?) ?? 'Product',
      ),
    );

    if (result != null) {
      try {
        await orderService.updateOrderRating(
          orderId: orderId,
          rating: result['rating'] as int,
          review: result['review'] as String?,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Thank you for your rating!'),
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
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_outline,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.heading3(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
