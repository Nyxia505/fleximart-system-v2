import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/notification_detail_modal.dart';

class DashboardNotifications extends StatefulWidget {
  const DashboardNotifications({super.key});

  @override
  State<DashboardNotifications> createState() => _DashboardNotificationsState();
}

class _DashboardNotificationsState extends State<DashboardNotifications> {
  final user = FirebaseAuth.instance.currentUser;
  int _refreshKey = 0; // Force StreamBuilder to refresh

  // Test function to verify notifications can be read
  Future<void> _testNotificationQuery() async {
    if (user == null) return;

    try {
      final userId = user!.uid;
      debugPrint('🔍 Testing notification query for user: $userId');
      debugPrint('🔍 Current user email: ${user!.email}');

      // First, try to create a test notification to verify permissions
      try {
        debugPrint('🧪 Creating test notification...');
        final testNotificationRef = await FirebaseFirestore.instance
            .collection('notifications')
            .add({
              'userId': userId,
              'type': 'test',
              'title': 'Test Notification',
              'message':
                  'This is a test notification to verify the system works',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
        debugPrint('✅ Test notification created: ${testNotificationRef.id}');

        // Wait a bit for Firestore to process
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('❌ Error creating test notification: $e');
      }

      // Try to read all notifications for this user
      debugPrint('🔍 Querying notifications...');
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .limit(10)
          .get();

      debugPrint('📊 Found ${snapshot.docs.length} notifications');

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No notifications found! Checking all notifications...');

        // Try to read ALL notifications (for debugging - will fail if no permission)
        try {
          final allSnapshot = await FirebaseFirestore.instance
              .collection('notifications')
              .limit(10)
              .get();
          debugPrint(
            '📊 Total notifications in database: ${allSnapshot.docs.length}',
          );
          for (var doc in allSnapshot.docs) {
            final data = doc.data();
            debugPrint(
              '   - Notification ${doc.id}: userId=${data['userId']}, title=${data['title']}',
            );
          }
        } catch (e) {
          debugPrint(
            '❌ Cannot read all notifications (expected if not admin): $e',
          );
        }
      } else {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          debugPrint('📋 Notification ID: ${doc.id}');
          debugPrint('   userId: ${data['userId']}');
          debugPrint('   title: ${data['title']}');
          debugPrint('   type: ${data['type']}');
          debugPrint('   read: ${data['read']}');
          debugPrint('   createdAt: ${data['createdAt']}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error testing notification query: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  @override
  void initState() {
    super.initState();
    // Test the query when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testNotificationQuery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with back arrow
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    "Notifications",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance the back button
              ],
            ),
          ),
          // Notifications List
          Expanded(
            child: user == null
                ? const Center(child: Text('Please login'))
                : StreamBuilder<QuerySnapshot>(
                    key: ValueKey(
                      _refreshKey,
                    ), // Force rebuild when key changes
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('userId', isEqualTo: user!.uid)
                        .snapshots(includeMetadataChanges: false),
                    builder: (context, snapshot) {
                      // Handle errors gracefully
                      if (snapshot.hasError) {
                        debugPrint(
                          '❌ Notification query error: ${snapshot.error}',
                        );
                        debugPrint('❌ User ID: ${user!.uid}');
                        debugPrint('❌ Error type: ${snapshot.error.runtimeType}');
                        
                        // Check if it's a permission error
                        final errorString = snapshot.error.toString().toLowerCase();
                        final isPermissionError = errorString.contains('permission') ||
                                                  errorString.contains('denied');
                        
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 64,
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isPermissionError
                                      ? 'Unable to load notifications'
                                      : 'No notifications available',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isPermissionError
                                      ? 'Please check your connection and try again'
                                      : "You'll see updates about your orders here",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _refreshKey++; // Force StreamBuilder refresh
                                    });
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Log query results for debugging
                      if (snapshot.hasData) {
                        debugPrint(
                          '📊 Notification query returned ${snapshot.data!.docs.length} notifications for user: ${user!.uid}',
                        );
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>?;
                          debugPrint(
                            '   - ${data?['title']} (userId: ${data?['userId']}, type: ${data?['type']}, status: ${data?['quotationStatus']})',
                          );
                        }
                      } else {
                        debugPrint('⚠️ No notification data in snapshot');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications_none,
                                  size: 64,
                                  color: AppColors.bubble1, // #A80038
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "No notifications yet",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "You'll see updates about your orders here",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _testNotificationQuery();
                                  if (mounted) {
                                    setState(() {
                                      _refreshKey++; // Force StreamBuilder refresh
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Check console for debug logs',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh & Test'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  if (user == null) return;
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('notifications')
                                        .add({
                                          'userId': user!.uid,
                                          'type': 'test',
                                          'title': 'Manual Test Notification',
                                          'message':
                                              'This is a manually created test notification',
                                          'read': false,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                    if (mounted) {
                                      setState(() {
                                        _refreshKey++; // Force StreamBuilder refresh
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Test notification created! Check if it appears.',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.add_alert),
                                label: const Text('Create Test Notification'),
                              ),
                            ],
                          ),
                        );
                      }

                      // Sort notifications by createdAt in descending order (newest first)
                      final notifications = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>?;
                          final bData = b.data() as Map<String, dynamic>?;
                          final aCreatedAt = aData?['createdAt'] as Timestamp?;
                          final bCreatedAt = bData?['createdAt'] as Timestamp?;
                          if (aCreatedAt == null && bCreatedAt == null)
                            return 0;
                          if (aCreatedAt == null) return 1;
                          if (bCreatedAt == null) return -1;
                          return bCreatedAt.compareTo(aCreatedAt);
                        });

                      // Group notifications by time period
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final yesterday = today.subtract(const Duration(days: 1));
                      final thisWeekStart = today.subtract(
                        Duration(days: now.weekday - 1),
                      );

                      final todayNotifications = <QueryDocumentSnapshot>[];
                      final yesterdayNotifications = <QueryDocumentSnapshot>[];
                      final thisWeekNotifications = <QueryDocumentSnapshot>[];
                      final earlierNotifications = <QueryDocumentSnapshot>[];

                      for (var notification in notifications) {
                        final data =
                            notification.data() as Map<String, dynamic>?;
                        final createdAt = data?['createdAt'] as Timestamp?;
                        if (createdAt == null) {
                          earlierNotifications.add(notification);
                          continue;
                        }

                        final notificationDate = createdAt.toDate();
                        final notificationDay = DateTime(
                          notificationDate.year,
                          notificationDate.month,
                          notificationDate.day,
                        );

                        if (notificationDay == today) {
                          todayNotifications.add(notification);
                        } else if (notificationDay == yesterday) {
                          yesterdayNotifications.add(notification);
                        } else if (notificationDate.isAfter(thisWeekStart)) {
                          thisWeekNotifications.add(notification);
                        } else {
                          earlierNotifications.add(notification);
                        }
                      }

                      return ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 16 + MediaQuery.of(context).padding.bottom,
                        ),
                        itemCount: _getTotalItemCount(
                          todayNotifications,
                          yesterdayNotifications,
                          thisWeekNotifications,
                          earlierNotifications,
                        ),
                        itemBuilder: (context, index) {
                          // Determine which section and item index
                          int currentIndex = 0;

                          // Today section
                          if (index == currentIndex &&
                              todayNotifications.isNotEmpty) {
                            return _buildSectionHeader('Today');
                          }
                          if (todayNotifications.isNotEmpty) {
                            currentIndex++;
                            if (index <
                                currentIndex + todayNotifications.length) {
                              return _buildNotificationItem(
                                context,
                                todayNotifications[index - currentIndex],
                                onSwipeToMarkRead: (docId) async {
                                  await FirebaseFirestore.instance
                                      .collection('notifications')
                                      .doc(docId)
                                      .update({'read': true});
                                },
                              );
                            }
                            currentIndex += todayNotifications.length;
                          }

                          // Yesterday section
                          if (index == currentIndex &&
                              yesterdayNotifications.isNotEmpty) {
                            return _buildSectionHeader('Yesterday');
                          }
                          if (yesterdayNotifications.isNotEmpty) {
                            currentIndex++;
                            if (index <
                                currentIndex + yesterdayNotifications.length) {
                              return _buildNotificationItem(
                                context,
                                yesterdayNotifications[index - currentIndex],
                                onSwipeToMarkRead: (docId) async {
                                  await FirebaseFirestore.instance
                                      .collection('notifications')
                                      .doc(docId)
                                      .update({'read': true});
                                },
                              );
                            }
                            currentIndex += yesterdayNotifications.length;
                          }

                          // This Week section
                          if (index == currentIndex &&
                              thisWeekNotifications.isNotEmpty) {
                            return _buildSectionHeader('This Week');
                          }
                          if (thisWeekNotifications.isNotEmpty) {
                            currentIndex++;
                            if (index <
                                currentIndex + thisWeekNotifications.length) {
                              return _buildNotificationItem(
                                context,
                                thisWeekNotifications[index - currentIndex],
                                onSwipeToMarkRead: (docId) async {
                                  await FirebaseFirestore.instance
                                      .collection('notifications')
                                      .doc(docId)
                                      .update({'read': true});
                                },
                              );
                            }
                            currentIndex += thisWeekNotifications.length;
                          }

                          // Earlier section (if needed)
                          if (index == currentIndex &&
                              earlierNotifications.isNotEmpty) {
                            return _buildSectionHeader('Earlier');
                          }
                          if (earlierNotifications.isNotEmpty) {
                            currentIndex++;
                            if (index <
                                currentIndex + earlierNotifications.length) {
                              return _buildNotificationItem(
                                context,
                                earlierNotifications[index - currentIndex],
                                onSwipeToMarkRead: (docId) async {
                                  await FirebaseFirestore.instance
                                      .collection('notifications')
                                      .doc(docId)
                                      .update({'read': true});
                                },
                              );
                            }
                          }

                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  int _getTotalItemCount(
    List<QueryDocumentSnapshot> today,
    List<QueryDocumentSnapshot> yesterday,
    List<QueryDocumentSnapshot> thisWeek,
    List<QueryDocumentSnapshot> earlier,
  ) {
    int count = 0;
    if (today.isNotEmpty) count += 1 + today.length; // header + items
    if (yesterday.isNotEmpty) count += 1 + yesterday.length;
    if (thisWeek.isNotEmpty) count += 1 + thisWeek.length;
    if (earlier.isNotEmpty) count += 1 + earlier.length;
    return count;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(title, style: AppTextStyles.heading3()),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    QueryDocumentSnapshot notificationDoc, {
    required Future<void> Function(String) onSwipeToMarkRead,
  }) {
    final notification = notificationDoc.data() as Map<String, dynamic>;
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final read = notification['read'] as bool? ?? false;
    final type = notification['type'] as String? ?? 'general';
    final createdAt = notification['createdAt'] as Timestamp?;

    // Get icon based on type
    IconData iconData;
    Color iconColor;
    switch (type) {
      case 'new_order':
      case 'order_placed':
        iconData = Icons.shopping_bag_outlined;
        iconColor = AppColors.primary; // Crimson Red
        break;
      case 'order_status_update':
      case 'order_shipped':
        iconData = Icons.local_shipping_outlined;
        iconColor = AppColors.berryRed; // Deep Berry Red
        break;
      case 'order_processed':
        iconData = Icons.inventory_2_outlined;
        iconColor = AppColors.primary; // Crimson Red
        break;
      case 'quotation_approved':
        iconData = Icons.attach_money;
        iconColor = AppColors.primary; // Crimson Red
        break;
      case 'voucher':
      case 'new_voucher':
        iconData = Icons.card_giftcard_outlined;
        iconColor = AppColors.primary; // Crimson Red
        break;
      case 'price_drop':
        iconData = Icons.info_outline;
        iconColor = AppColors.berryRed; // Deep Berry Red
        break;
      case 'message':
      case 'support_message':
        iconData = Icons.chat_bubble_outline;
        iconColor = AppColors.berryRed; // Deep Berry Red
        break;
      case 'flash_sale':
        iconData = Icons.local_offer_outlined;
        iconColor = AppColors.warning; // Keep orange for warnings
        break;
      case 'payment':
        iconData = Icons.payment_outlined;
        iconColor = AppColors.primary; // Crimson Red
        break;
      case 'security':
        iconData = Icons.security_outlined;
        iconColor = AppColors.error; // Keep red for errors
        break;
      case 'delivery':
      case 'upcoming_delivery':
        iconData = Icons.calendar_today_outlined;
        iconColor = AppColors.primary; // Crimson Red
        break;
      default:
        iconData = Icons.notifications_outlined;
        iconColor = AppColors.primary; // Crimson Red
    }

    // Format timestamp
    String timeText = '';
    if (createdAt != null) {
      final now = DateTime.now();
      final notificationTime = createdAt.toDate();
      final difference = now.difference(notificationTime);

      if (difference.inMinutes < 1) {
        timeText = 'Just now';
      } else if (difference.inMinutes < 60) {
        timeText =
            '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
      } else if (difference.inHours < 24) {
        timeText =
            '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inDays == 1) {
        timeText = 'Yesterday, ${_formatTime(notificationTime)}';
      } else if (difference.inDays < 7) {
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        timeText =
            'This Week, ${weekdays[notificationTime.weekday - 1]} ${_formatTime(notificationTime)}';
      } else {
        timeText = _formatDate(notificationTime);
      }
    }

    return Dismissible(
      key: Key(notificationDoc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) async {
        if (!read) {
          await onSwipeToMarkRead(notificationDoc.id);
        }
      },
      child: GestureDetector(
        onTap: () async {
          if (!read) {
            await FirebaseFirestore.instance
                .collection('notifications')
                .doc(notificationDoc.id)
                .update({'read': true});
          }
          // Show notification detail modal
          NotificationDetailModal.show(
            context,
            title: title,
            message: message,
            type: type,
            createdAt: createdAt,
            iconData: iconData,
            iconColor: iconColor,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: read ? AppColors.white : AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: read
                ? Border.all(color: AppColors.border, width: 1)
                : Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style:
                                AppTextStyles.bodyMedium(
                                  color: AppColors.textPrimary,
                                ).copyWith(
                                  fontWeight: read
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                          ),
                        ),
                        if (!read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 13),
                    ),
                    if (timeText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        timeText,
                        style: AppTextStyles.caption(color: AppColors.textHint),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDate(DateTime dateTime) {
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
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

}
