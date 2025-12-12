import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import '../utils/image_url_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../constants/app_colors.dart';
import '../utils/fcm_utils.dart';
import '../utils/dashboard_theme.dart';
import 'staff_quotation_list_page.dart';
import '../pages/order_detail_page.dart';
import '../pages/chat_list_page.dart';
import '../utils/price_formatter.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../utils/role_helper.dart';
import '../widgets/map_coming_soon_placeholder.dart';
import '../widgets/customer_profile_avatar.dart';

// Official theme colors - Staff Theme (Bright Red)
// Staff uses brighter, more vibrant red palette to differentiate from admin's deeper wine red
class StaffThemeColors {
  StaffThemeColors._();
  // Dark maroon palette (matching admin theme)
  static const Color primaryRed = Color(0xFF8B2E2E); // Dark maroon
  static const Color deepRed = Color(0xFF6B1F1F); // Darker maroon
  static const Color darkRed = Color(0xFF4A1515); // Darkest maroon

  // Navigation colors
  static const Color navActive = Color(0xFF8B2E2E);
  static const Color navActiveBg = Color(
    0x426B1F1F,
  ); // Dark maroon with opacity

  // Legacy names for compatibility
  static const Color crimsonRed = Color(0xFF8B2E2E);
  static const Color deepBerryRed = Color(0xFF6B1F1F);
  static const Color darkWinePurple = Color(0xFF4A1515);

