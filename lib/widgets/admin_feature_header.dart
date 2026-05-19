import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/dashboard_theme.dart';

/// Maroon gradient page header matching the Admin Dashboard overview.
class AdminFeatureHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final Widget? bottom;

  /// When true, header spans full content width flush to the sidebar (no gaps).
  final bool edgeToEdge;

  const AdminFeatureHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.trailing,
    this.bottom,
    this.edgeToEdge = true,
  });

  /// Standard padding for content below a flush header.
  static const EdgeInsets contentPadding = EdgeInsets.all(16);

  /// Primary action button styled for the gradient header (white pill).
  static Widget primaryAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool compact = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: compact ? 16 : 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 24,
            compact ? 16 : 20,
            compact ? 16 : 24,
            compact ? 14 : 18,
          ),
          decoration: BoxDecoration(
            gradient: DashboardTheme.headerGradient,
            borderRadius: edgeToEdge
                ? BorderRadius.zero
                : BorderRadius.circular(compact ? 16 : 24),
            boxShadow: edgeToEdge
                ? const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(compact ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: compact ? 26 : 32,
                    ),
                  ),
                  SizedBox(width: compact ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: compact ? 22 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: compact ? 13 : 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
              if (bottom != null) ...[
                SizedBox(height: compact ? 12 : 16),
                bottom!,
              ],
            ],
          ),
        );
      },
    );
  }
}
