import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:typed_data';
import '../utils/fcm_utils.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../constants/app_colors.dart';
import '../utils/dashboard_theme.dart';
import '../pages/order_detail_page.dart';
import 'admin_quotation_screen.dart';
import '../pages/chat_list_page.dart';
import '../utils/price_formatter.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../utils/role_helper.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../widgets/profile_picture_placeholder.dart';
import '../widgets/map_coming_soon_placeholder.dart';
import '../widgets/customer_profile_avatar.dart';
import '../widgets/product_image_widget.dart';
import '../services/firebase_storage_service.dart';
import '../services/product_service.dart';
import '../services/activity_log_service.dart';
import 'activity_log_page.dart';

// Official theme colors - New Theme
class AdminThemeColors {
  AdminThemeColors._();
  static const Color crimsonRed = Color(0xFF8B2E2E);
  static const Color deepBerryRed = Color(0xFF6B1F1F);
  static const Color darkWinePurple = Color(0xFF4A1515);

  // Navigation colors
  static const Color navActive = Color(0xFF8B2E2E);
  static const Color navActiveBg = Color(
    0x42AF3E3E,
  ); // Secondary red with opacity
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;
  bool _isCheckingRole = true;
  String? _userRole;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    try {
      final role = await RoleHelper.getUserRole();

      if (role == null) {
        if (mounted) {
          setState(() {
            _isCheckingRole = false;
            _errorMessage =
                'Your account does not have assigned permissions. Please contact the system administrator.';
          });
        }
        return;
      }

      if (role != 'admin') {
        if (mounted) {
          setState(() {
            _isCheckingRole = false;
            _errorMessage =
                'Access denied. Admin dashboard requires admin role, but your role is: $role';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isCheckingRole = false;
          _userRole = role;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingRole = false;
          _errorMessage = 'Error checking permissions: $e';
        });
      }
    }
  }

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.dashboard_outlined, 'label': 'Dashboard'},
    {'icon': Icons.inventory_2_outlined, 'label': 'Products'},
    {'icon': Icons.receipt_long, 'label': 'Transactions'},
    {'icon': Icons.calendar_today, 'label': 'Sales Calendar'},
    {'icon': Icons.shopping_bag_outlined, 'label': 'Orders'},
    {'icon': Icons.description_outlined, 'label': 'Quotations'},
    {'icon': Icons.history, 'label': 'Activity Log'},
    {'icon': Icons.chat_bubble_outline, 'label': 'Messages'},
    {'icon': Icons.person_outline, 'label': 'Staff'},
    {'icon': Icons.feedback_outlined, 'label': 'Feedback'},
    {'icon': Icons.settings_outlined, 'label': 'Settings'},
  ];

  final List<Widget> _pages = [
    const _DashboardOverviewPage(),
    const _ProductsManagementPage(),
    const _PosPage(),
    const _SalesCalendarPage(),
    const _OrdersManagementPage(),
    const AdminQuotationScreen(),
    const _ActivityLogPage(),
    const _AdminMessagesPage(),
    const _StaffManagementPage(),
    const _FeedbackPage(),
    const _SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Check role before loading dashboard
    if (_isCheckingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show error if role is invalid
    if (_errorMessage != null || _userRole != 'admin') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ??
                      'Access denied. Admin dashboard requires admin role.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  child: const Text('Return to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Use a more stable breakpoint to prevent layout shifts when resizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile =
        screenWidth < 900; // Increased from 768 to prevent flickering
    final isWeb = !isMobile;

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      appBar: isMobile ? _buildMobileAppBar(context) : null,
      drawer: isMobile ? _buildMobileDrawer(context) : null,
      body: isWeb
          ? SafeArea(
              child: Row(
                children: [
                  _buildSidebar(context, isWeb),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
            )
          : _pages[_selectedIndex],
    );
  }

  PreferredSizeWidget? _buildMobileAppBar(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: DashboardTheme.headerGradient,
        ),
      ),
      elevation: 0,
      title: const Text(
        'Admin Dashboard',
        style: DashboardTheme.titleTextStyle,
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isWeb) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _sidebarCollapsed ? 80 : 260,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8B2E2E), // Primary color start
            Color(0xFF4A1515), // Secondary color end
          ],
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(4, 0),
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Enhanced Header with Title and Collapse Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_sidebarCollapsed)
                    Expanded(
                      child: Text(
                        'FlexiMart',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.95),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _sidebarCollapsed ? Icons.menu : Icons.menu_open,
                        color: Colors.white.withOpacity(0.9),
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () {
                        setState(() {
                          _sidebarCollapsed = !_sidebarCollapsed;
                        });
                      },
                      tooltip: _sidebarCollapsed ? 'Expand' : 'Collapse',
                    ),
                  ),
                ],
              ),
            ),
            // Navigation Items - Scrollable with Expanded
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Column(
                    children: List.generate(_navItems.length, (index) {
                      final item = _navItems[index];
                      final selected = _selectedIndex == index;
                      return _NavTile(
                        icon: item['icon'] as IconData,
                        label: item['label'] as String,
                        selected: selected,
                        collapsed: _sidebarCollapsed,
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          }
                        },
                      );
                    }),
                  ),
                ),
              ),
            ),
            // Profile Section - Pinned at bottom with proper spacing
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: _buildProfileSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots()
          : null,
      builder: (context, snapshot) {
        final userData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>?
            : null;
        final userName =
            (userData?['fullName'] as String?) ??
            (userData?['name'] as String?) ??
            (userData?['customerName'] as String?) ??
            user?.email?.split('@')[0] ??
            'Admin';
        final userEmail = user?.email ?? '';

        return Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: _sidebarCollapsed ? 18 : 24,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: _sidebarCollapsed ? 16 : 22,
                  backgroundColor: AdminThemeColors.crimsonRed,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: _sidebarCollapsed ? 16 : 20,
                    ),
                  ),
                ),
              ),
            ),
            if (!_sidebarCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.95),
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMobileProfileSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots()
          : null,
      builder: (context, snapshot) {
        final userData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>?
            : null;
        final userName =
            (userData?['fullName'] as String?) ??
            (userData?['name'] as String?) ??
            (userData?['customerName'] as String?) ??
            user?.email?.split('@')[0] ??
            'Admin';
        final userEmail = user?.email ?? '';

        return Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AdminThemeColors.crimsonRed,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget? _buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8B2E2E), // Primary color
              Color(0xFF4A1515), // Secondary color
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(4, 0),
              spreadRadius: 2,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Enhanced Header with Title and Close Button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'FlexiMart',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu_open, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation Items - Scrollable with Expanded
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    child: Column(
                      children: List.generate(_navItems.length, (index) {
                        final item = _navItems[index];
                        final selected = _selectedIndex == index;
                        return _NavTile(
                          icon: item['icon'] as IconData,
                          label: item['label'] as String,
                          selected: selected,
                          collapsed: false,
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _selectedIndex = index;
                              });
                              Navigator.pop(context);
                            }
                          },
                        );
                      }),
                    ),
                  ),
                ),
              ),
              // Profile Section - Pinned at bottom with proper spacing
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: _buildMobileProfileSection(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: widget.selected
              ? Colors.white.withOpacity(
                  0.2,
                ) // Brighter red background for active
              : _isHovered
              ? Colors.white.withOpacity(0.1) // Hover effect
              : Colors.white.withOpacity(
                  0.05,
                ), // Subtle background for inactive
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.selected
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: widget.selected ? 2 : 1,
          ),
          boxShadow: widget.selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.selected
                    ? Colors
                          .white // White for active
                    : Colors.white.withOpacity(
                        0.8,
                      ), // Lighter red/pink for inactive
                size: 22,
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.selected
                          ? Colors
                                .white // White text for active
                          : Colors.white.withOpacity(
                              0.85,
                            ), // Lighter red/pink for inactive
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 14,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== DASHBOARD OVERVIEW PAGE ====================
class _DashboardOverviewPage extends StatelessWidget {
  const _DashboardOverviewPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header with Gradient - Matching Staff Design
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AdminThemeColors.crimsonRed,
                      AdminThemeColors.deepBerryRed,
                      AdminThemeColors.darkWinePurple,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: isCompact ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors
                                  .white, // White text for better contrast
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quick stats and pending tasks',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(
                                0.9,
                              ), // White text for better contrast
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Enhanced KPI Cards with Customer & Staff connections
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .snapshots()
                .handleError((error) {
                  debugPrint('⚠️ Error loading orders: $error');
                  return FirebaseFirestore.instance
                      .collection('orders')
                      .snapshots();
                }),
            builder: (context, ordersSnapshot) {
              // Handle errors gracefully - continue with empty data
              if (ordersSnapshot.hasError) {
                debugPrint('Error loading orders: ${ordersSnapshot.error}');
              }

              // Get orders data (or empty list if not available)
              final orders = ordersSnapshot.hasData
                  ? ordersSnapshot.data!.docs
                  : <QueryDocumentSnapshot>[];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots()
                    .handleError((error) {
                      debugPrint('⚠️ Error loading products: $error');
                      return FirebaseFirestore.instance
                          .collection('products')
                          .snapshots();
                    }),
                builder: (context, productsSnapshot) {
                  if (productsSnapshot.hasError) {
                    debugPrint(
                      'Error loading products: ${productsSnapshot.error}',
                    );
                  }

                  // Get products data (or empty list if not available)
                  final products = productsSnapshot.hasData
                      ? productsSnapshot.data!.docs
                      : <QueryDocumentSnapshot>[];

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots() // Load all users first, filter in memory
                        .handleError((error) {
                          debugPrint('⚠️ Error loading users: $error');
                          return FirebaseFirestore.instance
                              .collection('users')
                              .snapshots();
                        }),
                    builder: (context, usersSnapshot) {
                      if (usersSnapshot.hasError) {
                        debugPrint(
                          'Error loading users: ${usersSnapshot.error}',
                        );
                      }

                      // Get all users and filter by role in memory
                      final allUsers = usersSnapshot.hasData
                          ? usersSnapshot.data!.docs
                          : <QueryDocumentSnapshot>[];

                      // Filter customers and staff in memory
                      final customers = allUsers.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final role = (data['role'] as String?) ?? '';
                        return role.toLowerCase() == 'customer';
                      }).toList();

                      final staff = allUsers.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final role = (data['role'] as String?) ?? '';
                        return role.toLowerCase() == 'staff';
                      }).toList();

                      // Initialize variables
                      double totalRevenue = 0;
                      double paidRevenue = 0;
                      int totalSales = 0;
                      int pendingOrders = 0;
                      int processingOrders = 0;
                      double avgOrderValue = 0;
                      double inventoryValue = 0;
                      int totalCustomers = 0;
                      int totalStaff = 0;
                      int activeStaff = 0;

                      // Filter out quotations from orders
                      final actualOrders = orders.where((order) {
                        final data = order.data() as Map<String, dynamic>;
                        final isQuotation =
                            data['isQuotation'] as bool? ?? false;
                        return !isQuotation;
                      }).toList();

                      // Process orders

                      if (actualOrders.isNotEmpty) {
                        totalSales = actualOrders.length;
                        for (var order in actualOrders) {
                          final data = order.data() as Map<String, dynamic>;
                          // Read totalPrice with null safety: default to 0 if missing
                          final items = (data['items'] as List?) ?? [];
                          double price = _parsePrice(data['totalPrice']);

                          // If totalPrice is 0 or missing, compute from items as fallback
                          if (price == 0.0 && items.isNotEmpty) {
                            for (var item in items) {
                              if (item is Map<String, dynamic>) {
                                final itemPrice = _parsePrice(item['price']);
                                final quantity = _parseInt(
                                  item['quantity'],
                                  defaultValue: 1,
                                );
                                price += itemPrice * quantity;
                              }
                            }
                          }

                          final total = price;
                          totalRevenue += total;

                          final paymentStatus =
                              data['paymentStatus'] as String? ?? 'unpaid';
                          if (paymentStatus == 'paid') {
                            paidRevenue += total;
                          }

                          final status =
                              (data['status'] as String?) ?? 'pending';
                          if (status == 'pending') pendingOrders++;
                          if (status == 'processing') processingOrders++;
                        }
                        avgOrderValue = totalSales > 0
                            ? totalRevenue / totalSales
                            : 0;
                      }

                      // Process products - calculate inventory value from real product data
                      // Formula: inventoryValue = sum of (price × stock) for all products
                      if (products.isNotEmpty) {
                        int validProductsCount = 0;
                        int skippedProductsCount = 0;

                        for (var product in products) {
                          final data = product.data() as Map<String, dynamic>;
                          // Handle price as String or num
                          double price = _parsePrice(data['price']);
                          final stock = (data['stock'] as num?)?.toInt() ?? 0;

                          // Only count products with valid, reasonable values
                          // Filter out invalid data (negative, zero, or unreasonably high values)
                          if (price > 0 &&
                              stock > 0 &&
                              price <= 1000000 && // Max price: 1M per unit
                              stock <= 100000) {
                            // Max stock: 100K units
                            inventoryValue += price * stock;
                            validProductsCount++;
                          } else {
                            skippedProductsCount++;
                            if (kDebugMode &&
                                (price > 1000000 || stock > 100000)) {
                              debugPrint(
                                '⚠️ Skipped product ${product.id}: price=$price, stock=$stock (values too high)',
                              );
                            }
                          }
                        }

                        if (kDebugMode) {
                          debugPrint(
                            '📊 Inventory calculation: $validProductsCount valid products, '
                            '$skippedProductsCount skipped, total value: ₱${inventoryValue.toStringAsFixed(2)}',
                          );
                        }
                      }

                      // Process customers
                      totalCustomers = customers.length;

                      // Process staff
                      totalStaff = staff.length;
                      // Count active staff (those assigned to actual orders, not quotations)
                      final assignedStaffIds = <String>{};
                      if (actualOrders.isNotEmpty) {
                        for (var order in actualOrders) {
                          final data = order.data() as Map<String, dynamic>;
                          final assignedId = data['assignedStaffId'] as String?;
                          if (assignedId != null) {
                            assignedStaffIds.add(assignedId);
                          }
                        }
                      }
                      activeStaff = assignedStaffIds.length;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 1200;
                          final isMedium = constraints.maxWidth > 800;
                          final cardWidth = isWide
                              ? (constraints.maxWidth - 64) / 4
                              : isMedium
                              ? (constraints.maxWidth - 48) / 2
                              : constraints.maxWidth - 32;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _EnhancedKpiCard(
                                title: 'Total Revenue',
                                value: '₱${_formatNumber(totalRevenue)}',
                                subtitle: '₱${_formatNumber(paidRevenue)} paid',
                                icon: Icons.currency_exchange,
                                color: AdminThemeColors.darkWinePurple,
                                width: cardWidth,
                                trend: null,
                              ),
                              _EnhancedKpiCard(
                                title: 'Total Orders',
                                value: totalSales.toString(),
                                subtitle:
                                    '$pendingOrders pending, $processingOrders processing',
                                icon: Icons.shopping_cart_outlined,
                                color: AdminThemeColors.crimsonRed,
                                width: cardWidth,
                                trend: null,
                              ),
                              _EnhancedKpiCard(
                                title: 'Customers',
                                value: totalCustomers.toString(),
                                subtitle: 'Total registered customers',
                                icon: Icons.people_outline,
                                color: AdminThemeColors.deepBerryRed,
                                width: cardWidth,
                                trend: null,
                              ),
                              _EnhancedKpiCard(
                                title: 'Staff',
                                value: '$activeStaff/$totalStaff',
                                subtitle: 'Active staff members',
                                icon: Icons.person_outline,
                                color: AdminThemeColors.darkWinePurple,
                                width: cardWidth,
                                trend: null,
                              ),
                              _EnhancedKpiCard(
                                title: 'Avg. Order Value',
                                value: '₱${_formatNumber(avgOrderValue)}',
                                subtitle: 'Average per order',
                                icon: Icons.analytics_outlined,
                                color: AdminThemeColors.crimsonRed,
                                width: cardWidth,
                                trend: null,
                              ),
                              _EnhancedKpiCard(
                                title: 'Inventory Value',
                                value: '₱${_formatNumber(inventoryValue)}',
                                subtitle: 'Total stock value',
                                icon: Icons.inventory_2_outlined,
                                width: cardWidth,
                                color: AdminThemeColors.deepBerryRed,
                                trend: null,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          // Enhanced Charts Section
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1200;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _EnhancedPanel(
                    width: isWide
                        ? (constraints.maxWidth - 64) / 2
                        : constraints.maxWidth - 32,
                    title: 'Recent Orders',
                    icon: Icons.receipt_long,
                    color: AdminThemeColors.crimsonRed,
                    child: const _RecentOrdersTable(),
                  ),
                  _EnhancedPanel(
                    width: isWide
                        ? (constraints.maxWidth - 64) / 2
                        : constraints.maxWidth - 32,
                    title: 'Low Stock Alerts',
                    icon: Icons.warning_amber_rounded,
                    color: AdminThemeColors.deepBerryRed,
                    child: const _LowStockList(),
                  ),
                  _EnhancedPanel(
                    width: isWide
                        ? (constraints.maxWidth - 64) / 2
                        : constraints.maxWidth - 32,
                    title: 'Top Customers',
                    icon: Icons.star_outline,
                    color: AdminThemeColors.darkWinePurple,
                    child: const _TopCustomersList(),
                  ),
                  _EnhancedPanel(
                    width: isWide
                        ? (constraints.maxWidth - 64) / 2
                        : constraints.maxWidth - 32,
                    title: 'Staff Performance',
                    icon: Icons.work_outline,
                    color: AdminThemeColors.crimsonRed,
                    child: const _StaffPerformanceList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  /// Safely parse price value from Firestore (handles both String and num)
  static double _parsePrice(dynamic priceValue) {
    if (priceValue == null) return 0.0;
    if (priceValue is num) {
      return priceValue.toDouble();
    }
    if (priceValue is String) {
      // Remove currency symbols, spaces, and parse
      final cleanPrice = priceValue.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleanPrice) ?? 0.0;
    }
    return 0.0;
  }

  /// Safely parse integer value from Firestore (handles both String and num)
  static int _parseInt(dynamic intValue, {int defaultValue = 0}) {
    if (intValue == null) return defaultValue;
    if (intValue is num) {
      return intValue.toInt();
    }
    if (intValue is String) {
      return int.tryParse(intValue) ?? defaultValue;
    }
    return defaultValue;
  }
}

