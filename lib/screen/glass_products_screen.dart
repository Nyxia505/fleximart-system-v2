import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../constants/app_colors.dart';
import '../utils/price_formatter.dart';
import '../utils/image_url_helper.dart';

class GlassProductsScreen extends StatefulWidget {
  const GlassProductsScreen({super.key});

  @override
  State<GlassProductsScreen> createState() => _GlassProductsScreenState();
}

class _GlassProductsScreenState extends State<GlassProductsScreen> {
  int _currentNavIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Installation Services
  final List<Map<String, dynamic>> _services = [
    {
      'name': 'Sliding Window\nInstallation',
      'rating': 4.8,
      'reviews': 234,
      'price': 1500.00,
      'image':
          'https://images.unsplash.com/photo-1565183928294-7d22f2a37f14?w=400',
      'category': 'Windows',
    },
    {
      'name': 'Screen Door\nInstallation',
      'rating': 4.9,
      'reviews': 320,
      'price': 1200.00,
      'image':
          'https://images.unsplash.com/photo-1540518614846-7eded433c457?w=400',
      'category': 'Doors',
    },
    {
      'name': 'Jalousie Window\nSetup',
      'rating': 4.7,
      'reviews': 198,
      'price': 1800.00,
      'image':
          'https://images.unsplash.com/photo-1565183928294-7d22f2a37f14?w=400',
      'category': 'Windows',
    },
    {
      'name': 'Fixed Glass\nInstallation',
      'rating': 4.9,
      'reviews': 412,
      'price': 2200.00,
      'image':
          'https://images.unsplash.com/photo-1540518614846-7eded433c457?w=400',
      'category': 'Glass',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Green Header Section
            _buildGreenHeader(),

            // White Content Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Categories
                      _buildCategories(),
                      const SizedBox(height: 20),
                      // Promo Banner
                      _buildPromoBanner(),
                      const SizedBox(height: 20),
                      // Top Picks
                      _buildTopPicks(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildGreenHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notification Icon (Top Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.pushNamed(context, '/dashboard');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Search Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(50),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'What type of installation do you need?',
                hintStyle: const TextStyle(
                  color: Color(0xFF4A6B7F), // Darker for better readability
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: const Color(0xFF1D3B53), // Dark blue for better contrast
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = [
      {'name': 'Jalousie', 'icon': Icons.view_day},
      {'name': 'Sliding\nWin...', 'icon': Icons.window},
      {'name': 'Screen\nDoor', 'icon': Icons.door_front_door},
      {'name': 'Fixed\nGlass', 'icon': Icons.crop_square},
      {'name': 'See All', 'icon': Icons.grid_view},
    ];

    return SizedBox(
      height: 95,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    cat['icon'] as IconData,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cat['name'] as String,
                  style: const TextStyle(
                    fontSize: 12, // Increased for clarity
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background image (right side)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Image.network(
                ImageUrlHelper.encodeUrl('https://images.unsplash.com/photo-1540518614846-7eded433c457?w=400'),
                width: 160,
                fit: BoxFit.cover,
                cacheWidth: kIsWeb ? null : 320,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 160,
                    color: AppColors.primary,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    Container(width: 160, color: AppColors.primary),
              ),
            ),
          ),
          // Text content (left side)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Up to 30% off\non screen doors!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Professional installation,\nfast and affordable.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    'ORDER NOW',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12, // Increased for clarity
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPicks() {
    // Filter services by search query
    final displayServices = _searchQuery.isEmpty
        ? _services
        : _services.where((service) {
            final name = (service['name'] as String).toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Top Picks for You',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
        ),
        const SizedBox(height: 16),
        displayServices.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No services match "$_searchQuery"',
                        style: const TextStyle(color: Color(0xFF1D3B53)), // Dark blue for better contrast
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: displayServices.length,
                  itemBuilder: (context, index) {
                    return _buildServiceCard(displayServices[index]);
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Container(
      width: 190,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              ImageUrlHelper.encodeUrl(service['image'] as String),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheHeight: kIsWeb ? null : 240,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 120,
                  color: Colors.grey[200],
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
                height: 120,
                color: Colors.grey[200],
                child: Icon(Icons.window, size: 40, color: Colors.grey[400]),
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['name'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFC107), size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '${service['rating']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '(${service['reviews']})',
                      style: TextStyle(
                        fontSize: 12, // Increased for clarity
                        color: const Color(0xFF1D3B53), // Dark blue for better contrast
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  PriceFormatter.formatPrice((service['price'] as double)),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _bookService(service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'ORDER NOW',
                      style: TextStyle(
                        fontSize: 12, // Increased for clarity
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0, isActive: true),
              _buildNavItem(Icons.receipt_long_outlined, 'Order', 1),
              _buildNavItem(Icons.notifications_outlined, 'Notification', 2),
              _buildNavItem(Icons.person_outline, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    bool isActive = false,
  }) {
    final bool selected = _currentNavIndex == index || isActive;
    return InkWell(
      onTap: () {
        if (index == 3) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/orders');
        } else {
          setState(() => _currentNavIndex = index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? AppColors.primary : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.primary : Colors.grey,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _bookService(Map<String, dynamic> service) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Booking ${service['name']}...'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    // Service booking functionality
  }
}
