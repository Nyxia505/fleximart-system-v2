import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'order_history_page.dart';
import '../pages/quotations_page.dart';
import '../pages/chat_list_page.dart';
import 'order_tracking_landing_page.dart';

/// Home Purchases UI Widget
/// 
/// Clean, modern Shopee-style layout for customer purchases section
class HomePurchasesUI extends StatelessWidget {
  const HomePurchasesUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'My Purchases',
                  style: AppTextStyles.heading2(),
                ),
              ),
            ],
          ),
        ),
        
        // Quick Actions Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: AppTextStyles.bodyMedium(
                  color: AppColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  _buildQuickAction(
                    context,
                    icon: Icons.local_shipping_outlined,
                    label: 'Track Orders',
                    actionColor: AppColors.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrderTrackingLandingPage(),
                        ),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.description_outlined,
                    label: 'My Quotations',
                    actionColor: AppColors.berryRed,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuotationsPage(),
                        ),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.history_outlined,
                    label: 'Order History',
                    actionColor: AppColors.darkWine,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrderHistoryPage(),
                        ),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    actionColor: AppColors.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatListPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? actionColor,
  }) {
    final color = actionColor ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), // Light tint background for the entire box
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2), // Slightly darker for contrast
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: color.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

