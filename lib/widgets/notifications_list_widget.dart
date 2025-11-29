import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Notifications List Widget
/// 
/// Displays a list of notifications using StreamBuilder
class NotificationsListWidget extends StatelessWidget {
  final String? userId;
  final bool showEmptyState;
  final Function(NotificationModel)? onNotificationTap;

  const NotificationsListWidget({
    super.key,
    this.userId,
    this.showEmptyState = true,
    this.onNotificationTap,
  });

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
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_order':
        return Icons.shopping_bag;
      case 'order_paid':
        return Icons.payment;
      case 'order_shipped':
        return Icons.local_shipping;
      case 'order_received':
        return Icons.check_circle;
      case 'order_completed':
        return Icons.done_all;
      case 'new_quotation':
        return Icons.description;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_order':
        return AppColors.primary;
      case 'order_paid':
        return AppColors.info;
      case 'order_shipped':
        return AppColors.info;
      case 'order_received':
        return AppColors.success;
      case 'order_completed':
        return AppColors.success;
      case 'new_quotation':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) {
      return Center(
        child: Text(
          'Please log in to view notifications',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
      );
    }

    final notificationService = NotificationService.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: notificationService.getNotificationsForUser(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading notifications',
                  style: AppTextStyles.heading3(color: AppColors.error),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (!showEmptyState) {
            return const SizedBox.shrink();
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: AppTextStyles.heading3(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ll see notifications here when you have updates',
                  style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data!.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final isUnread = !notification.read;

            return InkWell(
              onTap: () {
                if (!notification.read) {
                  notificationService.markAsRead(notification.id);
                }
                if (onNotificationTap != null) {
                  onNotificationTap!(notification);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isUnread
                      ? AppColors.primary.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnread
                        ? AppColors.primary.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getNotificationColor(notification.type)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getNotificationIcon(notification.type),
                        color: _getNotificationColor(notification.type),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title ?? 'Notification',
                                  style: AppTextStyles.bodyMedium().copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (notification.createdAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _formatTime(notification.createdAt!),
                              style: AppTextStyles.caption(
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Notification Badge Widget
/// 
/// Shows unread notification count
class NotificationBadge extends StatelessWidget {
  final String? userId;
  final Widget child;

  const NotificationBadge({
    super.key,
    this.userId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) {
      return child;
    }

    final notificationService = NotificationService.instance;

    return StreamBuilder<int>(
      stream: notificationService.getUnreadCount(currentUserId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        if (unreadCount == 0) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12, // Increased for clarity
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

