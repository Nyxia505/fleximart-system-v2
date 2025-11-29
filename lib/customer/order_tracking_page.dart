import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Modern Track Order page with delivery timeline
class TrackOrderTimeline extends StatelessWidget {
  final String orderId;

  const TrackOrderTimeline({
    super.key,
    required this.orderId,
  });

  DocumentReference<Map<String, dynamic>> get _orderRef =>
      FirebaseFirestore.instance.collection('orders').doc(orderId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Order'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.mainGradient)),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _orderRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Order not found', style: AppTextStyles.heading3(color: AppColors.error)),
                ],
              ),
            );
          }

          final orderData = snapshot.data!.data()!;
          final status = (orderData['status'] as String?) ?? 'pending';
          final deliveryDate = _parseTimestamp(orderData['deliveryDate']);
          final currentStep = _statusToStep(status);
          final statusText = _statusHeadline(status);
          final updates = _parseUpdates(orderData['updates']);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EstimatedDeliveryCard(date: deliveryDate),
                const SizedBox(height: 20),
                Text(statusText.title, style: AppTextStyles.heading2()),
                const SizedBox(height: 4),
                Text(statusText.subtitle, style: AppTextStyles.bodyMedium(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                _StatusTracker(currentStep: currentStep),
                const SizedBox(height: 24),
                Text('Latest updates', style: AppTextStyles.heading3()),
                const SizedBox(height: 12),
                if (updates.isEmpty)
                  _EmptyUpdatesCard(statusText.subtitle)
                else
                  ...updates.map((update) => _TimelineUpdateItem(update: update)).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int _statusToStep(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'quoted':
        return 1;
      case 'processing':
        return 2;
      case 'completed':
        return 3;
      case 'delivered':
        return 4;
      default:
        return 0;
    }
  }

  static _StatusText _statusHeadline(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const _StatusText('Ordered', 'We’re confirming your order');
      case 'quoted':
        return const _StatusText('Packed', 'Items are getting packed');
      case 'processing':
        return const _StatusText('In transit', 'Your order is on its way');
      case 'completed':
        return const _StatusText('Out for delivery', 'Courier is heading to you');
      case 'delivered':
        return const _StatusText('Delivered', 'Enjoy your new purchase!');
      default:
        return _StatusText(status, 'Status update');
    }
  }

  static List<_TimelineUpdate> _parseUpdates(dynamic updates) {
    if (updates is List) {
      return updates.map((entry) {
        if (entry is Map<String, dynamic>) {
          return _TimelineUpdate(
            title: entry['title'] as String? ?? 'Update',
            description: entry['description'] as String? ?? '',
            timestamp: _parseTimestamp(entry['timestamp']) ?? DateTime.now(),
          );
        }
        return null;
      }).whereType<_TimelineUpdate>().toList();
    }
    return [];
  }
}

class _EstimatedDeliveryCard extends StatelessWidget {
  final DateTime? date;

  const _EstimatedDeliveryCard({required this.date});

  @override
  Widget build(BuildContext context) {
    final formattedDay = date != null ? DateFormat.d().format(date!) : '--';
    final formattedMonth = date != null ? DateFormat.MMMM().format(date!) : 'TBD';
    final formattedYear = date != null ? DateFormat.y().format(date!) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF0FF), Color(0xFFDDE1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estimated delivery', style: AppTextStyles.bodyMedium(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedDay,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formattedMonth, style: AppTextStyles.heading3()),
                  if (formattedYear.isNotEmpty)
                    Text(formattedYear, style: AppTextStyles.caption(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  final int currentStep;

  const _StatusTracker({required this.currentStep});

  static const _steps = [
    {'label': 'Ordered', 'icon': Icons.receipt_long},
    {'label': 'Packed', 'icon': Icons.inventory_2_outlined},
    {'label': 'In transit', 'icon': Icons.local_shipping_outlined},
    {'label': 'Out for delivery', 'icon': Icons.local_shipping},
    {'label': 'Delivered', 'icon': Icons.home_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final step = _steps[index];
          final bool isCompleted = index <= currentStep;
          final bool isLast = index == _steps.length - 1;

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _StepNode(
                      icon: step['icon'] as IconData,
                      isCompleted: isCompleted,
                      isCurrent: index == currentStep,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 4,
                          color: isCompleted ? AppColors.primary : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  step['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                    color: isCompleted ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;

  const _StepNode({
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.primary : Colors.grey[200],
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrent ? Colors.white : Colors.transparent,
          width: 3,
        ),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        color: isCompleted ? Colors.white : Colors.grey[500],
      ),
    );
  }
}

class _TimelineUpdateItem extends StatelessWidget {
  final _TimelineUpdate update;

  const _TimelineUpdateItem({required this.update});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.title,
                  style: AppTextStyles.bodyMedium().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  update.description,
                  style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM d, yyyy • hh:mm a').format(update.timestamp),
                  style: AppTextStyles.caption(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyUpdatesCard extends StatelessWidget {
  final String statusText;

  const _EmptyUpdatesCard(this.statusText);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No updates yet', style: AppTextStyles.heading3()),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatusText {
  final String title;
  final String subtitle;

  const _StatusText(this.title, this.subtitle);
}

class _TimelineUpdate {
  final String title;
  final String description;
  final DateTime timestamp;

  _TimelineUpdate({
    required this.title,
    required this.description,
    required this.timestamp,
  });
}