class _EnhancedKpiCard extends StatelessWidget {
  const _EnhancedKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.width,
    this.trend,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double width;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), // Light tint of the card's color
          borderRadius: BorderRadius.circular(20), // 20px rounded corners
          border: Border.all(
            color: color.withOpacity(0.4), // Border matching the card's color
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1), // Light bubble background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: color, size: 28),
                ),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trend!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14, // Increased for clarity
                color: Color(0xFF1D3B53), // Dark blue for better readability
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B2E2E), // Card value color (primary)
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13, // Increased for clarity
                color: const Color(
                  0xFF1D3B53,
                ).withOpacity(0.9), // Darker for better readability
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2, // Added for clarity
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EnhancedPanel extends StatelessWidget {
  const _EnhancedPanel({
    required this.title,
    required this.child,
    required this.width,
    required this.icon,
    this.color,
  });

  final String title;
  final Widget child;
  final double width;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final panelColor = color ?? AdminThemeColors.darkWinePurple;
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: panelColor.withOpacity(0.1), // Light tint of the panel's color
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: panelColor.withOpacity(
              0.4,
            ), // Border matching the panel's color
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: panelColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: panelColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: panelColor, // Icon color matching panel
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121), // Dark text
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(height: 240, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrdersTable extends StatelessWidget {
  const _RecentOrdersTable();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots()
          .handleError((error) {
            debugPrint('⚠️ OrderBy failed for recent orders: $error');
            // Fallback: return all orders without orderBy
            return FirebaseFirestore.instance
                .collection('orders')
                .limit(5)
                .snapshots();
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Error loading recent orders: ${snapshot.error}');
          // Try without orderBy if index is missing
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .snapshots()
                .handleError((error) {
                  debugPrint('⚠️ Fallback query also failed: $error');
                  return FirebaseFirestore.instance
                      .collection('orders')
                      .snapshots();
                }),
            builder: (context, fallbackSnapshot) {
              if (fallbackSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!fallbackSnapshot.hasData ||
                  fallbackSnapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }
              // Sort manually
              final orders = fallbackSnapshot.data!.docs;
              orders.sort((a, b) {
                final aTime =
                    (a.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                final bTime =
                    (b.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });
              return _buildOrdersTable(orders.take(5).toList());
            },
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final orders = snapshot.data!.docs;
        return _buildOrdersTable(orders);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            'No orders yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable(List<QueryDocumentSnapshot> orders) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              const Color(0xFFF5F5F5), // Light gray background for headers
            ),
            headingRowHeight: 48,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            columnSpacing: 24,
            columns: const [
              DataColumn(
                label: Text(
                  'Date',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Increased for clarity
                    color: Color(
                      0xFF1D3B53,
                    ), // Dark blue for better readability
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Customer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Increased for clarity
                    color: Color(
                      0xFF1D3B53,
                    ), // Dark blue for better readability
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Increased for clarity
                    color: Color(
                      0xFF1D3B53,
                    ), // Dark blue for better readability
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Increased for clarity
                    color: Color(
                      0xFF1D3B53,
                    ), // Dark blue for better readability
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Increased for clarity
                    color: Color(
                      0xFF1D3B53,
                    ), // Dark blue for better readability
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
            rows: orders.map((orderDoc) {
              final order = orderDoc.data() as Map<String, dynamic>;
              final createdAt = order['createdAt'] as Timestamp?;
              final date = createdAt != null
                  ? '${createdAt.toDate().month}/${createdAt.toDate().day}/${createdAt.toDate().year}'
                  : 'N/A';
              final items = order['items'] as List<dynamic>? ?? [];
              final itemCount = items.length;
              // Read totalPrice with null safety: default to 0 if missing
              double price = _DashboardOverviewPage._parsePrice(
                order['totalPrice'],
              );

              // If totalPrice is 0 or missing, compute from items as fallback
              if (price == 0.0 && items.isNotEmpty) {
                for (var item in items) {
                  if (item is Map<String, dynamic>) {
                    final itemPrice = _DashboardOverviewPage._parsePrice(
                      item['price'],
                    );
                    final quantity = _DashboardOverviewPage._parseInt(
                      item['quantity'],
                      defaultValue: 1,
                    );
                    price += itemPrice * quantity;
                  }
                }
              }

              final total = price;
              final status = (order['status'] as String?) ?? 'pending';
              final customerName =
                  (order['customerName'] as String?) ?? 'Unknown';

              Color statusColor = const Color(0xFF757575);
              switch (status.toLowerCase()) {
                case 'completed':
                  statusColor = const Color(0xFF2E7D32); // Green
                  break;
                case 'pending':
                  statusColor = const Color(0xFFF59E0B); // Orange
                  break;
                case 'shipped':
                  statusColor = const Color(0xFF2196F3); // Blue
                  break;
                case 'processing':
                  statusColor = const Color(0xFF6366F1); // Indigo
                  break;
              }

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 14, // Increased for clarity
                        color: Color(
                          0xFF1D3B53,
                        ), // Dark blue for better readability
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  DataCell(
                    FutureBuilder<DocumentSnapshot>(
                      future: (order['customerId'] as String?) != null
                          ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(order['customerId'] as String)
                                .get()
                          : null,
                      builder: (context, snapshot) {
                        String displayName =
                            customerName; // Fallback to order customerName
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          displayName =
                              (userData?['fullName'] as String?) ??
                              (userData?['name'] as String?) ??
                              (userData?['customerName'] as String?) ??
                              customerName;
                        }
                        return Text(
                          displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14, // Increased for clarity
                            color: Color(
                              0xFF1D3B53,
                            ), // Dark blue for better readability
                            letterSpacing: 0.1,
                          ),
                        );
                      },
                    ),
                  ),
                  DataCell(
                    Text(
                      itemCount.toString(),
                      style: const TextStyle(
                        fontSize: 14, // Increased for clarity
                        color: Color(
                          0xFF1D3B53,
                        ), // Dark blue for better readability
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      PriceFormatter.formatPrice(total),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _LowStockList extends StatelessWidget {
  const _LowStockList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: const Color(0xFF2E7D32), // Green checkmark
                ),
                const SizedBox(height: 12),
                Text(
                  'All products well stocked',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          );
        }

        final products = snapshot.data!.docs;
        final lowStockItems = <Map<String, dynamic>>[];

        for (var productDoc in products) {
          final product = productDoc.data() as Map<String, dynamic>;
          final stock = (product['stock'] as num?)?.toInt() ?? 0;
          final minStock = (product['minStock'] as num?)?.toInt() ?? 10;

          if (stock < minStock) {
            lowStockItems.add({
              'id': productDoc.id,
              'name':
                  (product['name'] as String?) ??
                  (product['title'] as String?) ??
                  'Unknown',
              'stock': stock,
              'min': minStock,
            });
          }
        }

        if (lowStockItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: const Color(0xFF2E7D32), // Green checkmark
                ),
                const SizedBox(height: 12),
                Text(
                  'All products well stocked',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: lowStockItems.length > 5 ? 5 : lowStockItems.length,
          itemBuilder: (context, index) {
            final item = lowStockItems[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.error.withOpacity(0.1),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                ),
              ),
              title: Text(
                item['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Stock: ${item['stock']} (Min: ${item['min']})'),
              trailing: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Restock functionality for ${item['name']}',
                      ),
                    ),
                  );
                },
                child: const Text('Restock'),
              ),
            );
          },
        );
      },
    );
  }
}

class _TopCustomersList extends StatelessWidget {
  const _TopCustomersList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, ordersSnapshot) {
        if (ordersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!ordersSnapshot.hasData || ordersSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No customer data yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        // Calculate customer spending - aggregate by customerId
        final Map<String, double> customerSpending = {};
        final Map<String, int> customerOrderCount = {};
        final Map<String, String> customerNames = {};
        final Set<String> customerIds = {};

        for (var orderDoc in ordersSnapshot.data!.docs) {
          final order = orderDoc.data() as Map<String, dynamic>;
          // Use customerId (the correct field name in orders collection)
          final customerId = order['customerId'] as String?;

          if (customerId == null || customerId.isEmpty) {
            continue; // Skip orders without customerId
          }

          // Get customer name from order (fallback to customerName field)
          final customerName =
              order['customerName'] as String? ??
              order['name'] as String? ??
              'Unknown Customer';

          // Read totalPrice with null safety: default to 0 if missing
          final items = (order['items'] as List?) ?? [];
          double price = _DashboardOverviewPage._parsePrice(
            order['totalPrice'],
          );

          // If totalPrice is 0 or missing, compute from items as fallback
          if (price == 0.0 && items.isNotEmpty) {
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final itemPrice = _DashboardOverviewPage._parsePrice(
                  item['price'],
                );
                final quantity = _DashboardOverviewPage._parseInt(
                  item['quantity'],
                  defaultValue: 1,
                );
                price += itemPrice * quantity;
              }
            }
          }

          final total = price;

          // Aggregate spending and order count by customerId
          customerSpending[customerId] =
              (customerSpending[customerId] ?? 0.0) + total;
          customerOrderCount[customerId] =
              (customerOrderCount[customerId] ?? 0) + 1;
          customerNames[customerId] = customerName;
          customerIds.add(customerId);
        }

        // Fetch customer names from users collection for better accuracy
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchCustomerNames(customerIds),
          builder: (context, customerNamesSnapshot) {
            // Update customer names if available from users collection
            if (customerNamesSnapshot.hasData) {
              for (var customerData in customerNamesSnapshot.data!) {
                final customerId = customerData['id'] as String;
                final name = customerData['name'] as String?;
                if (name != null && name.isNotEmpty) {
                  customerNames[customerId] = name;
                }
              }
            }

            // Sort by spending (highest first)
            final sortedCustomers = customerSpending.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            final topCustomers = sortedCustomers.take(5).toList();

            if (topCustomers.isEmpty) {
              return Center(
                child: Text(
                  'No customer data',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: topCustomers.length,
              itemBuilder: (context, index) {
                final entry = topCustomers[index];
                final customerId = entry.key;
                final totalSpent = entry.value;
                final orderCount = customerOrderCount[customerId] ?? 0;
                final name = customerNames[customerId] ?? 'Unknown Customer';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        color: const Color(0xFF2E7D32),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF212121),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$orderCount order${orderCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          PriceFormatter.formatPrice(totalSpent),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF212121),
                          ),
                        ),
                        if (index == 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TOP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
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
      },
    );
  }

  /// Fetch customer names from users collection
  Future<List<Map<String, dynamic>>> _fetchCustomerNames(
    Set<String> customerIds,
  ) async {
    if (customerIds.isEmpty) return [];

    try {
      final List<Map<String, dynamic>> customerData = [];

      // Fetch customer data in batches (Firestore 'in' query limit is 10)
      final customerIdsList = customerIds.toList();
      for (int i = 0; i < customerIdsList.length; i += 10) {
        final batch = customerIdsList.skip(i).take(10).toList();
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          // Prioritize fullName first (matches customer profile), then name, then customerName
          final name =
              data['fullName'] as String? ??
              data['name'] as String? ??
              data['customerName'] as String?;
          if (name != null && name.isNotEmpty) {
            customerData.add({'id': doc.id, 'name': name});
          }
        }
      }

      return customerData;
    } catch (e) {
      debugPrint('Error fetching customer names: $e');
      return [];
    }
  }
}

