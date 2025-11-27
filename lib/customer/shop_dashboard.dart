import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_colors.dart';
import '../pages/product_details_page.dart';
import '../widgets/product_base64_image.dart';
import '../utils/price_formatter.dart';

class ShopDashboard extends StatefulWidget {
  const ShopDashboard({super.key});

  @override
  State<ShopDashboard> createState() => _ShopDashboardState();
}

class _ShopDashboardState extends State<ShopDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  String? _selectedCategory;
  List<String> _categories = ['All Categories'];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load categories from Firestore
  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .get();

      if (mounted) {
        setState(() {
          _categories = ['All Categories'];
          for (var doc in snapshot.docs) {
            final categoryName = doc.data()['name']?.toString() ?? doc.id;
            if (!_categories.contains(categoryName)) {
              _categories.add(categoryName);
            }
          }
          // Also get unique categories from products
          _loadCategoriesFromProducts();
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  /// Load unique categories from products collection as fallback
  Future<void> _loadCategoriesFromProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();

      if (mounted) {
        final Set<String> productCategories = {};
        for (var doc in snapshot.docs) {
          final category = doc.data()['category']?.toString();
          if (category != null && category.isNotEmpty) {
            productCategories.add(category);
          }
        }

        setState(() {
          for (var category in productCategories) {
            if (!_categories.contains(category)) {
              _categories.add(category);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading categories from products: $e');
    }
  }

  /// Get products stream with category and search filtering
  Stream<QuerySnapshot> _getProductsStream() {
    Query query = FirebaseFirestore.instance.collection('products');

    // Apply category filter if selected
    if (_selectedCategory != null && _selectedCategory != 'All Categories') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots().handleError((error) {
      debugPrint('Error fetching products: $error');
    });
  }

  /// Filter products by search term
  List<QueryDocumentSnapshot> _filterProductsBySearch(
    List<QueryDocumentSnapshot> products,
  ) {
    if (_searchTerm.isEmpty) return products;

    final searchLower = _searchTerm.toLowerCase();
    return products.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final productCode = (data['productCode'] ?? '').toString().toLowerCase();

      return name.contains(searchLower) ||
          category.contains(searchLower) ||
          description.contains(searchLower) ||
          productCode.contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.mainGradient,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Shop',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchTerm.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchTerm = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchTerm = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Category Filter
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.white,
              child: _isLoadingCategories
                  ? const SizedBox(
                      height: 40,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((category) {
                          final isSelected = _selectedCategory == category ||
                              (_selectedCategory == null &&
                                  category == 'All Categories');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory =
                                      selected ? category : 'All Categories';
                                });
                              },
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),

            // Products Grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getProductsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

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
                            'Error loading products',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please try again later',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
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
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filter by search term
                  final allProducts = snapshot.data!.docs;
                  final filteredProducts = _filterProductsBySearch(allProducts);

                  if (filteredProducts.isEmpty) {
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
                            'No products found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.60, // Reduced to give more vertical space and prevent overflow
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final productDoc = filteredProducts[index];
                      final product = productDoc.data() as Map<String, dynamic>;
                      final name = product['name']?.toString() ??
                          product['title']?.toString() ??
                          'Product';
                      final imageString = product['image']?.toString() ??
                          product['imageUrl']?.toString() ??
                          '';
                      final price =
                          (product['price'] as num?)?.toDouble() ?? 0.0;
                      final category = product['category']?.toString() ?? '';
                      final categoryGroup = product['categoryGroup']?.toString() ?? 
                                           product['category']?.toString() ?? '';
                      final productId = productDoc.id;
                      final isCustomizable =
                          product['isCustomizable'] as bool? ?? false;
                      final productLength =
                          (product['length'] as num?)?.toDouble();
                      final productWidth = (product['width'] as num?)?.toDouble();

                      // Format product data for ProductDetailsPage
                      final productData = {
                        'id': productId,
                        'productId': productId,
                        'name': name,
                        'img': imageString,
                        'image': imageString,
                        'imageUrl': imageString,
                        'price': price,
                        'size': product['description']?.toString() ??
                            'Standard Size',
                        'description': product['description']?.toString() ?? '',
                        'category': category,
                        'categoryGroup': categoryGroup, // Add categoryGroup for door detection
                        'isCustomizable': isCustomizable,
                        if (productLength != null) 'length': productLength,
                        if (productWidth != null) 'width': productWidth,
                      };

                      return _ProductCard(
                        title: name,
                        imageString: imageString,
                        price: price,
                        category: category,
                        productData: productData,
                        onImageTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailsPage(product: productData),
                            ),
                          );
                        },
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
}

/// Product Card Widget matching Home Featured Products design
class _ProductCard extends StatelessWidget {
  final String title;
  final String imageString;
  final double price;
  final String category;
  final Map<String, dynamic> productData;
  final VoidCallback onImageTap;

  const _ProductCard({
    required this.title,
    required this.imageString,
    required this.price,
    required this.category,
    required this.productData,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image (clickable)
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: onImageTap,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: imageString.isNotEmpty
                    ? _buildProductImage(imageString)
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_outlined,
                          size: 56,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
          ),
          // Product Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced vertical padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category Label
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1, // Further reduced
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 8, // Further reduced
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (category.isNotEmpty) const SizedBox(height: 2), // Further reduced
                  // Product Name
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12, // Further reduced
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2), // Further reduced
                  // Price
                  Text(
                    PriceFormatter.formatPrice(price),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Further reduced
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4), // Small spacing before buttons
                  // REQUEST QUOTATION Button
                  SizedBox(
                    width: double.infinity,
                    height: 24, // Further reduced
                    child: OutlinedButton(
                      onPressed: () {
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
                        minimumSize: const Size(0, 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'REQUEST QUOTATION',
                        style: TextStyle(
                          fontSize: 7, // Further reduced
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2), // Further reduced
                  // PROCEED TO BUY Button
                  SizedBox(
                    width: double.infinity,
                    height: 24, // Further reduced
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/proceed-buy',
                          arguments: productData,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'PROCEED TO BUY',
                        style: TextStyle(
                          fontSize: 7, // Further reduced
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
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
    );
  }

  Widget _buildProductImage(String imageString) {
    // Check if it's a base64 string
    final isBase64 = imageString.startsWith('data:image/') ||
        (imageString.length > 100 && !imageString.startsWith('http'));

    if (isBase64) {
      return ProductBase64Image(base64String: imageString);
    } else {
      return Image.network(
        imageString,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Icon(
              Icons.broken_image,
              size: 32,
              color: Colors.grey,
            ),
          );
        },
      );
    }
  }
}