  // Alias for primary
  static const Color primaryBlue = Color(0xFF8B2E2E); // Keep for compatibility
}

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
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

      if (role != 'staff') {
        if (mounted) {
          setState(() {
            _isCheckingRole = false;
            _errorMessage =
                'Access denied. Staff dashboard requires staff role, but your role is: $role';
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
    {'icon': Icons.shopping_bag_outlined, 'label': 'Orders'},
    {'icon': Icons.description_outlined, 'label': 'Quotations'},
    {'icon': Icons.chat_bubble_outline, 'label': 'Messages'},
    {'icon': Icons.feedback_outlined, 'label': 'Feedback'},
    {'icon': Icons.settings_outlined, 'label': 'Settings'},
  ];

  final List<Widget> _pages = [
    const _StaffDashboardPage(),
    const _ProductsViewPage(),
    const _StaffPosPage(),
    const _OrdersViewPage(),
    const StaffQuotationListPage(),
    const ChatListPage(showBackButton: false),
    const _FeedbackSupportPage(),
    const _StaffProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Check role before loading dashboard
    if (_isCheckingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show error if role is invalid
    if (_errorMessage != null || _userRole != 'staff') {
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
                      'Access denied. Staff dashboard requires staff role.',
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
    final isMobileLayout =
        screenWidth < 900; // Increased from 768 to prevent flickering
    final isWebLayout = !isMobileLayout;

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      appBar: isMobileLayout ? _buildMobileAppBar(context) : null,
      drawer: isMobileLayout ? _buildMobileDrawer(context) : null,
      body: isWebLayout
          ? SafeArea(
              child: Row(
                children: [
                  _buildSidebar(context, isWebLayout),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
            )
          : SafeArea(bottom: true, child: _pages[_selectedIndex]),
    );
  }

  /// Simple logout handler for the main StaffDashboard (mobile app bar menu).
  void _handleLogout(BuildContext context) async {
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
          final userName = (userData['name'] as String?) ??
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
    
    await context.read<app_auth.AuthProvider>().signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  PreferredSizeWidget? _buildMobileAppBar(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8B2E2E), // Dark maroon
              Color(0xFF6B1F1F), // Darker maroon
              Color(0xFF4A1515), // Darkest maroon
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ),
      elevation: 0,
      title: const Text(
        'Staff Dashboard',
        style: DashboardTheme.titleTextStyle,
      ),
      actions: [
        if (user != null)
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.white,
              child: Text(
                user.email?.substring(0, 1).toUpperCase() ?? 'S',
                style: const TextStyle(
                  color: StaffThemeColors.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'logout', child: const Text('Logout')),
            ],
          ),
      ],
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
            Color(0xFF8B2E2E), // Dark maroon start
            Color(0xFF4A1515), // Darkest maroon end
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
          children: [
            // Enhanced Header with Logo and Collapse Button
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
            'Staff';
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
                  backgroundColor: StaffThemeColors.primaryRed,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
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

  Widget? _buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8B2E2E), // Dark maroon start
              Color(0xFF4A1515), // Darkest maroon end
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
            'Staff';
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
                  backgroundColor: StaffThemeColors.primaryRed,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
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
            mainAxisSize: MainAxisSize.min,
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

// ==================== STAFF DASHBOARD PAGE ====================
class _StaffDashboardPage extends StatelessWidget {
  const _StaffDashboardPage();

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header with Gradient - Matching Admin Design
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              return Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF8B2E2E), // Bright coral red
                      Color(0xFF6B1F1F), // Darker maroon
                      Color(0xFF4A1515), // Darkest maroon
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
                        Icons.dashboard_customize,
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
                            'Staff Dashboard',
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
          // Quick Stats Cards - Now with real data
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, ordersSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (context, productsSnapshot) {
                  double todaySales = 0;
                  int todayOrders = 0;
                  int pendingOrders = 0;
                  int lowStockCount = 0;

                  final today = DateTime.now();
                  final todayStart = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );

                  if (ordersSnapshot.hasData) {
                    final orders = ordersSnapshot.data!.docs;
                    for (var order in orders) {
                      final data = order.data() as Map<String, dynamic>;
                      final status = (data['status'] as String?) ?? 'pending';

                      if (status == 'pending') {
                        pendingOrders++;
                      }

                      final createdAt = data['createdAt'] as Timestamp?;
                      if (createdAt != null) {
                        final orderDate = createdAt.toDate();
                        if (orderDate.isAfter(todayStart)) {
                          todayOrders++;
                          todaySales +=
                              (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
                        }
                      }
                    }
                  }

                  if (productsSnapshot.hasData) {
                    final products = productsSnapshot.data!.docs;
                    for (var product in products) {
                      final data = product.data() as Map<String, dynamic>;
                      final stock = (data['stock'] as num?)?.toInt() ?? 0;
                      final minStock =
                          (data['minStock'] as num?)?.toInt() ?? 10;
                      if (stock < minStock) {
                        lowStockCount++;
                      }
                    }
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 1200;
                      final isMedium = constraints.maxWidth > 800;
                      final cardWidth = isWide
                          ? (constraints.maxWidth - 64) / 3
                          : isMedium
                          ? (constraints.maxWidth - 48) / 2
                          : constraints.maxWidth - 32;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _StaffKpiCard(
                            title: 'Today\'s Sales',
                            value: '₱${_formatNumber(todaySales)}',
                            subtitle: '$todayOrders orders',
                            icon: Icons.today_outlined,
                            color: StaffThemeColors.darkWinePurple,
                            width: cardWidth,
                          ),
                          _StaffKpiCard(
                            title: 'Pending Orders',
                            value: pendingOrders.toString(),
                            subtitle: 'Need attention',
                            icon: Icons.pending_actions_outlined,
                            color: StaffThemeColors.primaryRed,
                            width: cardWidth,
                          ),
                          _StaffKpiCard(
                            title: 'Low Stock',
                            value: lowStockCount.toString(),
                            subtitle: 'Items need restocking',
                            icon: Icons.warning_amber_rounded,
                            color: StaffThemeColors.deepBerryRed,
                            width: cardWidth,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          // Tasks Section
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1200;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StaffPanel(
                    width: isWide
                        ? (constraints.maxWidth - 64) / 2
                        : constraints.maxWidth - 32,
                    title: 'Recent Tasks',
                    icon: Icons.task_alt,
                    child: const _RecentTasksList(),
                  ),
                  _StaffPanel(
                    width: isWide
                        ? (constraints.maxWidth - 64) / 2
                        : constraints.maxWidth - 32,
                    title: 'Low Stock Alerts',
                    icon: Icons.warning_amber_rounded,
                    child: const _LowStockAlertsList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StaffKpiCard extends StatelessWidget {
  const _StaffKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.width,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // White card background
          borderRadius: BorderRadius.circular(20), // 20px rounded corners
          border: Border.all(
            color: const Color(
              0xFF8B2E2E,
            ).withOpacity(0.3), // Bright red border matching theme
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1), // Light bubble background
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(
                          0xFF1D3B53,
                        ), // Dark blue for better readability
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
                        color: Color(0xFF8B2E2E), // Dark maroon color for staff
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(
                          0xFF1D3B53,
                        ).withOpacity(0.9), // Darker for better readability
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffPanel extends StatelessWidget {
  const _StaffPanel({
    required this.title,
    required this.child,
    required this.width,
    required this.icon,
  });

  final String title;
  final Widget child;
  final double width;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(
              0xFF8B2E2E,
            ).withOpacity(0.3), // Bright red border matching theme
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B2E2E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(
                        0xFF8B2E2E,
                      ), // Bright red icon for staff
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

class _RecentTasksList extends StatelessWidget {
  const _RecentTasksList();

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Error loading recent orders: ${snapshot.error}');
          // Try without orderBy if index is missing
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
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
              return _buildOrdersList(orders.take(5).toList());
            },
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final orders = snapshot.data!.docs;
        return _buildOrdersList(orders);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent orders',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<QueryDocumentSnapshot> orders) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final orderDoc = orders[index];
        final order = orderDoc.data() as Map<String, dynamic>;
        final status = (order['status'] as String?) ?? 'pending';
        final createdAt = order['createdAt'] as Timestamp?;
        final orderId = orderDoc.id.length >= 8
            ? orderDoc.id.substring(0, 8)
            : orderDoc.id;

        IconData icon;
        Color color;
        String text;

        switch (status.toLowerCase()) {
          case 'completed':
            icon = Icons.check_circle;
            color = AppColors.success;
            text = 'Order #$orderId marked as delivered';
            break;
          case 'shipped':
            icon = Icons.local_shipping;
            color = StaffThemeColors.primaryRed;
            text = 'Order #$orderId is shipped';
            break;
          case 'processing':
            icon = Icons.inventory_2;
            color = AppColors.accent;
            text = 'Order #$orderId is being processed';
            break;
          default:
            icon = Icons.pending;
            color = AppColors.accent;
            text = 'Order #$orderId is pending';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt != null ? _getTimeAgo(createdAt) : 'Just now',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LowStockAlertsList extends StatelessWidget {
  const _LowStockAlertsList();

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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All products well stocked',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All products well stocked',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: lowStockItems.length,
          itemBuilder: (context, index) {
            final item = lowStockItems[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stock: ${item['stock']} (Min: ${item['min']})',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Contact admin for ${item['name']}'),
                        ),
                      );
                    },
                    child: const Text('Contact Admin'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== PRODUCTS MANAGEMENT PAGE ====================
class _ProductsViewPage extends StatefulWidget {
  const _ProductsViewPage();

  @override
  State<_ProductsViewPage> createState() => _ProductsViewPageState();
}

class _ProductsViewPageState extends State<_ProductsViewPage> {
  String _filterCategory = 'all';
  String _filterStock = 'all'; // all, low, normal
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                                'Product Management',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (!isMobile) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Add, view, and manage products',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Add Product button hidden for staff (view-only)
                        const SizedBox.shrink(),
                      ],
                    ),
                    // Add Product button hidden for staff (view-only)
                    const SizedBox.shrink(),
                    const SizedBox(height: 16),
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.dashboardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: AppColors.textSecondary,
                                  ),
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
                            horizontal: 16,
                            vertical: 12,
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
                                      value: 'Glass',
                                      child: Text('Glass'),
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
                                      value: 'Glass',
                                      child: Text('Glass'),
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
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading products: ${snapshot.error}'),
                  );
                }

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
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        // Add Product button hidden for staff (view-only)
                        const SizedBox.shrink(),
                      ],
                    ),
                  );
                }

                var products = snapshot.data!.docs;

                // Apply filters
                products = products.where((doc) {
                  final product = doc.data() as Map<String, dynamic>;

                  // Category filter
                  if (_filterCategory != 'all') {
                    if (product['category'] != _filterCategory) return false;
                  }

                  // Stock filter
                  if (_filterStock != 'all') {
                    final stock = (product['stock'] as num?)?.toInt() ?? 0;
                    final minStock =
                        (product['minStock'] as num?)?.toInt() ?? 10;
                    if (_filterStock == 'low' && stock >= minStock)
                      return false;
                    if (_filterStock == 'normal' && stock < minStock)
                      return false;
                  }

                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    final title =
                        ((product['name'] as String?) ??
                                (product['title'] as String?) ??
                                '')
                            .toLowerCase();
                    final query = _searchQuery.toLowerCase();
                    if (!title.contains(query)) return false;
                  }

                  return true;
                }).toList();

                final isMobile = MediaQuery.of(context).size.width < 768;
                final isTablet =
                    MediaQuery.of(context).size.width < 1024 && !isMobile;

                if (isMobile) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final productDoc = products[index];
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

                // Web/Tablet Grid Layout
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 2 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final productDoc = products[index];
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
    required bool isMobile,
  }) {
    // Use 'name' field first, fallback to 'title' for backward compatibility
    final title =
        product['name'] as String? ?? product['title'] as String? ?? 'Unknown';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    final minStock = (product['minStock'] as num?)?.toInt() ?? 10;
    final category = product['category'] as String? ?? 'Uncategorized';
    final imageUrl = product['imageUrl'] as String?;
    final isLowStock = stock < minStock;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          AspectRatio(
            aspectRatio: 1.5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      ImageUrlHelper.encodeUrl(imageUrl),
                      fit: BoxFit.cover,
                      cacheWidth: kIsWeb ? null : 400,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.border,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.border,
                        child: Icon(
                          Icons.image_not_supported,
                          color: AppColors.textSecondary,
                        ),
                      ),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: StaffThemeColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12, // Increased for clarity
                          color: StaffThemeColors.primaryRed,
                          fontWeight: FontWeight.w600,
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
                        color: StaffThemeColors.primaryRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: StaffThemeColors.primaryRed.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 12,
                            color: StaffThemeColors.primaryRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$soldCount sold',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: StaffThemeColors.primaryRed,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      PriceFormatter.formatPrice(price),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: StaffThemeColors.primaryRed,
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
                // Action buttons hidden for staff (view-only)
                const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffPosPage extends StatelessWidget {
  const _StaffPosPage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            if (kDebugMode) {
              print('⚠️ OrderBy failed, using simple query: $error');
            }
            return FirebaseFirestore.instance.collection('orders').snapshots();
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading transactions',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Refresh by rebuilding
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StaffThemeColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
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

        final allOrders = snapshot.data!.docs;

        // Sort manually by createdAt if orderBy failed
        final orders = List<QueryDocumentSnapshot>.from(allOrders);
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

        return LayoutBuilder(
          builder: (context, constraints) {
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
                      final customerName = data['customerName'] ?? 'Unknown';
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
                      if (totalPrice == null) {
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
                      }

                      final totalAmount = (totalPrice ?? computedTotal) as num;
                      final status = (data['status'] as String? ?? 'Pending')
                          .toString();
                      final createdAt = data['createdAt'];

                      String formattedDate = 'N/A';
                      if (createdAt != null) {
                        try {
                          final timestamp = createdAt as Timestamp;
                          final date = timestamp.toDate();
                          formattedDate =
                              '${date.day}/${date.month}/${date.year}';
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order ID: ${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          customerName,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
            onPressed: () => _updateStatus(context, orderRef, 'Processing'),
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
        return StaffThemeColors.primaryRed;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _OrdersViewPage extends StatefulWidget {
  const _OrdersViewPage();

  @override
  State<_OrdersViewPage> createState() => _OrdersViewPageState();
}

class _OrdersViewPageState extends State<_OrdersViewPage> {
  String _filterStatus = 'all';

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterStatus,
                      decoration: InputDecoration(
                        labelText: 'Filter by Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Orders'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'processing',
                          child: Text('Processing'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                        DropdownMenuItem(
                          value: 'delivered',
                          child: Text('Delivered'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterStatus = value ?? 'all';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapComingSoonPlaceholder(
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
                      backgroundColor: StaffThemeColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Orders List
            Expanded(child: _buildOrdersList(context)),
          ],
        );
      },
    );
  }

  Widget _buildOrdersList(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (_filterStatus != 'all') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots().handleError((error) {
        if (kDebugMode) {
          print('⚠️ OrderBy failed, using simple query: $error');
        }
        // Fallback to simple query without orderBy
        Query fallbackQuery = FirebaseFirestore.instance.collection('orders');
        if (_filterStatus != 'all') {
          fallbackQuery = fallbackQuery.where(
            'status',
            isEqualTo: _filterStatus,
          );
        }
        return fallbackQuery.snapshots();
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading orders',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        // Refresh by rebuilding
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StaffThemeColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
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

        final allOrders = snapshot.data!.docs;
        final isMobile = MediaQuery.of(context).size.width < 768;

        // Sort manually by createdAt if orderBy failed
        final orders = List<QueryDocumentSnapshot>.from(allOrders);
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final order = orderDoc.data() as Map<String, dynamic>;
            return _buildOrderCard(
              context,
              orderDoc.id,
              order,
              isMobile: isMobile,
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
    final items = (order['items'] as List<dynamic>?) ?? [];

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

          total += price * quantity;
        }
      }
    }

    final customerName = (order['customerName'] as String?) ?? 'Unknown';
    final createdAt = order['createdAt'] as Timestamp?;

    Color statusColor = AppColors.textSecondary;
    IconData statusIcon = Icons.pending;
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = AppColors.accent;
        statusIcon = Icons.pending;
        break;
      case 'processing':
        statusColor = AppColors.primary;
        statusIcon = Icons.build;
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'delivered':
        statusColor = AppColors.success;
        statusIcon = Icons.inventory_2;
        break;
    }

    return InkWell(
      onTap: () {
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
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    PriceFormatter.formatPrice(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Order #${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: $customerName',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Date: ${createdAt.toDate().toString().substring(0, 16)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${items.length} item${items.length != 1 ? 's' : ''}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              // View Map button (if coordinates exist)
              if (order['latitude'] != null && order['longitude'] != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                    ),
                  ),
                ),
              if (order['latitude'] != null && order['longitude'] != null)
                const SizedBox(height: 8),
              if (status != 'delivered' && status != 'completed')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _updateOrderStatus(context, orderId, order),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Update Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StaffThemeColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

class _FeedbackSupportPage extends StatelessWidget {
  const _FeedbackSupportPage();

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
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
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
                  color: StaffThemeColors.primaryRed,
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

                return ListView.builder(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _deleteRating(BuildContext context, String orderId) async {
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
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
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
    final customerName =
        orderData['customerName'] as String? ??
        orderData['customer_name'] as String? ??
        'Unknown Customer';
    // Get customerId to fetch profile picture
    final customerId = orderData['customerId'] as String?;
    final createdAt = orderData['createdAt'] as Timestamp?;
    final orderDate = createdAt != null
        ? '${createdAt.toDate().toString().substring(0, 16)}'
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
                    : CircleAvatar(
                        radius: isMobile ? 20 : 24,
                        backgroundColor: StaffThemeColors.primaryBlue
                            .withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          size: isMobile ? 20 : 24,
                          color: StaffThemeColors.primaryRed,
                        ),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
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
                      color: StaffThemeColors.primaryRed,
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
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                ),
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
                    color: StaffThemeColors.primaryRed,
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
                  foregroundColor: StaffThemeColors.primaryBlue,
                  side: const BorderSide(color: StaffThemeColors.primaryBlue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffProfilePage extends StatelessWidget {
  const _StaffProfilePage();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: StaffThemeColors.primaryRed,
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
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: user != null
                          ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        return Column(
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
                              user?.email ?? 'No email',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account Information Section
            _buildSectionHeader('Account Information'),
            StreamBuilder<DocumentSnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = snapshot.hasData && snapshot.data!.exists
                    ? snapshot.data!.data() as Map<String, dynamic>?
                    : null;
                final fullName = (userData?['fullName'] as String?) ?? '';
                final email = user?.email ?? 'No email';
                final phone =
                    (userData?['phone'] as String?) ?? 'No phone number';
                final salary = (userData?['salary'] as num?)?.toDouble();
                final salaryBalance =
                    (userData?['salaryBalance'] as num?)?.toDouble() ?? 0.0;

                return Column(
                  children: [
                    _buildInfoCard(
                      icon: Icons.person_outline,
                      title: 'Full Name',
                      value: fullName.isNotEmpty ? fullName : 'Not set',
                    ),
                    Divider(
                      height: 1,
                      color: const Color(0xFFCD5656).withOpacity(0.8),
                    ),
                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: email,
                    ),
                    Divider(
                      height: 1,
                      color: const Color(0xFFCD5656).withOpacity(0.8),
                    ),
                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      title: 'Phone Number',
                      value: phone,
                    ),
                    if (salary != null) ...[
                      Divider(
                        height: 1,
                        color: const Color(0xFFCD5656).withOpacity(0.8),
                      ),
                      _buildInfoCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Monthly Salary',
                        value: PriceFormatter.formatPrice(salary),
                        color: AppColors.success,
                      ),
                    ],
                    if (salaryBalance != 0.0) ...[
                      Divider(
                        height: 1,
                        color: const Color(0xFFCD5656).withOpacity(0.8),
                      ),
                      _buildInfoCard(
                        icon: Icons.savings_outlined,
                        title: 'Salary Balance',
                        value: PriceFormatter.formatPrice(salaryBalance),
                        color: salaryBalance > 0
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Account Actions Section
            _buildSectionHeader('Account Actions'),
            _buildSettingsTile(
              context,
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              subtitle: 'Update your name and phone number',
              onTap: () {
                _showEditProfileDialog(context);
              },
            ),
            Divider(height: 1, color: const Color(0xFFCD5656).withOpacity(0.8)),
            _buildSettingsTile(
              context,
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: () {
                _showChangePasswordDialog(context);
              },
            ),
            Divider(height: 1, color: const Color(0xFFCD5656).withOpacity(0.8)),

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
                      'For support, please contact:\n\nEmail: support@fleximart.com\nPhone: 1-800-FLEXIMART\n\nBusiness Hours: Monday-Friday, 9AM-6PM',
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
            Divider(height: 1, color: const Color(0xFFCD5656).withOpacity(0.8)),
            _buildSettingsTile(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Enable notifications (this device)',
              subtitle: 'Allow push notifications for your account',
              onTap: () async {
                try {
                  await saveFcmToken();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications enabled')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to enable notifications: $e'),
                    ),
                  );
                }
              },
            ),
            Divider(height: 1, color: const Color(0xFFCD5656).withOpacity(0.8)),
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
                      'FlexiMart Staff Dashboard\nVersion 1.0.0\n\n© 2024 FlexiMart. All rights reserved.',
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
            Divider(height: 1, color: const Color(0xFFCD5656).withOpacity(0.8)),

            // Logout Section
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleLogout(context),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.textPrimary,
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
      leading: Icon(icon, color: StaffThemeColors.primaryBlue),
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

    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    // Load existing data
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((
      doc,
    ) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        nameController.text = data['fullName'] ?? '';
        phoneController.text = data['phone'] ?? '';
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await user.updateDisplayName(nameController.text.trim());
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({
                      'fullName': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
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
        builder: (context, setDialogState) => AlertDialog(
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
                        setDialogState(() => obscureCurrent = !obscureCurrent);
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
                        setDialogState(() => obscureNew = !obscureNew);
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
                        setDialogState(() => obscureConfirm = !obscureConfirm);
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
                        backgroundColor: AppColors.success,
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
                      backgroundColor: AppColors.error,
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

  void _handleLogout(BuildContext context) async {
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
            final userName = (userData['name'] as String?) ??
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
      
      await context.read<app_auth.AuthProvider>().signOut();
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