class _StaffPerformanceList extends StatelessWidget {
  const _StaffPerformanceList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, ordersSnapshot) {
        if (ordersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .snapshots() // Load all users, filter in memory
              .handleError((error) {
                debugPrint('⚠️ Error loading users: $error');
                return FirebaseFirestore.instance
                    .collection('users')
                    .snapshots();
              }),
          builder: (context, allUsersSnapshot) {
            if (allUsersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Filter staff in memory
            final staffMembers =
                (allUsersSnapshot.hasData
                        ? allUsersSnapshot.data!.docs
                        : <QueryDocumentSnapshot>[])
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final role = (data['role'] as String?) ?? '';
                      return role.toLowerCase() == 'staff';
                    })
                    .toList();

            if (staffMembers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No staff members',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            // Calculate staff performance
            final Map<String, int> staffOrderCount = {};
            final Map<String, double> staffRevenue = {};

            // Use orders from ordersSnapshot
            if (ordersSnapshot.hasData &&
                ordersSnapshot.data!.docs.isNotEmpty) {
              for (var orderDoc in ordersSnapshot.data!.docs) {
                final order = orderDoc.data() as Map<String, dynamic>;
                final assignedStaffId = order['assignedStaffId'] as String?;
                // Get totalPrice from Firestore, or compute from items if missing
                final totalPriceValue = order['totalPrice'];
                double? totalPrice;
                if (totalPriceValue is num) {
                  totalPrice = totalPriceValue.toDouble();
                } else if (totalPriceValue is String) {
                  totalPrice = double.tryParse(totalPriceValue);
                }

                // Compute from items if totalPrice doesn't exist
                double computedTotal = 0.0;
                if (totalPrice == null) {
                  final items = (order['items'] as List?) ?? [];
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
                }

                final total = totalPrice ?? computedTotal;

                if (assignedStaffId != null) {
                  staffOrderCount[assignedStaffId] =
                      (staffOrderCount[assignedStaffId] ?? 0) + 1;
                  staffRevenue[assignedStaffId] =
                      (staffRevenue[assignedStaffId] ?? 0.0) + total;
                }
              }
            }

            // staffMembers is already defined above from filtering allUsers
            final staffPerformance = <Map<String, dynamic>>[];

            for (var staffDoc in staffMembers) {
              final staffData = staffDoc.data() as Map<String, dynamic>;
              final staffId = staffDoc.id;
              final staffName =
                  (staffData['name'] as String?) ??
                  (staffData['customerName'] as String?) ??
                  staffData['email'] ??
                  'Staff';
              final orderCount = staffOrderCount[staffId] ?? 0;
              final revenue = staffRevenue[staffId] ?? 0.0;

              staffPerformance.add({
                'id': staffId,
                'name': staffName,
                'orders': orderCount,
                'revenue': revenue,
              });
            }

            // Sort by order count
            staffPerformance.sort((a, b) => b['orders'].compareTo(a['orders']));
            final topStaff = staffPerformance.take(5).toList();

            if (topStaff.isEmpty) {
              return Center(
                child: Text(
                  'No staff assignments yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: topStaff.length,
              itemBuilder: (context, index) {
                final staff = topStaff[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                      child: Icon(
                        Icons.work,
                        color: const Color(0xFF2E7D32),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      staff['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF212121),
                      ),
                    ),
                    subtitle: Text(
                      '${staff['orders']} order${staff['orders'] != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          PriceFormatter.formatPrice(
                            (staff['revenue'] as double),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF212121),
                          ),
                        ),
                        if (index == 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3), // Light blue
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BEST',
                              style: TextStyle(
                                fontSize: 12, // Increased for clarity
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
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
      },
    );
  }
}

// ==================== PLACEHOLDER PAGES ====================
class _ProductsManagementPage extends StatefulWidget {
  const _ProductsManagementPage();

  @override
  State<_ProductsManagementPage> createState() =>
      _ProductsManagementPageState();
}

class _ProductsManagementPageState extends State<_ProductsManagementPage> {
  String _filterCategory = 'all';
  String _filterStock = 'all'; // all, low, normal, out
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search to avoid excessive filtering
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  /// Get Firestore products stream with category and stock filters applied
  /// Note: Search filtering is done client-side due to Firestore limitations
  /// for case-insensitive partial matching
  Stream<QuerySnapshot> _getProductsStream() {
    Query query = FirebaseFirestore.instance.collection('products');

    // Apply category filter via Firestore query
    if (_filterCategory != 'all') {
      query = query.where('category', isEqualTo: _filterCategory);
    }

    // Apply stock filter via Firestore query
    if (_filterStock == 'low') {
      // Low Stock: stock <= 30
      query = query.where('stock', isLessThanOrEqualTo: 30);
    } else if (_filterStock == 'out') {
      // Out of Stock: stock <= 0
      query = query.where('stock', isLessThanOrEqualTo: 0);
    } else if (_filterStock == 'normal') {
      // Normal Stock: stock > 30
      query = query.where('stock', isGreaterThan: 30);
    }
    // If _filterStock == 'all', no stock filter is applied

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: Column(
        children: [
          // Header - Responsive
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              return Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(
                        0xFFCD5656,
                      ).withOpacity(0.3), // Red border matching theme
                      width: 2,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory Management',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (!isMobile) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Track materials needing restocking',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isMobile)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseAuth.instance.currentUser != null
                                ? FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(
                                        FirebaseAuth.instance.currentUser!.uid,
                                      )
                                      .snapshots()
                                : null,
                            builder: (context, snapshot) {
                              final userRole =
                                  (snapshot.data?.data()
                                          as Map<String, dynamic>?)?['role']
                                      as String?;
                              final isAdmin = userRole == 'admin';

                              if (!isAdmin) return const SizedBox.shrink();

                              return ElevatedButton.icon(
                                onPressed: () => _showAddProductDialog(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    if (isMobile) ...[
                      const SizedBox(height: 12),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseAuth.instance.currentUser != null
                            ? FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(FirebaseAuth.instance.currentUser!.uid)
                                  .snapshots()
                            : null,
                        builder: (context, snapshot) {
                          final userRole =
                              (snapshot.data?.data()
                                      as Map<String, dynamic>?)?['role']
                                  as String?;
                          final isAdmin = userRole == 'admin';

                          if (!isAdmin) return const SizedBox.shrink();

                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddProductDialog(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Product'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search products by name, category, or code...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filters - Responsive
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterCategory,
                                  isDense: true,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All Categories'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Doors',
                                      child: Text('Doors'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Windows',
                                      child: Text('Windows'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterCategory = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterStock,
                                  isDense: true,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All Stock'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text('Low Stock'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'out',
                                      child: Text('Out of Stock'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'normal',
                                      child: Text('Normal Stock'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterStock = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterCategory,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All Categories'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Doors',
                                      child: Text('Doors'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Windows',
                                      child: Text('Windows'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterCategory = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterStock,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All Stock'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text('Low Stock'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'out',
                                      child: Text('Out of Stock'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'normal',
                                      child: Text('Normal Stock'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterStock = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              );
            },
          ),
          // Products List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getProductsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseAuth.instance.currentUser != null
                              ? FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .snapshots()
                              : null,
                          builder: (context, snapshot) {
                            final userRole =
                                (snapshot.data?.data()
                                        as Map<String, dynamic>?)?['role']
                                    as String?;
                            final isAdmin = userRole == 'admin';

                            if (!isAdmin) return const SizedBox.shrink();

                            return ElevatedButton(
                              onPressed: () => _showAddProductDialog(context),
                              child: const Text('Add First Product'),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }

                // Products are filtered by Firestore query (category + stock)
                // Search filtering is done client-side for case-insensitive partial matching
                var filteredProducts = snapshot.data!.docs;

                // Apply search filter (case-insensitive partial match)
                if (_searchQuery.isNotEmpty) {
                  final searchLower = _searchQuery.toLowerCase().trim();
                  filteredProducts = filteredProducts.where((doc) {
                    final product = doc.data() as Map<String, dynamic>;

                    // Search in name
                    final name = (product['name'] as String? ?? '')
                        .toLowerCase();
                    if (name.contains(searchLower)) return true;

                    // Search in category
                    final category = (product['category'] as String? ?? '')
                        .toLowerCase();
                    if (category.contains(searchLower)) return true;

                    // Search in productCode (if exists)
                    final productCode =
                        (product['productCode'] as String? ??
                                product['code'] as String? ??
                                '')
                            .toLowerCase();
                    if (productCode.contains(searchLower)) return true;

                    return false;
                  }).toList();
                }

                final isMobile = MediaQuery.of(context).size.width < 768;
                final isTablet =
                    MediaQuery.of(context).size.width < 1024 && !isMobile;

                if (isMobile) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final productDoc = filteredProducts[index];
                      final product = productDoc.data() as Map<String, dynamic>;
                      return _buildProductCard(
                        context,
                        productDoc.id,
                        product,
                        isMobile: true,
                      );
                    },
                  );
                }

                // Web/Tablet Grid Layout - Matching staff design
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 2 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85, // Matching staff design
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final productDoc = filteredProducts[index];
                    final product = productDoc.data() as Map<String, dynamic>;
                    return _buildProductCard(
                      context,
                      productDoc.id,
                      product,
                      isMobile: false,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    String productId,
    Map<String, dynamic> product, {
    bool isMobile = false,
  }) {
    // Use 'name' field first, fallback to 'title' for backward compatibility
    final title =
        (product['name'] as String?) ??
        (product['title'] as String?) ??
        'Unknown';
    final price = _DashboardOverviewPage._parsePrice(product['price']);
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    final minStock = (product['minStock'] as num?)?.toInt() ?? 10;
    final category = (product['category'] as String?) ?? 'Uncategorized';
    final imageUrl = (product['imageUrl'] as String?);
    final isLowStock = stock < minStock;

    // Debug: Log image URL for troubleshooting
    if (kDebugMode) {
      debugPrint(
        '🖼️ Product "$title" - imageUrl: ${imageUrl ?? "null"} (length: ${imageUrl?.length ?? 0})',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(
            0xFFCD5656,
          ).withOpacity(0.3), // Red border matching theme
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image - Large size matching staff design
          AspectRatio(
            aspectRatio: 1.5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ProductImageWidget(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      backgroundColor: AppColors.border,
                    )
                  : Container(
                      color: AppColors.border,
                      child: Icon(
                        Icons.inventory_2,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Category Tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12, // Increased for clarity
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Sold Count Badge
                StreamBuilder<int>(
                  stream: ProductService().getSoldCountStream(productId),
                  builder: (context, snapshot) {
                    final soldCount = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$soldCount sold',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Price and Stock Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      PriceFormatter.formatPrice(price),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isLowStock
                            ? AppColors.error.withOpacity(0.1)
                            : AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Stock: $stock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isLowStock
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Action Buttons - Only show for admin
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    final userRole =
                        (snapshot.data?.data()
                                as Map<String, dynamic>?)?['role']
                            as String?;
                    final isAdmin = userRole == 'admin';

                    if (!isAdmin) return const SizedBox.shrink();

                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showEditProductDialog(
                              context,
                              productId,
                              product,
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(isMobile ? '' : 'Edit'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteProduct(context, productId),
                            icon: const Icon(Icons.delete, size: 16),
                            label: Text(isMobile ? '' : 'Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        if (isLowStock) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showRestockDialog(
                                context,
                                productId,
                                product,
                              ),
                              icon: const Icon(Icons.add_box, size: 16),
                              label: Text(isMobile ? '' : 'Restock'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 8 : 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final minStockController = TextEditingController(text: '10');
    final imageUrlController = TextEditingController();
    String selectedCategory = 'Windows';
    XFile? _selectedImage;
    Uint8List? _selectedImageBytes;
    bool _uploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Container(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 600
                    ? 500
                    : constraints.maxWidth - 32,
                maxHeight: constraints.maxHeight * 0.9,
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Product',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Product Title *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              border: OutlineInputBorder(),
                              prefixText: '₱',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Windows',
                                child: Text('Windows'),
                              ),
                              DropdownMenuItem(
                                value: 'Doors',
                                child: Text('Doors'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedCategory = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Initial Stock *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minStockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min Stock *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Image Upload Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Product Image',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedImage != null) ...[
                          FutureBuilder<Uint8List?>(
                            future: _selectedImageBytes != null
                                ? Future.value(_selectedImageBytes)
                                : _selectedImage!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (snapshot.hasData && snapshot.data != null) {
                                return Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Center(
                                  child: Icon(Icons.error_outline),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (image != null) {
                                  final bytes = await image.readAsBytes();
                                  setDialogState(() {
                                    _selectedImage = image;
                                    _selectedImageBytes = bytes;
                                  });
                                }
                              },
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Change Image'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.border,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.dashboardBackground,
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No image selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add a product image to help customers',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.camera,
                                    );
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      setDialogState(() {
                                        _selectedImage = image;
                                        _selectedImageBytes = bytes;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text('Take Photo'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      setDialogState(() {
                                        _selectedImage = image;
                                        _selectedImageBytes = bytes;
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.photo_library,
                                    size: 18,
                                  ),
                                  label: const Text('Choose from Gallery'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Image URL',
                            border: OutlineInputBorder(),
                            hintText: 'https://example.com/image.jpg',
                            helperText:
                                'Select an image above or enter a direct image URL (required)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _uploadingImage
                              ? null
                              : () async {
                                  if (titleController.text.isEmpty ||
                                      priceController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please fill required fields',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final price = double.tryParse(
                                    priceController.text,
                                  );
                                  final stock =
                                      int.tryParse(stockController.text) ?? 0;
                                  final minStock =
                                      int.tryParse(minStockController.text) ??
                                      10;

                                  // Require either an uploaded image or a URL
                                  if (_selectedImage == null &&
                                      imageUrlController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select an image or enter an Image URL',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  if (price == null || price <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter a valid price',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  String? finalImageUrl;

                                  // Upload image if selected
                                  if (_selectedImage != null) {
                                    setDialogState(() {
                                      _uploadingImage = true;
                                    });

                                    try {
                                      if (kDebugMode) {
                                        debugPrint(
                                          '📤 Starting image upload...',
                                        );
                                      }

                                      // Use cached bytes if available, otherwise read from XFile
                                      final Uint8List imageBytes =
                                          _selectedImageBytes ??
                                          await _selectedImage!.readAsBytes();

                                      if (kDebugMode) {
                                        debugPrint(
                                          '📦 Image bytes: ${imageBytes.length} bytes',
                                        );
                                      }

                                      // Generate storage path
                                      final storagePath =
                                          'products/${DateTime.now().millisecondsSinceEpoch}_${titleController.text.replaceAll(' ', '_')}.jpg';

                                      if (kDebugMode) {
                                        debugPrint(
                                          '📁 Storage path: $storagePath',
                                        );
                                      }

                                      // Use centralized service that works on both web and mobile
                                      finalImageUrl =
                                          await FirebaseStorageService.uploadImageBytes(
                                            imageBytes: imageBytes,
                                            storagePath: storagePath,
                                            contentType: 'image/jpeg',
                                          );

                                      if (kDebugMode) {
                                        debugPrint(
                                          '✅ Image uploaded successfully!',
                                        );
                                        debugPrint(
                                          '🔗 Download URL: $finalImageUrl',
                                        );
                                      }

                                      setDialogState(() {
                                        _uploadingImage = false;
                                      });
                                    } catch (e) {
                                      setDialogState(() {
                                        _uploadingImage = false;
                                      });

                                      if (kDebugMode) {
                                        debugPrint('❌ Image upload failed: $e');
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error uploading image: $e',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  } else if (imageUrlController.text
                                      .trim()
                                      .isNotEmpty) {
                                    // Use manually entered image URL if provided
                                    finalImageUrl = imageUrlController.text
                                        .trim();
                                  } else {
                                    if (kDebugMode) {
                                      debugPrint(
                                        '⚠️ No image selected or URL provided',
                                      );
                                    }
                                  }

                                  Navigator.pop(context);

                                  try {
                                    if (kDebugMode) {
                                      debugPrint(
                                        '💾 Saving product to Firestore...',
                                      );
                                      debugPrint('Image URL: $finalImageUrl');
                                    }

                                    final productData = <String, dynamic>{
                                      'title': titleController.text,
                                      'price': price,
                                      'stock': stock,
                                      'minStock': minStock,
                                      'category': selectedCategory,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };

                                    // Only add imageUrl if it's not null and not empty
                                    if (finalImageUrl != null &&
                                        finalImageUrl.isNotEmpty) {
                                      productData['imageUrl'] = finalImageUrl;
                                      if (kDebugMode) {
                                        debugPrint(
                                          '✅ Image URL added to product data',
                                        );
                                      }
                                    } else {
                                      if (kDebugMode) {
                                        debugPrint('⚠️ No image URL to save');
                                      }
                                    }

                                    final productRef = await FirebaseFirestore
                                        .instance
                                        .collection('products')
                                        .add(productData);

                                    if (kDebugMode) {
                                      debugPrint(
                                        '✅ Product saved successfully',
                                      );
                                    }

                                    // Log product creation activity
                                    try {
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      if (user != null) {
                                        final userDoc = await FirebaseFirestore
                                            .instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .get();
                                        final userData =
                                            userDoc.data()
                                                as Map<String, dynamic>?;
                                        final userName =
                                            (userData?['fullName']
                                                as String?) ??
                                            (userData?['name'] as String?) ??
                                            user.email?.split('@')[0] ??
                                            'Admin';

                                        await ActivityLogService()
                                            .logProductCreate(
                                              userId: user.uid,
                                              userName: userName,
                                              productId: productRef.id,
                                              productName: titleController.text,
                                            );
                                      }
                                    } catch (e) {
                                      if (kDebugMode) {
                                        debugPrint(
                                          '⚠️ Error logging product creation: $e',
                                        );
                                      }
                                    }

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Product added successfully',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error adding product: $e',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _uploadingImage
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Add Product'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProductDialog(
    BuildContext context,
    String productId,
    Map<String, dynamic> product,
  ) {
    // Pre-populate controllers with existing product data
    final nameController = TextEditingController(
      text: (product['name'] as String?) ?? (product['title'] as String?) ?? '',
    );
    final descriptionController = TextEditingController(
      text: product['description'] as String? ?? '',
    );
    final priceController = TextEditingController(
      text: (product['price'] as num?)?.toString() ?? '0',
    );
    final stockController = TextEditingController(
      text: (product['stock'] as num?)?.toString() ?? '0',
    );
    final minStockController = TextEditingController(
      text: (product['minStock'] as num?)?.toString() ?? '10',
    );
    final imageUrlController = TextEditingController(
      text: product['imageUrl'] as String? ?? '',
    );

    // Get existing category or default to 'Windows'
    String selectedCategory = (product['category'] as String?) ?? 'Windows';
    XFile? _selectedImage;
    Uint8List? _selectedImageBytes;
    bool _uploadingImage = false;
    String? _existingImageUrl = product['imageUrl'] as String?;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Container(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 600
                    ? 500
                    : constraints.maxWidth - 32,
                maxHeight: constraints.maxHeight * 0.9,
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Product',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              border: OutlineInputBorder(),
                              prefixText: '₱',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Windows',
                                child: Text('Windows'),
                              ),
                              DropdownMenuItem(
                                value: 'Doors',
                                child: Text('Doors'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedCategory = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minStockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min Stock *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Image Upload Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Product Image',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedImage != null) ...[
                          FutureBuilder<Uint8List?>(
                            future: _selectedImageBytes != null
                                ? Future.value(_selectedImageBytes)
                                : _selectedImage!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (snapshot.hasData && snapshot.data != null) {
                                return Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Center(
                                  child: Icon(Icons.error_outline),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      _selectedImage = null;
                                      _selectedImageBytes = null;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Remove Image'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      setDialogState(() {
                                        _selectedImage = image;
                                        _selectedImageBytes = bytes;
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.photo_library,
                                    size: 18,
                                  ),
                                  label: const Text('Change Image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (_existingImageUrl != null &&
                            _existingImageUrl!.isNotEmpty) ...[
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ProductImageWidget(
                                imageUrl: _existingImageUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      _existingImageUrl = null;
                                      imageUrlController.clear();
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Remove Image'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      setDialogState(() {
                                        _selectedImage = image;
                                        _selectedImageBytes = bytes;
                                        _existingImageUrl = null;
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.photo_library,
                                    size: 18,
                                  ),
                                  label: const Text('Change Image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.camera,
                                    );
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      setDialogState(() {
                                        _selectedImage = image;
                                        _selectedImageBytes = bytes;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text('Take Photo'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      setDialogState(() {
                                        _selectedImage = image;
                                        _selectedImageBytes = bytes;
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.photo_library,
                                    size: 18,
                                  ),
                                  label: const Text('Choose from Gallery'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Or enter Image URL (optional)',
                            border: OutlineInputBorder(),
                            hintText: 'https://example.com/image.jpg',
                            helperText:
                                'Use image picker above OR enter URL manually',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _uploadingImage
                              ? null
                              : () async {
                                  // Validation
                                  if (nameController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Product name cannot be empty',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  if (selectedCategory.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select a category',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  final price = double.tryParse(
                                    priceController.text.trim(),
                                  );
                                  if (price == null || price <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Price must be greater than 0',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  final stock = int.tryParse(
                                    stockController.text.trim(),
                                  );
                                  if (stock == null || stock < 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Stock cannot be negative',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  final minStock =
                                      int.tryParse(
                                        minStockController.text.trim(),
                                      ) ??
                                      10;

                                  String? finalImageUrl;

                                  // Upload image if selected
                                  if (_selectedImage != null) {
                                    setDialogState(() {
                                      _uploadingImage = true;
                                    });

                                    try {
                                      // Use cached bytes if available, otherwise read from XFile
                                      final Uint8List imageBytes =
                                          _selectedImageBytes ??
                                          await _selectedImage!.readAsBytes();

                                      // Generate storage path
                                      final storagePath =
                                          'products/${DateTime.now().millisecondsSinceEpoch}_${nameController.text.trim().replaceAll(' ', '_')}.jpg';

                                      // Use centralized service that works on both web and mobile
                                      finalImageUrl =
                                          await FirebaseStorageService.uploadImageBytes(
                                            imageBytes: imageBytes,
                                            storagePath: storagePath,
                                            contentType: 'image/jpeg',
                                          );

                                      setDialogState(() {
                                        _uploadingImage = false;
                                      });
                                    } catch (e) {
                                      setDialogState(() {
                                        _uploadingImage = false;
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error uploading image: $e',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  } else if (imageUrlController.text
                                      .trim()
                                      .isNotEmpty) {
                                    finalImageUrl = imageUrlController.text
                                        .trim();
                                  } else if (_existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty) {
                                    // Keep existing image if no new image is provided
                                    finalImageUrl = _existingImageUrl;
                                  }

                                  // Update product in Firestore
                                  try {
                                    final updateData = <String, dynamic>{
                                      'name': nameController.text.trim(),
                                      'title': nameController.text
                                          .trim(), // Keep for backward compatibility
                                      'description': descriptionController.text
                                          .trim(),
                                      'price': price,
                                      'stock': stock,
                                      'minStock': minStock,
                                      'category': selectedCategory,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };

                                    if (finalImageUrl != null) {
                                      updateData['imageUrl'] = finalImageUrl;
                                    }

                                    // Get old product data for logging
                                    final oldProductDoc =
                                        await FirebaseFirestore.instance
                                            .collection('products')
                                            .doc(productId)
                                            .get();
                                    final oldProductData =
                                        oldProductDoc.data()
                                            as Map<String, dynamic>?;

                                    await FirebaseFirestore.instance
                                        .collection('products')
                                        .doc(productId)
                                        .update(updateData);

                                    // Log product update activity
                                    try {
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      if (user != null) {
                                        final userDoc = await FirebaseFirestore
                                            .instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .get();
                                        final userData =
                                            userDoc.data()
                                                as Map<String, dynamic>?;
                                        final userName =
                                            (userData?['fullName']
                                                as String?) ??
                                            (userData?['name'] as String?) ??
                                            user.email?.split('@')[0] ??
                                            'Admin';

                                        final productName = nameController.text
                                            .trim();

                                        // Log changes for key fields
                                        if (oldProductData != null) {
                                          final oldName =
                                              (oldProductData['name']
                                                  as String?) ??
                                              (oldProductData['title']
                                                  as String?) ??
                                              '';
                                          final oldPrice =
                                              (oldProductData['price'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                          final oldStock =
                                              (oldProductData['stock'] as num?)
                                                  ?.toInt() ??
                                              0;
                                          final oldCategory =
                                              oldProductData['category']
                                                  as String? ??
                                              '';

                                          if (oldName != productName) {
                                            await ActivityLogService()
                                                .logProductUpdate(
                                                  userId: user.uid,
                                                  userName: userName,
                                                  productId: productId,
                                                  productName: productName,
                                                  fieldChanged: 'name',
                                                  oldValue: oldName,
                                                  newValue: productName,
                                                );
                                          }
                                          if (oldPrice != price) {
                                            await ActivityLogService().logProductUpdate(
                                              userId: user.uid,
                                              userName: userName,
                                              productId: productId,
                                              productName: productName,
                                              fieldChanged: 'price',
                                              oldValue:
                                                  '₱${oldPrice.toStringAsFixed(2)}',
                                              newValue:
                                                  '₱${price.toStringAsFixed(2)}',
                                            );
                                          }
                                          if (oldStock != stock) {
                                            await ActivityLogService()
                                                .logProductUpdate(
                                                  userId: user.uid,
                                                  userName: userName,
                                                  productId: productId,
                                                  productName: productName,
                                                  fieldChanged: 'stock',
                                                  oldValue: oldStock.toString(),
                                                  newValue: stock.toString(),
                                                );
                                          }
                                          if (oldCategory != selectedCategory) {
                                            await ActivityLogService()
                                                .logProductUpdate(
                                                  userId: user.uid,
                                                  userName: userName,
                                                  productId: productId,
                                                  productName: productName,
                                                  fieldChanged: 'category',
                                                  oldValue: oldCategory,
                                                  newValue: selectedCategory,
                                                );
                                          }
                                        } else {
                                          // If no old data, just log general update
                                          await ActivityLogService()
                                              .logProductUpdate(
                                                userId: user.uid,
                                                userName: userName,
                                                productId: productId,
                                                productName: productName,
                                              );
                                        }
                                      }
                                    } catch (e) {
                                      if (kDebugMode) {
                                        debugPrint(
                                          '⚠️ Error logging product update: $e',
                                        );
                                      }
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Product updated successfully!',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error updating product: $e',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _uploadingImage
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteProduct(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Get product data before deletion for logging
              final productDoc = await FirebaseFirestore.instance
                  .collection('products')
                  .doc(productId)
                  .get();
              final productData = productDoc.data() as Map<String, dynamic>?;
              final productName =
                  (productData?['name'] as String?) ??
                  (productData?['title'] as String?) ??
                  'Unknown Product';

              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(productId)
                  .delete();

              // Log product deletion activity
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get();
                  final userData = userDoc.data() as Map<String, dynamic>?;
                  final userName =
                      (userData?['fullName'] as String?) ??
                      (userData?['name'] as String?) ??
                      user.email?.split('@')[0] ??
                      'Admin';

                  await ActivityLogService().logProductDelete(
                    userId: user.uid,
                    userName: userName,
                    productId: productId,
                    productName: productName,
                  );
                }
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('⚠️ Error logging product deletion: $e');
                }
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(
    BuildContext context,
    String productId,
    Map<String, dynamic> product,
  ) {
    final currentStock = (product['stock'] as num?)?.toInt() ?? 0;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restock Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: $currentStock'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity to add',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(controller.text);
              if (quantity != null && quantity > 0) {
                Navigator.pop(context);
                // Get product data for logging
                final productDoc = await FirebaseFirestore.instance
                    .collection('products')
                    .doc(productId)
                    .get();
                final productData = productDoc.data() as Map<String, dynamic>?;
                final oldStock = (productData?['stock'] as num?)?.toInt() ?? 0;
                final productName =
                    (productData?['name'] as String?) ??
                    (productData?['title'] as String?) ??
                    'Unknown Product';
                final newStock = oldStock + quantity;

                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(productId)
                    .update({
                      'stock': FieldValue.increment(quantity),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                // Log restock activity
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();
                    final userData = userDoc.data() as Map<String, dynamic>?;
                    final userName =
                        (userData?['fullName'] as String?) ??
                        (userData?['name'] as String?) ??
                        user.email?.split('@')[0] ??
                        'Admin';

                    await ActivityLogService().logProductUpdate(
                      userId: user.uid,
                      userName: userName,
                      productId: productId,
                      productName: productName,
                      fieldChanged: 'stock',
                      oldValue: oldStock.toString(),
                      newValue: newStock.toString(),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('⚠️ Error logging restock: $e');
                  }
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restocked $quantity units')),
                  );
                }
              }
            },
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }
}

class _PosPage extends StatelessWidget {
  const _PosPage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Transactions Yet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All orders will appear here',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs;

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${orders.length} ${orders.length == 1 ? 'order' : 'orders'}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Orders Table
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final orderId = doc.id;
                  final fallbackCustomerName =
                      data['customerName'] ?? 'Unknown';
                  final customerId = data['customerId'] as String?;
                  // Get totalPrice from Firestore, or compute from items if missing
                  // Read totalPrice with null safety: default to 0 if missing
                  final items = (data['items'] as List?) ?? [];
                  double price =
                      (data['totalPrice'] as num?)?.toDouble() ?? 0.0;

                  // If totalPrice is 0 or missing, compute from items as fallback
                  if (price == 0.0 && items.isNotEmpty) {
                    for (var item in items) {
                      if (item is Map<String, dynamic>) {
                        final itemPrice =
                            (item['price'] as num?)?.toDouble() ?? 0.0;
                        final quantity =
                            (item['quantity'] as num?)?.toInt() ?? 1;
                        price += itemPrice * quantity;
                      }
                    }
                  }

                  final totalAmount = price;
                  final status = (data['status'] as String? ?? 'pending')
                      .toString()
                      .toLowerCase();
                  final createdAt = data['createdAt'];

                  String formattedDate = 'N/A';
                  if (createdAt != null) {
                    try {
                      final timestamp = createdAt as Timestamp;
                      final date = timestamp.toDate();
                      formattedDate = '${date.day}/${date.month}/${date.year}';
                    } catch (e) {
                      formattedDate = 'N/A';
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order ID: ${orderId.substring(0, 8).toUpperCase()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FutureBuilder<DocumentSnapshot>(
                                      future: customerId != null
                                          ? FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(customerId)
                                                .get()
                                          : null,
                                      builder: (context, snapshot) {
                                        String displayName =
                                            fallbackCustomerName;
                                        if (snapshot.hasData &&
                                            snapshot.data!.exists) {
                                          final userData =
                                              snapshot.data!.data()
                                                  as Map<String, dynamic>?;
                                          displayName =
                                              (userData?['fullName']
                                                  as String?) ??
                                              (userData?['name'] as String?) ??
                                              (userData?['customerName']
                                                  as String?) ??
                                              fallbackCustomerName;
                                        }
                                        return Text(
                                          displayName,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    PriceFormatter.formatPrice(
                                      totalAmount.toDouble(),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        status,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Date: $formattedDate',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              _buildStatusButtons(
                                context,
                                doc.reference,
                                status,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusButtons(
    BuildContext context,
    DocumentReference orderRef,
    String currentStatus,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (currentStatus == 'Pending')
          TextButton(
            onPressed: () => _updateStatus(context, orderRef, 'processing'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Process'),
          ),
        if (currentStatus == 'Processing')
          TextButton(
            onPressed: () => _updateStatus(context, orderRef, 'completed'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Complete'),
          ),
      ],
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    DocumentReference orderRef,
    String newStatus,
  ) async {
    try {
      // Get order data first to get customerId
      final orderDoc = await orderRef.get();
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final customerId =
          orderData['customerId'] as String? ??
          orderData['userId'] as String? ??
          '';

      // Update order status
      await orderRef.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to customer
      if (customerId.isNotEmpty) {
        try {
          final notificationService = NotificationService.instance;
          await notificationService.notifyOrderStatusChange(
            customerId: customerId,
            orderId: orderRef.id,
            orderData: orderData,
            newStatus: newStatus,
          );
        } catch (e) {
          // Don't fail the status update if notification fails
          if (kDebugMode) {
            print('⚠️ Error creating notification: $e');
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: AppColors.success,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.accent;
      case 'processing':
        return AppColors.secondary;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ==================== SALES CALENDAR PAGE ====================
class _SalesCalendarPage extends StatefulWidget {
  const _SalesCalendarPage();

  @override
  State<_SalesCalendarPage> createState() => _SalesCalendarPageState();
}

class _SalesCalendarPageState extends State<_SalesCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AdminThemeColors.crimsonRed,
                  AdminThemeColors.deepBerryRed,
                  AdminThemeColors.darkWinePurple,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Sales Calendar',
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View sales by date',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Calendar
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      // Set focusedDay to selectedDay to center the calendar on the selected date
                      // This ensures the calendar navigates to the month containing the selected date
                      _focusedDay = selectedDay;
                    });
                    _showSalesBottomSheet(context, selectedDay);
                  }
                },
                onPageChanged: (focusedDay) {
                  // Update focusedDay when user navigates the calendar
                  // This allows the calendar to scroll through months/weeks
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(
                    color: AdminThemeColors.crimsonRed,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AdminThemeColors.crimsonRed,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AdminThemeColors.crimsonRed.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: AdminThemeColors.deepBerryRed,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                    color: AdminThemeColors.crimsonRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  formatButtonTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: AdminThemeColors.crimsonRed,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: AdminThemeColors.crimsonRed,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSalesBottomSheet(BuildContext context, DateTime selectedDate) {
    // Calculate start and end of selected day
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      0,
      0,
      0,
    );
    final endOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      23,
      59,
      59,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - Fixed at top
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminThemeColors.crimsonRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: AdminThemeColors.crimsonRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales for ${DateFormat('MMMM d, yyyy').format(selectedDate)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE').format(selectedDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(
                                0xFF1D3B53,
                              ), // Dark blue for better contrast
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Sales Data - Scrollable content area
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                            .collection('orders')
                            .where(
                              'createdAt',
                              isGreaterThanOrEqualTo: Timestamp.fromDate(
                                startOfDay,
                              ),
                            )
                            .where(
                              'createdAt',
                              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
                            )
                            .snapshots()
                            .handleError((error) {
                              // Fallback: query without date filters if index is missing
                              if (error.toString().contains('index') ||
                                  error.toString().contains(
                                    'failed-precondition',
                                  )) {
                                return FirebaseFirestore.instance
                                    .collection('orders')
                                    .snapshots();
                              }
                              throw error;
                            })
                      : null,
                  builder: (context, snapshot) {
                    // Check authentication first
                    if (FirebaseAuth.instance.currentUser == null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: Colors.orange[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Authentication Required',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please log in to view sales data.',
                                style: const TextStyle(
                                  color: Color(0xFF1D3B53),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      final error = snapshot.error.toString();
                      final isPermissionError =
                          error.contains('permission-denied') ||
                          error.contains('Missing or insufficient permissions');
                      final isIndexError =
                          error.contains('index') ||
                          error.contains('requires an index');

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isIndexError
                                    ? Icons.build_outlined
                                    : Icons.error_outline,
                                size: 64,
                                color: isIndexError
                                    ? Colors.orange[300]
                                    : Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isIndexError
                                    ? 'Index Required'
                                    : 'Error loading sales',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isIndexError
                                    ? 'A Firestore index is required for this query. Please check the console for the index creation link, or contact your administrator.'
                                    : isPermissionError
                                    ? 'Permission denied. Please ensure you are logged in and have the correct permissions.'
                                    : error,
                                style: const TextStyle(
                                  color: Color(0xFF1D3B53),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (isPermissionError) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'If this error persists, please contact your administrator.',
                                  style: TextStyle(
                                    color: const Color(
                                      0xFF1D3B53,
                                    ).withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    // Filter orders by selected date and sort by date (descending)
                    final allOrders = snapshot.data!.docs;
                    final ordersForDate =
                        allOrders.where((orderDoc) {
                          final order = orderDoc.data() as Map<String, dynamic>;
                          final createdAt = order['createdAt'] as Timestamp?;
                          if (createdAt == null) return false;

                          final orderDate = createdAt.toDate();
                          return orderDate.isAfter(
                                startOfDay.subtract(const Duration(seconds: 1)),
                              ) &&
                              orderDate.isBefore(
                                endOfDay.add(const Duration(seconds: 1)),
                              );
                        }).toList()..sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aTimestamp = aData['createdAt'] as Timestamp?;
                          final bTimestamp = bData['createdAt'] as Timestamp?;
                          if (aTimestamp == null && bTimestamp == null)
                            return 0;
                          if (aTimestamp == null) return 1;
                          if (bTimestamp == null) return -1;
                          return bTimestamp.compareTo(
                            aTimestamp,
                          ); // Descending order
                        });

                    if (ordersForDate.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sales for this date',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No transactions found for ${DateFormat('MMMM d, yyyy').format(selectedDate)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    double totalSales = 0;
                    int transactionCount = ordersForDate.length;

                    // Calculate total sales from orders
                    for (var order in ordersForDate) {
                      final data = order.data() as Map<String, dynamic>;
                      // Try totalPrice first, then totalAmount, then amount
                      final amount =
                          data['totalPrice'] ??
                          data['totalAmount'] ??
                          data['amount'];
                      if (amount != null) {
                        if (amount is num) {
                          totalSales += amount.toDouble();
                        } else if (amount is String) {
                          totalSales += double.tryParse(amount) ?? 0;
                        }
                      }
                    }

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Summary Cards
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Total Sales',
                                    PriceFormatter.formatPrice(totalSales),
                                    Icons.attach_money,
                                    AdminThemeColors.crimsonRed,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Transactions',
                                    transactionCount.toString(),
                                    Icons.receipt_long,
                                    AdminThemeColors.deepBerryRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          // Transactions List
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: ordersForDate.length,
                            itemBuilder: (context, index) {
                              final order = ordersForDate[index];
                              final data = order.data() as Map<String, dynamic>;
                              // Try totalPrice first, then totalAmount, then amount
                              final amount =
                                  data['totalPrice'] ??
                                  data['totalAmount'] ??
                                  data['amount'];
                              final createdAt = data['createdAt'] as Timestamp?;

                              double saleAmount = 0;
                              if (amount != null) {
                                if (amount is num) {
                                  saleAmount = amount.toDouble();
                                } else if (amount is String) {
                                  saleAmount = double.tryParse(amount) ?? 0;
                                }
                              }

                              String timeString = '';
                              if (createdAt != null) {
                                timeString = DateFormat(
                                  'h:mm a',
                                ).format(createdAt.toDate());
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AdminThemeColors.crimsonRed
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.payment,
                                      color: AdminThemeColors.crimsonRed,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    'Transaction ${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    timeString.isNotEmpty
                                        ? 'Time: $timeString'
                                        : 'No time available',
                                    style: TextStyle(
                                      color: const Color(
                                        0xFF1D3B53,
                                      ), // Dark blue for better contrast
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Text(
                                    PriceFormatter.formatPrice(saleAmount),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AdminThemeColors.crimsonRed,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersManagementPage extends StatefulWidget {
  const _OrdersManagementPage();

  @override
  State<_OrdersManagementPage> createState() => _OrdersManagementPageState();
}

class _OrdersManagementPageState extends State<_OrdersManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterStatus = 'all'; // all, pending, processing, completed
  String _filterPayment = 'all'; // all, paid, unpaid

  static const Set<String> _pendingStatuses = {
    'pending',
    'pending_payment',
    'pending_delivery',
    'to_pay',
  };

  static const Set<String> _inProgressStatuses = {
    'processing',
    'scheduled',
    'paid',
    'shipped',
    'awaiting_installation',
    'awaiting installation',
  };

  static const Set<String> _completedStatuses = {'completed', 'delivered'};

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

  bool _matchesStatusGroup(String group, String status) {
    final normalized = status.toLowerCase();
    switch (group) {
      case 'pending':
        return _pendingStatuses.contains(normalized);
      case 'processing':
        return _inProgressStatuses.contains(normalized);
      case 'completed':
        return _completedStatuses.contains(normalized);
      default:
        return group == 'all' ? true : normalized == group.toLowerCase();
    }
  }

  String _formatStatusLabel(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'pending_delivery':
        return 'Pending Delivery';
      case 'pending_payment':
      case 'to_pay':
        return 'Pending Payment';
      case 'scheduled':
        return 'Scheduled';
      case 'awaiting_installation':
      case 'awaiting installation':
        return 'Awaiting Installation';
      case 'paid':
        return 'Paid';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'processing':
        return 'Processing';
      case 'pending':
        return 'Pending';
      default:
        return normalized
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }

  Color _getStatusColor(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'pending':
      case 'pending_payment':
      case 'pending_delivery':
      case 'to_pay':
        return AppColors.accent;
      case 'processing':
      case 'scheduled':
        return AppColors.primary;
      case 'paid':
      case 'shipped':
      case 'awaiting_installation':
      case 'awaiting installation':
        return AppColors.info;
      case 'delivered':
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'pending':
      case 'pending_payment':
      case 'pending_delivery':
      case 'to_pay':
        return Icons.pending;
      case 'processing':
      case 'scheduled':
        return Icons.build;
      case 'paid':
        return Icons.payments_outlined;
      case 'shipped':
        return Icons.local_shipping;
      case 'awaiting_installation':
      case 'awaiting installation':
        return Icons.event_available_outlined;
      case 'delivered':
        return Icons.inventory_2_outlined;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: Column(
        children: [
          // Header with filters - Responsive
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              return Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(
                        0xFFCD5656,
                      ).withOpacity(0.3), // Red border matching theme
                      width: 2,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Orders & Quotations',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MapComingSoonPlaceholder(
                                      title: 'Delivery Locations Map',
                                      message:
                                          'Map view of all delivery locations is coming soon!',
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('View Map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isMobile) ...[
                      const SizedBox(height: 4),
                      Text(
                        'View incoming orders and quotations prepared by staff',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Filters - Responsive layout
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Status Filter
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterStatus,
                                  isDense: true,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All Status'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('Pending'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'processing',
                                      child: Text('In Progress'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'completed',
                                      child: Text('Completed'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterStatus = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Payment Filter
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterPayment,
                                  isDense: true,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All Payments'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'paid',
                                      child: Text('Paid'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'unpaid',
                                      child: Text('Unpaid'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterPayment = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Status Filter
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterStatus,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All Status'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('Pending'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'processing',
                                      child: Text('In Progress'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'completed',
                                      child: Text('Completed'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterStatus = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Payment Filter
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dashboardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterPayment,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All Payments'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'paid',
                                      child: Text('Paid'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'unpaid',
                                      child: Text('Unpaid'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => _filterPayment = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 12),
                    TabBar(
                      controller: _tabController,
                      isScrollable: isMobile,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      tabs: const [
                        Tab(text: 'All Orders'),
                        Tab(text: 'Pending'),
                        Tab(text: 'In Progress'),
                        Tab(text: 'Completed'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // Orders List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(context, 'all'),
                _buildOrdersList(context, 'pending'),
                _buildOrdersList(context, 'processing'),
                _buildOrdersList(context, 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, String statusFilter) {
    final query = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No orders found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs;
        final filteredOrders = orders.where((doc) {
          final order = doc.data() as Map<String, dynamic>;
          final status = (order['status'] as String? ?? '').toLowerCase();
          final paymentStatus = (order['paymentStatus'] as String? ?? 'unpaid')
              .toLowerCase();

          if ((order['isQuotation'] as bool? ?? false)) {
            return false;
          }

          if (statusFilter != 'all' &&
              !_matchesStatusGroup(statusFilter, status)) {
            return false;
          }

          // Apply status filter
          if (_filterStatus != 'all') {
            if (!_matchesStatusGroup(_filterStatus, status)) return false;
          }

          // Apply payment filter
          if (_filterPayment != 'all') {
            if (paymentStatus != _filterPayment) return false;
          }

          return true;
        }).toList();

        final isMobile = MediaQuery.of(context).size.width < 768;
        final isTablet = MediaQuery.of(context).size.width < 1024 && !isMobile;

        if (isMobile) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final orderDoc = filteredOrders[index];
              final order = orderDoc.data() as Map<String, dynamic>;
              return _buildOrderCard(
                context,
                orderDoc.id,
                order,
                isMobile: true,
              );
            },
          );
        }

        // Web/Tablet Grid Layout
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 2 : 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final orderDoc = filteredOrders[index];
            final order = orderDoc.data() as Map<String, dynamic>;
            return _buildOrderCard(
              context,
              orderDoc.id,
              order,
              isMobile: false,
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> order, {
    bool isMobile = false,
  }) {
    final status = (order['status'] as String?) ?? 'pending';
    final fallbackCustomerName =
        (order['customerName'] as String?) ?? 'Unknown';
    final customerId = order['customerId'] as String?;
    final items = (order['items'] as List<dynamic>?) ?? [];
    final createdAt = order['createdAt'] as Timestamp?;
    final assignedStaffId = order['assignedStaffId'] as String?;
    final paymentStatus = order['paymentStatus'] as String? ?? 'unpaid';
    final isQuotation = order['isQuotation'] as bool? ?? false;
    final quotationPreparedBy = order['quotationPreparedBy'] as String?;

    // Read totalPrice from Firestore (correct field name)
    // Priority: totalPrice > price > compute from items
    double total = (order['totalPrice'] as num?)?.toDouble() ?? 0.0;

    // Fallback to 'price' field if totalPrice is 0 or missing
    if (total == 0.0) {
      total = (order['price'] as num?)?.toDouble() ?? 0.0;
    }

    // If still 0, compute from items array as last resort
    if (total == 0.0 && items.isNotEmpty) {
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          final itemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          total += itemPrice * quantity;
        }
      }
    }

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusLabel = _formatStatusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(
            0xFFCD5656,
          ).withOpacity(0.3), // Red border matching theme
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isQuotation)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'QUOTATION',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: paymentStatus == 'paid'
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    paymentStatus == 'paid' ? 'PAID' : 'UNPAID',
                    style: TextStyle(
                      color: paymentStatus == 'paid'
                          ? AppColors.success
                          : AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<DocumentSnapshot>(
                        future: customerId != null
                            ? FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(customerId)
                                  .get()
                            : null,
                        builder: (context, snapshot) {
                          String displayName = fallbackCustomerName;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            displayName =
                                (userData?['fullName'] as String?) ??
                                (userData?['name'] as String?) ??
                                (userData?['customerName'] as String?) ??
                                fallbackCustomerName;
                          }
                          return Text(
                            'Customer: $displayName',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Date: ${createdAt.toDate().toString().substring(0, 16)}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (isQuotation && quotationPreparedBy != null) ...[
                        const SizedBox(height: 4),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(quotationPreparedBy)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final userData =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>?;
                              final staffName =
                                  (userData?['name'] as String?) ??
                                  (userData?['customerName'] as String?) ??
                                  'Staff';
                              return Text(
                                'Quotation by: $staffName',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      PriceFormatter.formatPrice(total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${items.length} item${items.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (assignedStaffId != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(assignedStaffId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    final staffName =
                        (userData?['name'] as String?) ??
                        (userData?['customerName'] as String?) ??
                        'Staff';
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Assigned: $staffName',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            const SizedBox(height: 12),
            if (isMobile) ...[
              // Mobile: Stack buttons vertically
              OutlinedButton.icon(
                onPressed: () => _viewOrderDetails(context, orderId, order),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              // View Map button (if coordinates exist)
              if (order['latitude'] != null && order['longitude'] != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapComingSoonPlaceholder(
                          title: 'Order Location',
                          message:
                              'Map view for order delivery location is coming soon!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('View Map'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
              if (status != 'delivered' && status != 'completed') ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _updateOrderStatus(context, orderId, order),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Update Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
              if (status == 'processing' || status == 'quoted') ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _assignStaff(context, orderId, order),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Assign Staff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ] else ...[
              // Web: Horizontal button layout
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _viewOrderDetails(context, orderId, order),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  // View Map button (if coordinates exist)
                  if (order['latitude'] != null && order['longitude'] != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapComingSoonPlaceholder(
                              title: 'Order Location',
                              message:
                                  'Map view for order delivery location is coming soon!',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('View Map'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  if (status != 'delivered' && status != 'completed')
                    ElevatedButton.icon(
                      onPressed: () =>
                          _updateOrderStatus(context, orderId, order),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Update Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  if (status == 'processing' || status == 'quoted')
                    ElevatedButton.icon(
                      onPressed: () => _assignStaff(context, orderId, order),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Assign Staff'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (paymentStatus == 'unpaid')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _markPaymentReceived(context, orderId),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Mark Payment Received (On-Site)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _viewOrderDetails(
    BuildContext context,
    String orderId,
    Map<String, dynamic> order,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(
          orderId: orderId,
          orderRef: FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId),
        ),
      ),
    );
  }

  void _updateOrderStatus(
    BuildContext context,
    String orderId,
    Map<String, dynamic> order,
  ) {
    final currentStatus = order['status'] as String? ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(
              context,
              orderId,
              currentStatus,
              'pending',
              'Pending',
            ),
            _buildStatusOption(
              context,
              orderId,
              currentStatus,
              'quoted',
              'Quoted',
            ),
            _buildStatusOption(
              context,
              orderId,
              currentStatus,
              'processing',
              'Processing',
            ),
            _buildStatusOption(
              context,
              orderId,
              currentStatus,
              'completed',
              'Completed',
            ),
            _buildStatusOption(
              context,
              orderId,
              currentStatus,
              'delivered',
              'Delivered',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context,
    String orderId,
    String currentStatus,
    String status,
    String label,
  ) {
    final isSelected = currentStatus == status;
    return ListTile(
      title: Text(label),
      leading: Radio<String>(
        value: status,
        groupValue: currentStatus,
        onChanged: (value) async {
          Navigator.pop(context);

          // Get order details
          final orderDoc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .get();
          final orderData = orderDoc.data() ?? {};
          final customerId =
              orderData['customerId'] as String? ??
              orderData['userId'] as String? ??
              '';
          final oldStatus = orderData['status'] as String? ?? 'pending';

          // Get user info for logging
          final user = FirebaseAuth.instance.currentUser;
          String? userName;
          if (user != null) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final userData = userDoc.data() as Map<String, dynamic>?;
              userName =
                  (userData?['fullName'] as String?) ??
                  (userData?['name'] as String?) ??
                  user.email?.split('@')[0] ??
                  'Admin';
            } catch (e) {
              userName = user.email?.split('@')[0] ?? 'Admin';
            }
          }

          final customerName = orderData['customerName'] as String?;

          // Update order status
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .update({
                'status': status,
                'updatedAt': FieldValue.serverTimestamp(),
                // keep alias fields in sync for compatibility
                'statusLabel': label,
              });

          // Log order status change activity
          if (user != null && userName != null) {
            try {
              await ActivityLogService().logOrderStatusChange(
                userId: user.uid,
                userName: userName,
                orderId: orderId,
                oldStatus: oldStatus,
                newStatus: status,
                customerName: customerName,
              );
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ Error logging order status change: $e');
              }
            }
          }

          // Create notification for customer when status changes
          if (customerId.isNotEmpty && oldStatus != status) {
            try {
              final notificationService = NotificationService.instance;
              await notificationService.notifyOrderStatusChange(
                customerId: customerId,
                orderId: orderId,
                orderData: orderData,
                newStatus: status,
              );
            } catch (e) {
              // Don't fail the status update if notification fails
              if (kDebugMode) {
                print('⚠️ Error creating notification: $e');
              }
            }
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Order status updated to $label')),
            );
          }
        },
      ),
      selected: isSelected,
    );
  }

  void _assignStaff(
    BuildContext context,
    String orderId,
    Map<String, dynamic> order,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Staff Member'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .snapshots() // Load all users, filter in memory
                .handleError((error) {
                  debugPrint('⚠️ Error loading users: $error');
                  return FirebaseFirestore.instance
                      .collection('users')
                      .snapshots();
                }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter staff in memory
              final staffMembers =
                  (snapshot.hasData
                          ? snapshot.data!.docs
                          : <QueryDocumentSnapshot>[])
                      .where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final role = (data['role'] as String?) ?? '';
                        return role.toLowerCase() == 'staff';
                      })
                      .toList();
              if (staffMembers.isEmpty) {
                return const Text('No staff members available');
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: staffMembers.length,
                itemBuilder: (context, index) {
                  final staff = staffMembers[index];
                  final staffData = staff.data() as Map<String, dynamic>;
                  final staffName =
                      (staffData['name'] as String?) ??
                      (staffData['customerName'] as String?) ??
                      staffData['email'] ??
                      'Staff';
                  final isAssigned = order['assignedStaffId'] == staff.id;

                  return ListTile(
                    leading: const CompactProfilePicturePlaceholder(size: 40),
                    title: Text(staffName),
                    subtitle: Text(staffData['email'] ?? ''),
                    trailing: isAssigned
                        ? Icon(Icons.check_circle, color: AppColors.success)
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      await FirebaseFirestore.instance
                          .collection('orders')
                          .doc(orderId)
                          .update({
                            'assignedStaffId': staff.id,
                            'assignedStaffName': staffName,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Order assigned to $staffName'),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _markPaymentReceived(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Payment Received'),
        content: const Text(
          'This will mark the payment as received on-site. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Get order details for notification
              final orderDoc = await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(orderId)
                  .get();
              final orderData = orderDoc.data() ?? {};
              final userId = orderData['userId'] as String? ?? '';

              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(orderId)
                  .update({
                    'paymentStatus': 'paid',
                    'paymentReceivedAt': FieldValue.serverTimestamp(),
                    'paymentMethod': 'on-site',
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

              // Notify customer
              if (userId.isNotEmpty) {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'userId': userId,
                  'type': 'payment_received',
                  'title': 'Payment Received',
                  'message':
                      'Payment for order #${orderId.substring(0, 8).toUpperCase()} has been received.',
                  'orderId': orderId,
                  'read': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment marked as received')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogPage extends StatelessWidget {
  const _ActivityLogPage();

  @override
  Widget build(BuildContext context) {
    return const ActivityLogPage();
  }
}

// Old CustomersManagementPageState removed - replaced with ActivityLogPage

class _StaffManagementPage extends StatefulWidget {
  const _StaffManagementPage();

  @override
  State<_StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<_StaffManagementPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: Column(
        children: [
          // Header - Responsive
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              return Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(
                        0xFFCD5656,
                      ).withOpacity(0.3), // Red border matching theme
                      width: 2,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Staff Management',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (!isMobile) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Manage staff accounts and assignments',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isMobile)
                          ElevatedButton.icon(
                            onPressed: () => _showAddStaffDialog(context),
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add Staff'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    if (isMobile) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddStaffDialog(context),
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Add Staff'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          // Content
          Expanded(child: _buildStaffList()),
        ],
      ),
    );
  }

  Widget _buildStaffList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots() // Load all users, filter in memory
          .handleError((error) {
            debugPrint('⚠️ Error loading users: $error');
            return FirebaseFirestore.instance.collection('users').snapshots();
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter staff in memory
        final staffMembers =
            (snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[])
                .where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = (data['role'] as String?) ?? '';
                  return role.toLowerCase() == 'staff';
                })
                .toList();

        if (staffMembers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No staff members found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _showAddStaffDialog(context),
                  child: const Text('Add First Staff Member'),
                ),
              ],
            ),
          );
        }

        // staffMembers is already defined above from filtering
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: staffMembers.length,
          itemBuilder: (context, index) {
            final staffDoc = staffMembers[index];
            final staff = staffDoc.data() as Map<String, dynamic>;
            return _buildStaffCard(context, staffDoc.id, staff);
          },
        );
      },
    );
  }

  Widget _buildStaffCard(
    BuildContext context,
    String staffId,
    Map<String, dynamic> staff,
  ) {
    final name =
        (staff['name'] as String?) ??
        (staff['customerName'] as String?) ??
        staff['email'] ??
        'Staff';
    final email = staff['email'] ?? 'No email';
    final phone = staff['phone'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const ProfilePicturePlaceholder(size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (phone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () =>
                      _showEditStaffDialog(context, staffId, staff),
                  tooltip: 'Edit',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add staff functionality - requires Firebase Auth setup'),
      ),
    );
  }

  void _showEditStaffDialog(
    BuildContext context,
    String staffId,
    Map<String, dynamic> staff,
  ) {
    final currentRole = staff['role'] as String? ?? 'customer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change User Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User: ${staff['name'] ?? staff['customerName'] ?? staff['email'] ?? 'Unknown'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Current Role: ${currentRole.toUpperCase()}'),
            const SizedBox(height: 16),
            const Text('Select new role:'),
            const SizedBox(height: 8),
            ...['admin', 'staff', 'customer'].map((role) {
              final isSelected = role == currentRole;
              return RadioListTile<String>(
                title: Text(role.toUpperCase()),
                value: role,
                groupValue: currentRole,
                onChanged: isSelected
                    ? null
                    : (value) async {
                        if (value == null) return;

                        Navigator.pop(context); // Close dialog

                        // Show loading
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        try {
                          await RoleService.assignUserRole(staffId, value);

                          // Log user role update activity
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final userDoc = await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .get();
                              final userData =
                                  userDoc.data() as Map<String, dynamic>?;
                              final userName =
                                  (userData?['fullName'] as String?) ??
                                  (userData?['name'] as String?) ??
                                  user.email?.split('@')[0] ??
                                  'Admin';

                              final targetUserName =
                                  (staff['fullName'] as String?) ??
                                  (staff['name'] as String?) ??
                                  (staff['customerName'] as String?) ??
                                  (staff['email'] as String?) ??
                                  'Unknown User';

                              await ActivityLogService().logUserUpdate(
                                userId: user.uid,
                                userName: userName,
                                targetUserId: staffId,
                                targetUserName: targetUserName,
                                fieldChanged: 'role',
                                oldValue: currentRole,
                                newValue: value,
                              );
                            }
                          } catch (logError) {
                            if (kDebugMode) {
                              debugPrint(
                                '⚠️ Error logging user role update: $logError',
                              );
                            }
                          }

                          if (context.mounted) {
                            Navigator.pop(context); // Close loading
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Role changed to ${value.toUpperCase()} successfully',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // Close loading
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackPage extends StatelessWidget {
  const _FeedbackPage();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF8B2E2E).withOpacity(0.3),
                  width: 2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.feedback_outlined,
                  size: isMobile ? 28 : 32,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Feedback Center',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Feedback List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots()
                  .handleError((error) {
                    if (kDebugMode) {
                      debugPrint(
                        '⚠️ OrderBy createdAt failed, using simple query: $error',
                      );
                    }
                    // Fallback: return orders without orderBy
                    return FirebaseFirestore.instance
                        .collection('orders')
                        .snapshots();
                  }),
              builder: (context, snapshot) {
                // Handle connection state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Handle errors
                if (snapshot.hasError) {
                  return Center(
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
                          'Error loading feedback',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.feedback_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No feedback yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Customer ratings and reviews will appear here',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                // Filter orders with ratings and sort by createdAt
                final allOrders = List<QueryDocumentSnapshot>.from(
                  snapshot.data!.docs,
                );

                // Filter orders that have ratings
                final ordersWithRatings = allOrders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hasRating = data['hasRating'] as bool? ?? false;
                  final rating = data['rating'] as num?;
                  return hasRating || (rating != null && rating > 0);
                }).toList();

                // Sort by createdAt in memory if orderBy failed
                ordersWithRatings.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aCreatedAt = aData['createdAt'] as Timestamp?;
                  final bCreatedAt = bData['createdAt'] as Timestamp?;
                  if (aCreatedAt == null && bCreatedAt == null) return 0;
                  if (aCreatedAt == null) return 1;
                  if (bCreatedAt == null) return -1;
                  return bCreatedAt.compareTo(aCreatedAt);
                });

                if (ordersWithRatings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.feedback_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No feedback yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Customer ratings and reviews will appear here',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                final orders = ordersWithRatings;

                // Use grid layout for web, list for mobile
                if (isMobile) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final orderDoc = orders[index];
                      final orderData = orderDoc.data() as Map<String, dynamic>;
                      return _buildFeedbackCard(
                        context,
                        orderDoc,
                        orderData,
                        isMobile,
                      );
                    },
                  );
                } else {
                  // Web: Use grid layout with max width constraint
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 1.1,
                            ),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final orderDoc = orders[index];
                          final orderData =
                              orderDoc.data() as Map<String, dynamic>;
                          return _buildFeedbackCard(
                            context,
                            orderDoc,
                            orderData,
                            isMobile,
                          );
                        },
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _deleteRating(
    BuildContext context,
    String orderId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rating'),
        content: const Text(
          'Are you sure you want to delete this customer rating? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final orderService = OrderService();
        await orderService.deleteOrderRating(orderId: orderId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rating deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting rating: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildFeedbackCard(
    BuildContext context,
    QueryDocumentSnapshot orderDoc,
    Map<String, dynamic> orderData,
    bool isMobile,
  ) {
    final orderId = orderDoc.id;
    final rating = (orderData['rating'] as num?)?.toInt() ?? 0;
    final review = orderData['review'] as String? ?? '';
    final fallbackCustomerName =
        orderData['customerName'] as String? ??
        orderData['customer_name'] as String? ??
        'Unknown Customer';
    // Get customerId to fetch profile picture and name
    final customerId = orderData['customerId'] as String?;
    final createdAt = orderData['createdAt'] as Timestamp?;
    final orderDate = createdAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate())
        : 'Unknown date';
    final totalPrice =
        (orderData['totalPrice'] as num?)?.toDouble() ??
        (orderData['price'] as num?)?.toDouble() ??
        0.0;

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with customer info and date
            Row(
              children: [
                // Customer profile picture - fetch from Firestore
                customerId != null && customerId.isNotEmpty
                    ? CustomerProfileAvatar(
                        customerId: customerId,
                        size: isMobile ? 40 : 48,
                      )
                    : CompactProfilePicturePlaceholder(
                        size: isMobile ? 40 : 48,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: customerId != null && customerId.isNotEmpty
                            ? FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(customerId)
                                  .get()
                            : null,
                        builder: (context, snapshot) {
                          String displayName = fallbackCustomerName;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            displayName =
                                (userData?['fullName'] as String?) ??
                                (userData?['name'] as String?) ??
                                (userData?['customerName'] as String?) ??
                                fallbackCustomerName;
                          }
                          return Text(
                            displayName,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        orderDate,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating stars
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: AppColors.primary,
                      size: isMobile ? 18 : 20,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Review text
            if (review.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  review,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Delete rating button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _deleteRating(context, orderId),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Rating'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Order info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  PriceFormatter.formatPrice(totalPrice),
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // View order button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailPage(
                        orderId: orderId,
                        orderRef: FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderId),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View Order Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    Future<void> _enableNotifications() async {
      try {
        await saveFcmToken();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications enabled')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to enable notifications: $e')),
          );
        }
      }
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'Admin',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account Section
            _buildSectionHeader('Account'),
            _buildSettingsTile(
              context,
              icon: Icons.person_outline,
              title: 'Edit Profile',
              subtitle: 'Update your name and email',
              onTap: () {
                _showEditProfileDialog(context);
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              context,
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: () {
                _showChangePasswordDialog(context);
              },
            ),
            const Divider(height: 1),

            // Business Section
            _buildSectionHeader('Business'),
            _buildSettingsTile(
              context,
              icon: Icons.business_outlined,
              title: 'Business Information',
              subtitle: 'Company details and contact info',
              onTap: () {
                _showBusinessInfoDialog(context);
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              context,
              icon: Icons.payment_outlined,
              title: 'Payment Methods',
              subtitle: 'Configure payment settings',
              onTap: () {
                _showPaymentSettingsDialog(context);
              },
            ),
            const Divider(height: 1),

            // System Section
            _buildSectionHeader('System'),
            _buildSettingsTile(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () {
                _showNotificationSettingsDialog(context);
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Enable notifications (this device)',
              subtitle: 'Allow push notifications for your account',
              onTap: _enableNotifications,
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              context,
              icon: Icons.storage_outlined,
              title: 'Data Management',
              subtitle: 'Backup and export data',
              onTap: () {
                _showDataManagementDialog(context);
              },
            ),
            const Divider(height: 1),

            // Security Section
            _buildSectionHeader('Security'),
            _buildSettingsTile(
              context,
              icon: Icons.security_outlined,
              title: 'Security Settings',
              subtitle: 'Two-factor authentication and more',
              onTap: () {
                _showSecuritySettingsDialog(context);
              },
            ),
            const Divider(height: 1),

            // Support Section
            _buildSectionHeader('Support'),
            _buildSettingsTile(
              context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Help & Support'),
                    content: const Text(
                      'For technical support, please contact:\n\nEmail: support@fleximart.com\nPhone: 1-800-FLEXIMART\n\nBusiness Hours: Monday-Friday, 9AM-6PM',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Send Test Push (to me)',
              subtitle: 'Creates a temp order and updates status',
              onTap: () async {
                await _sendTestPush(context);
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              context,
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'App version and information',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About FlexiMart'),
                    content: const Text(
                      'FlexiMart Admin Dashboard\nVersion 1.0.0\n\n© 2024 FlexiMart. All rights reserved.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),

            // Logout Section
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleLogoutFromSettings(context),
                  child: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestPush(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docRef = await FirebaseFirestore.instance.collection('orders').add({
        'customerId': user.uid,
        'customerName': user.displayName ?? 'Test User',
        'customerEmail': user.email ?? '',
        'items': [],
        'totalPrice': 0.0,
        'status': 'pending_payment',
        'paymentMethod': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Trigger status update notification
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(docRef.id)
          .update({
            'status': 'processing',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test push triggered. Check your device.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send test push: $e')));
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load current name from Firestore
    final nameController = TextEditingController();
    final emailController = TextEditingController(text: user.email ?? '');

    // Fetch current name from Firestore
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((
      doc,
    ) {
      if (doc.exists) {
        final userData = doc.data() ?? {};
        final currentName =
            (userData['fullName'] as String?) ??
            (userData['name'] as String?) ??
            (userData['customerName'] as String?) ??
            user.displayName ??
            '';
        nameController.text = currentName;
      } else {
        nameController.text = user.displayName ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                hintText: 'Enter your full name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              enabled: false, // Email cannot be changed directly
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  final newName = nameController.text.trim();
                  // Update Firebase Auth display name
                  await user.updateDisplayName(newName);
                  // Update Firestore with both fullName and name fields
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({'fullName': newName, 'name': newName});
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating profile: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your name'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => obscureCurrent = !obscureCurrent);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => obscureNew = !obscureNew);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => obscureConfirm = !obscureConfirm);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                    ),
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPasswordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully'),
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.code == 'wrong-password'
                            ? 'Current password is incorrect'
                            : 'Error changing password',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBusinessInfoDialog(BuildContext context) {
    final companyNameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final businessHoursController = TextEditingController();
    final taxIdController = TextEditingController();
    bool _loading = false;

    // Load existing data
    FirebaseFirestore.instance
        .collection('business_settings')
        .doc('info')
        .get()
        .then((doc) {
          if (doc.exists) {
            final data = doc.data() ?? {};
            companyNameController.text = data['companyName'] ?? '';
            addressController.text =
                (data['completeAddress'] as String?) ??
                (data['address'] as String?) ??
                '';
            phoneController.text = data['phone'] ?? '';
            emailController.text = data['email'] ?? '';
            businessHoursController.text = data['businessHours'] ?? '';
            taxIdController.text = data['taxId'] ?? '';
          }
        });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Business Information'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: companyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Business Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixText: '+63 ',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Business Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: businessHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Business Hours',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Mon-Fri: 9AM-6PM',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: taxIdController,
                  decoration: const InputDecoration(
                    labelText: 'Tax ID / TIN',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (companyNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Company name is required')),
                  );
                  return;
                }

                setDialogState(() => _loading = true);

                try {
                  await FirebaseFirestore.instance
                      .collection('business_settings')
                      .doc('info')
                      .set({
                        'companyName': companyNameController.text.trim(),
                        'address': addressController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'email': emailController.text.trim(),
                        'businessHours': businessHoursController.text.trim(),
                        'taxId': taxIdController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
                      }, SetOptions(merge: true));

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Business information saved successfully',
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                } finally {
                  setDialogState(() => _loading = false);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSettingsDialog(BuildContext context) {
    bool _gcashEnabled = false;
    bool _paymayaEnabled = false;
    bool _bankTransferEnabled = false;
    bool _cashOnDeliveryEnabled = true;
    final _gcashNumberController = TextEditingController();
    final _paymayaNumberController = TextEditingController();
    final _bankNameController = TextEditingController();
    final _bankAccountController = TextEditingController();
    final _bankAccountNameController = TextEditingController();
    bool _loading = false;

    // Load existing settings
    FirebaseFirestore.instance
        .collection('business_settings')
        .doc('payment')
        .get()
        .then((doc) {
          if (doc.exists) {
            final data = doc.data() ?? {};
            _gcashEnabled = data['gcashEnabled'] ?? false;
            _paymayaEnabled = data['paymayaEnabled'] ?? false;
            _bankTransferEnabled = data['bankTransferEnabled'] ?? false;
            _cashOnDeliveryEnabled = data['cashOnDeliveryEnabled'] ?? true;
            _gcashNumberController.text = data['gcashNumber'] ?? '';
            _paymayaNumberController.text = data['paymayaNumber'] ?? '';
            _bankNameController.text = data['bankName'] ?? '';
            _bankAccountController.text = data['bankAccount'] ?? '';
            _bankAccountNameController.text = data['bankAccountName'] ?? '';
          }
        });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Payment Methods'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('GCash'),
                  subtitle: const Text('Enable GCash payments'),
                  value: _gcashEnabled,
                  onChanged: (value) {
                    setDialogState(() => _gcashEnabled = value);
                  },
                ),
                if (_gcashEnabled) ...[
                  TextField(
                    controller: _gcashNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'GCash Number',
                      border: OutlineInputBorder(),
                      prefixText: '+63 ',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                SwitchListTile(
                  title: const Text('PayMaya'),
                  subtitle: const Text('Enable PayMaya payments'),
                  value: _paymayaEnabled,
                  onChanged: (value) {
                    setDialogState(() => _paymayaEnabled = value);
                  },
                ),
                if (_paymayaEnabled) ...[
                  TextField(
                    controller: _paymayaNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'PayMaya Number',
                      border: OutlineInputBorder(),
                      prefixText: '+63 ',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                SwitchListTile(
                  title: const Text('Bank Transfer'),
                  subtitle: const Text('Enable bank transfer payments'),
                  value: _bankTransferEnabled,
                  onChanged: (value) {
                    setDialogState(() => _bankTransferEnabled = value);
                  },
                ),
                if (_bankTransferEnabled) ...[
                  TextField(
                    controller: _bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., BPI, BDO, Metrobank',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bankAccountController,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bankAccountNameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                SwitchListTile(
                  title: const Text('Cash on Delivery'),
                  subtitle: const Text('Enable COD payments'),
                  value: _cashOnDeliveryEnabled,
                  onChanged: (value) {
                    setDialogState(() => _cashOnDeliveryEnabled = value);
                  },
                ),
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setDialogState(() => _loading = true);

                try {
                  await FirebaseFirestore.instance
                      .collection('business_settings')
                      .doc('payment')
                      .set({
                        'gcashEnabled': _gcashEnabled,
                        'paymayaEnabled': _paymayaEnabled,
                        'bankTransferEnabled': _bankTransferEnabled,
                        'cashOnDeliveryEnabled': _cashOnDeliveryEnabled,
                        'gcashNumber': _gcashNumberController.text.trim(),
                        'paymayaNumber': _paymayaNumberController.text.trim(),
                        'bankName': _bankNameController.text.trim(),
                        'bankAccount': _bankAccountController.text.trim(),
                        'bankAccountName': _bankAccountNameController.text
                            .trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
                      }, SetOptions(merge: true));

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment settings saved successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                } finally {
                  setDialogState(() => _loading = false);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettingsDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool _emailNotifications = true;
    bool _pushNotifications = true;
    bool _newOrderAlerts = true;
    bool _lowStockAlerts = true;
    bool _paymentAlerts = true;
    bool _customerFeedbackAlerts = true;

    // Load existing settings
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((
      doc,
    ) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        _emailNotifications = data['admin_emailNotifications'] ?? true;
        _pushNotifications = data['admin_pushNotifications'] ?? true;
        _newOrderAlerts = data['admin_newOrderAlerts'] ?? true;
        _lowStockAlerts = data['admin_lowStockAlerts'] ?? true;
        _paymentAlerts = data['admin_paymentAlerts'] ?? true;
        _customerFeedbackAlerts = data['admin_customerFeedbackAlerts'] ?? true;
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notification Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'General Notifications',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive notifications via email'),
                  value: _emailNotifications,
                  onChanged: (value) {
                    setDialogState(() => _emailNotifications = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'admin_emailNotifications': value});
                  },
                ),
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive push notifications'),
                  value: _pushNotifications,
                  onChanged: (value) {
                    setDialogState(() => _pushNotifications = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'admin_pushNotifications': value});
                  },
                ),
                const Divider(),
                const Text(
                  'Alert Types',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('New Order Alerts'),
                  subtitle: const Text('Notify when new orders are placed'),
                  value: _newOrderAlerts,
                  onChanged: (value) {
                    setDialogState(() => _newOrderAlerts = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'admin_newOrderAlerts': value});
                  },
                ),
                SwitchListTile(
                  title: const Text('Low Stock Alerts'),
                  subtitle: const Text('Notify when products are low in stock'),
                  value: _lowStockAlerts,
                  onChanged: (value) {
                    setDialogState(() => _lowStockAlerts = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'admin_lowStockAlerts': value});
                  },
                ),
                SwitchListTile(
                  title: const Text('Payment Alerts'),
                  subtitle: const Text('Notify when payments are received'),
                  value: _paymentAlerts,
                  onChanged: (value) {
                    setDialogState(() => _paymentAlerts = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'admin_paymentAlerts': value});
                  },
                ),
                SwitchListTile(
                  title: const Text('Customer Feedback Alerts'),
                  subtitle: const Text('Notify when customers leave feedback'),
                  value: _customerFeedbackAlerts,
                  onChanged: (value) {
                    setDialogState(() => _customerFeedbackAlerts = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'admin_customerFeedbackAlerts': value});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDataManagementDialog(BuildContext context) {
    bool _exporting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Data Management'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _exporting
                      ? null
                      : () async {
                          setDialogState(() => _exporting = true);
                          try {
                            // Export products
                            final productsSnapshot = await FirebaseFirestore
                                .instance
                                .collection('products')
                                .get();

                            // Export orders
                            final ordersSnapshot = await FirebaseFirestore
                                .instance
                                .collection('orders')
                                .get();

                            // Export users
                            final usersSnapshot = await FirebaseFirestore
                                .instance
                                .collection('users')
                                .get();

                            // Create export data
                            final List<Map<String, dynamic>> productsList = [];
                            for (var doc in productsSnapshot.docs) {
                              final data = Map<String, dynamic>.from(
                                doc.data(),
                              );
                              data['id'] = doc.id;
                              productsList.add(data);
                            }

                            final List<Map<String, dynamic>> ordersList = [];
                            for (var doc in ordersSnapshot.docs) {
                              final data = Map<String, dynamic>.from(
                                doc.data(),
                              );
                              data['id'] = doc.id;
                              ordersList.add(data);
                            }

                            final List<Map<String, dynamic>> usersList = [];
                            for (var doc in usersSnapshot.docs) {
                              final data = Map<String, dynamic>.from(
                                doc.data(),
                              );
                              data['id'] = doc.id;
                              // Remove sensitive data
                              data.remove('password');
                              usersList.add(data);
                            }

                            final exportData = {
                              'exportDate': DateTime.now().toIso8601String(),
                              'products': productsList,
                              'orders': ordersList,
                              'users': usersList,
                              'summary': {
                                'totalProducts': productsSnapshot.docs.length,
                                'totalOrders': ordersSnapshot.docs.length,
                                'totalUsers': usersSnapshot.docs.length,
                              },
                            };

                            // Save to Firestore for download
                            await FirebaseFirestore.instance
                                .collection('exports')
                                .add({
                                  'exportData': exportData,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'createdBy':
                                      FirebaseAuth.instance.currentUser?.uid,
                                  'type': 'full_export',
                                });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Export completed! ${productsSnapshot.docs.length} products, ${ordersSnapshot.docs.length} orders, ${usersSnapshot.docs.length} users exported.',
                                  ),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error exporting data: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => _exporting = false);
                          }
                        },
                  icon: _exporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_exporting ? 'Exporting...' : 'Export All Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Database Statistics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, int>>(
                future: _getDatabaseStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stats = snapshot.data ?? {};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow('Total Products', stats['products'] ?? 0),
                      _buildStatRow('Total Orders', stats['orders'] ?? 0),
                      _buildStatRow('Total Users', stats['users'] ?? 0),
                      _buildStatRow('Total Staff', stats['staff'] ?? 0),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, int>> _getDatabaseStats() async {
    final productsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .get();
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .get();
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    final staffSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .get();

    return {
      'products': productsSnapshot.docs.length,
      'orders': ordersSnapshot.docs.length,
      'users': usersSnapshot.docs.length,
      'staff': staffSnapshot.docs.length,
    };
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSecuritySettingsDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool _twoFactorEnabled = false;
    bool _sessionTimeoutEnabled = true;
    int _sessionTimeoutMinutes = 30;
    bool _requirePasswordForSensitiveActions = true;
    bool _loginAlerts = true;

    // Load existing settings
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((
      doc,
    ) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        _twoFactorEnabled = data['security_twoFactorEnabled'] ?? false;
        _sessionTimeoutEnabled = data['security_sessionTimeoutEnabled'] ?? true;
        _sessionTimeoutMinutes = data['security_sessionTimeoutMinutes'] ?? 30;
        _requirePasswordForSensitiveActions =
            data['security_requirePasswordForSensitiveActions'] ?? true;
        _loginAlerts = data['security_loginAlerts'] ?? true;
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Security Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Two-Factor Authentication'),
                  subtitle: const Text(
                    'Require additional verification for login',
                  ),
                  value: _twoFactorEnabled,
                  onChanged: (value) {
                    setDialogState(() => _twoFactorEnabled = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'security_twoFactorEnabled': value});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? 'Two-factor authentication enabled'
                              : 'Two-factor authentication disabled',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Session Timeout'),
                  subtitle: const Text(
                    'Automatically log out after inactivity',
                  ),
                  value: _sessionTimeoutEnabled,
                  onChanged: (value) {
                    setDialogState(() => _sessionTimeoutEnabled = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'security_sessionTimeoutEnabled': value});
                  },
                ),
                if (_sessionTimeoutEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timeout: $_sessionTimeoutMinutes minutes',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        Slider(
                          value: _sessionTimeoutMinutes.toDouble(),
                          min: 5,
                          max: 120,
                          divisions: 23,
                          label: '$_sessionTimeoutMinutes minutes',
                          onChanged: (value) {
                            setDialogState(() {
                              _sessionTimeoutMinutes = value.toInt();
                            });
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({
                                  'security_sessionTimeoutMinutes': value
                                      .toInt(),
                                });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(),
                SwitchListTile(
                  title: const Text('Password for Sensitive Actions'),
                  subtitle: const Text(
                    'Require password confirmation for critical operations',
                  ),
                  value: _requirePasswordForSensitiveActions,
                  onChanged: (value) {
                    setDialogState(() {
                      _requirePasswordForSensitiveActions = value;
                    });
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                          'security_requirePasswordForSensitiveActions': value,
                        });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Login Alerts'),
                  subtitle: const Text(
                    'Receive notifications for new login attempts',
                  ),
                  value: _loginAlerts,
                  onChanged: (value) {
                    setDialogState(() => _loginAlerts = value);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'security_loginAlerts': value});
                  },
                ),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Recent Login Activity'),
                          content: const Text(
                            'This feature will show your recent login history including device, location, and time.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('View Login History'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogoutFromSettings(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      // Log logout activity before signing out
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userName =
                (userData['name'] as String?) ??
                (userData['fullName'] as String?) ??
                (userData['customerName'] as String?) ??
                (userData['email'] as String?) ??
                'Unknown User';

            await FirebaseFirestore.instance.collection('activity_logs').add({
              'userId': user.uid,
              'userName': userName,
              'actionType': 'Logout',
              'description': 'User logged out',
              'timestamp': FieldValue.serverTimestamp(),
              'metadata': {
                'role': userData['role'] as String? ?? 'unknown',
                'logoutTime': DateTime.now().toIso8601String(),
              },
            });
          }
        }
      } catch (e) {
        // Don't fail logout if activity logging fails
        if (kDebugMode) {
          debugPrint('Error logging logout activity: $e');
        }
      }

      try {
        // Try provider signOut first (clears app state)
        await context.read<app_auth.AuthProvider>().signOut();
      } catch (_) {
        // Fallback to direct Firebase signOut
        await FirebaseAuth.instance.signOut();
      }
      if (!context.mounted) return;
      // Ensure stack is cleared to prevent back navigation into admin
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}

// Admin Messages Page
class _AdminMessagesPage extends StatelessWidget {
  const _AdminMessagesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Customer Messages',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ),

          // Chat List
          Expanded(child: ChatListPage(showBackButton: false)),
        ],
      ),
    );
  }
}
