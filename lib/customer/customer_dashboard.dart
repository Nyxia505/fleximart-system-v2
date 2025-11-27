import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shop_dashboard.dart';
import 'dashboard_notifications.dart';
import 'dashboard_profile.dart';
import '../constants/app_colors.dart';
import '../services/notification_service.dart';

class CustomerDashboard extends StatefulWidget {
  final int initialIndex;
  const CustomerDashboard({super.key, this.initialIndex = 0});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 2);
  }

  final List<Widget> _pages = const [
    ShopDashboard(),
    DashboardNotifications(),
    DashboardProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                key: ValueKey<int>(_currentIndex),
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: _pages[_currentIndex],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.shopping_bag_outlined, 'Shop', 0),
                _buildNavItem(Icons.notifications_outlined, 'Notification', 1),
                _buildNavItem(Icons.person_outline, 'Profile', 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final isNotification = icon == Icons.notifications_outlined;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.2) // Crimson Red highlight
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(
                          0.25,
                        ) // Crimson Red circle
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: isNotification
                    ? _buildNotificationIconWithBadge(isSelected)
                    : Icon(
                        icon,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: isSelected ? 22 : 20,
                      ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIconWithBadge(bool isSelected) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Icon(
        Icons.notifications_outlined,
        color: isSelected
            ? AppColors.primary
            : AppColors.textSecondary,
        size: isSelected ? 22 : 20,
      );
    }

    final notificationService = NotificationService.instance;

    return StreamBuilder<int>(
      stream: notificationService.getUnreadCount(user.uid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications_outlined,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: isSelected ? 22 : 20,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary, // Crimson Red badge
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99
                          ? '99+'
                          : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
