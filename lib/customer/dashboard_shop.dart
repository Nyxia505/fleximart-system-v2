import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/product_details_page.dart';
import '../constants/app_colors.dart';
import '../widgets/product_base64_image.dart';

class DashboardShop extends StatefulWidget {
  const DashboardShop({super.key});

  @override
  State<DashboardShop> createState() => _DashboardShopState();
}

class _DashboardShopState extends State<DashboardShop> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  String? _selectedCategoryGroup;

  @override
  void initState() {
    super.initState();
    // Get categoryGroup or search from route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args != null && args is Map<String, dynamic>) {
          final categoryGroup = args['categoryGroup'] as String?;
          final category = args['category'] as String?; // Backward compatibility
          final search = args['search'] as String?;
          
          // Use categoryGroup if available, otherwise fallback to category
          final selectedGroup = categoryGroup ?? category;
          if (selectedGroup != null && selectedGroup.isNotEmpty) {
            setState(() {
              _selectedCategoryGroup = selectedGroup.toLowerCase();
            });
          }
          if (search != null && search.isNotEmpty) {
            setState(() {
              _searchController.text = search;
              _searchTerm = search;
            });
          }
        }
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also check arguments in didChangeDependencies in case initState missed them
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      final categoryGroup = args['categoryGroup'] as String?;
      final category = args['category'] as String?; // Backward compatibility
      final selectedGroup = categoryGroup ?? category;
      
      if (selectedGroup != null && selectedGroup.isNotEmpty && _selectedCategoryGroup == null) {
        debugPrint('Setting categoryGroup filter: $selectedGroup');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedCategoryGroup = selectedGroup.toLowerCase();
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.mainGradient,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'FlexiMart',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black12,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedCategoryGroup != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedCategoryGroup!.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchTerm = value);
                      },
                      decoration: InputDecoration(
                        hintText: "Search in shop...",
                        hintStyle: TextStyle(
                          color: AppColors.textHint.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.primary, // Crimson Red
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: _searchTerm.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchTerm = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: AppColors.dashboardBackground,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint('❌ Error loading products: ${snapshot.error}');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
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
                              'Error loading products',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check your connection and try again',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No products available",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final allProducts = snapshot.data!.docs;
                  
                  if (allProducts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No products available",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Log all products for debugging
                  debugPrint('📦 Total products in Firestore: ${snapshot.data!.docs.length}');
                  for (var doc in snapshot.data!.docs) {
                    final product = doc.data() as Map<String, dynamic>?;
                    final name = product?['name'] as String? ?? product?['title'] as String? ?? 'Unknown';
                    final categoryGroup = product?['categoryGroup'] as String? ?? 'No categoryGroup';
                    debugPrint('   - $name (CategoryGroup: $categoryGroup)');
                  }

                  // Filter products by categoryGroup and search term
                  List<QueryDocumentSnapshot> products = [];
                  try {
                    debugPrint('🔍 Filtering products - Selected CategoryGroup: $_selectedCategoryGroup, Search: $_searchTerm');
                    products = snapshot.data!.docs.where((doc) {
                      try {
                        final product = doc.data() as Map<String, dynamic>?;
                        if (product == null) return false;
                        
                        // CategoryGroup filter
                        if (_selectedCategoryGroup != null && _selectedCategoryGroup!.isNotEmpty) {
                          final productCategoryGroup = (product['categoryGroup'] as String?)?.trim().toLowerCase();
                          if (productCategoryGroup == null || 
                              productCategoryGroup != _selectedCategoryGroup!.toLowerCase()) {
                            return false;
                          }
                        }
                        
                        // Search filter
                        if (_searchTerm.isNotEmpty) {
                          final name = (product['name'] as String? ?? product['title'] as String? ?? '').toLowerCase().trim();
                          final description = (product['description'] as String? ?? '').toLowerCase().trim();
                          final query = _searchTerm.toLowerCase().trim();
                          if (query.isNotEmpty && !name.contains(query) && !description.contains(query)) {
                            return false;
                          }
                        }
                        
                        return true;
                      } catch (e) {
                        debugPrint('Error filtering product ${doc.id}: $e');
                        return false;
                      }
                    }).toList();
                  } catch (e) {
                    debugPrint('Error filtering products: $e');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
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
                              'Error processing products',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No products found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedCategoryGroup != null
                                ? "Try a different category or search term"
                                : "Try a different search term",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 20 + MediaQuery.of(context).padding.bottom + 80, // Extra padding for bottom nav
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58, // Reduced to give more vertical space
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final productDoc = products[i];
                      final product = productDoc.data() as Map<String, dynamic>;
                      // Use 'name' field, fallback to 'title' for backward compatibility
                      final name = product['name'] as String? ?? product['title'] as String? ?? 'Unknown';
                      // Use 'image' field (base64), fallback to 'imageUrl' for backward compatibility
                      final imageString = product['image'] as String? ?? product['imageUrl'] as String? ?? '';
                      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
                      final description = product['description'] as String? ?? '';
                      
                      // Get product ID and customizable flag
                      final productId = productDoc.id;
                      final isCustomizable = product['isCustomizable'] as bool? ?? false;
                      final productLength = (product['length'] as num?)?.toDouble();
                      final productWidth = (product['width'] as num?)?.toDouble();
                      
                      // Format product data for ProductDetailsPage - pass full product data
                      final productData = <String, dynamic>{
                        'id': productId,
                        'productId': productId,
                        'name': name,
                        'img': imageString,
                        'image': imageString,
                        'imageUrl': imageString,
                        'price': price, // Pass as number, not formatted string
                        'size': description.isNotEmpty ? description : 'Standard Size',
                        'description': description,
                        'isCustomizable': isCustomizable,
                        if (productLength != null) 'length': productLength,
                        if (productWidth != null) 'width': productWidth,
                      };

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailsPage(product: productData),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Container(
                                    width: double.infinity,
                                    color: AppColors.dashboardBackground,
                                    child: imageString.isNotEmpty
                                        ? _buildProductImage(imageString)
                                        : Container(
                                            color: AppColors.border.withOpacity(0.3),
                                            child: Center(
                                              child: Icon(
                                                Icons.image_not_supported,
                                                size: 40,
                                                color: AppColors.textHint.withOpacity(0.5),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                              height: 1.2,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          productData['size'] as String? ?? 'Standard Size',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          productData['price'] as String? ?? '₱0.00',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // REQUEST QUOTATION Button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 28,
                                          child: OutlinedButton(
                                            onPressed: () {
                                              final user = FirebaseAuth.instance.currentUser;
                                              if (user == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: const Text('Please log in to request quotation'),
                                                    backgroundColor: AppColors.primary,
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    margin: const EdgeInsets.all(16),
                                                  ),
                                                );
                                                return;
                                              }
                                              Navigator.pushNamed(
                                                context,
                                                '/request-quotation',
                                                arguments: productData,
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.primary,
                                              side: const BorderSide(color: AppColors.primary, width: 1),
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(0, 28),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(18),
                                              ),
                                            ),
                                            child: const Text(
                                              'REQUEST QUOTATION',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // PROCEED BUY Button - Gradient Style
                                        SizedBox(
                                          width: double.infinity,
                                          height: 28,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: AppColors.buttonGradient,
                                              borderRadius: BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primary.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                final user = FirebaseAuth.instance.currentUser;
                                                if (user == null) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: const Text('Please log in to buy products'),
                                                      backgroundColor: AppColors.primary,
                                                      behavior: SnackBarBehavior.floating,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(16),
                                                      ),
                                                      margin: const EdgeInsets.all(16),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                Navigator.pushNamed(
                                                  context,
                                                  '/proceed-buy',
                                                  arguments: productData,
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 28),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: const Text(
                                                'PROCEED BUY',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String imageString) {
    // Check if it's a base64 string (starts with data:image/ or is a long base64 string)
    final isBase64 = imageString.startsWith('data:image/') || 
                     (imageString.length > 100 && !imageString.startsWith('http'));
    
    if (isBase64) {
      // Use base64 image widget
      return ProductBase64Image(
        base64String: imageString,
      );
    } else {
      // Use network image for URLs
      return Image.network(
        imageString,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.border.withOpacity(0.3),
          child: Center(
            child: Icon(
              Icons.image_not_supported,
              size: 40,
              color: AppColors.textHint.withOpacity(0.5),
            ),
          ),
        ),
      );
    }
  }
}
