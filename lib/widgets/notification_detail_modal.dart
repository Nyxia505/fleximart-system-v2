import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Utility class for showing notification detail modals
class NotificationDetailModal {
  /// Get icon based on notification type
  static IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_order':
      case 'order_placed':
        return Icons.shopping_bag_outlined;
      case 'order_status_update':
      case 'order_shipped':
        return Icons.local_shipping_outlined;
      case 'order_processed':
        return Icons.inventory_2_outlined;
      case 'quotation_approved':
        return Icons.attach_money;
      case 'voucher':
      case 'new_voucher':
        return Icons.card_giftcard_outlined;
      case 'price_drop':
        return Icons.info_outline;
      case 'message':
      case 'support_message':
        return Icons.chat_bubble_outline;
      case 'flash_sale':
        return Icons.local_offer_outlined;
      case 'payment':
        return Icons.payment_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'delivery':
      case 'upcoming_delivery':
        return Icons.calendar_today_outlined;
      case 'order_paid':
        return Icons.payment;
      case 'order_received':
        return Icons.check_circle;
      case 'order_completed':
        return Icons.done_all;
      case 'new_quotation':
        return Icons.description;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Get icon color based on notification type
  static Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_order':
      case 'order_placed':
      case 'order_processed':
      case 'quotation_approved':
      case 'voucher':
      case 'new_voucher':
      case 'payment':
      case 'delivery':
      case 'upcoming_delivery':
      case 'new_quotation':
        return AppColors.primary; // Crimson Red
      case 'order_status_update':
      case 'order_shipped':
      case 'price_drop':
      case 'message':
      case 'support_message':
        return AppColors.berryRed; // Deep Berry Red
      case 'flash_sale':
        return AppColors.warning; // Orange
      case 'security':
        return AppColors.error; // Red
      case 'order_paid':
        return AppColors.info; // Blue
      case 'order_received':
      case 'order_completed':
        return AppColors.success; // Red
      default:
        return AppColors.primary; // Crimson Red
    }
  }

  /// Format timestamp for modal display (e.g., Nov 28, 2025, 09:32 AM)
  static String _formatTimestampForModal(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final formattedTime =
        '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}, $formattedTime';
  }

  /// Show notification detail modal
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required String type,
    Timestamp? createdAt,
    IconData? iconData,
    Color? iconColor,
  }) {
    final icon = iconData ?? _getNotificationIcon(type);
    final color = iconColor ?? _getNotificationColor(type);
    String timestampText = '';
    if (createdAt != null) {
      timestampText = _formatTimestampForModal(createdAt.toDate());
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // Dimmed background
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 500,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon, title, and close button
              Row(
                children: [
                  // Notification icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.heading3(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Close button (X)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Timestamp
              if (timestampText.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timestampText,
                      style: AppTextStyles.caption(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              // Divider
              Divider(
                color: AppColors.border,
                height: 1,
              ),
              const SizedBox(height: 16),
              // Message body
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textSecondary,
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
}

