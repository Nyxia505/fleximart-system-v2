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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Get products stream with search filtering
  Stream<QuerySnapshot> _getProductsStream() {
    Query query = FirebaseFirestore.instance.collection('products');

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
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
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

            // Products Grid - Scrollable
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getProductsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      child: Center(
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
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please try again later',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF1D3B53),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return SingleChildScrollView(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: const Color(0xFF1D3B53).withOpacity(0.8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products available',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Filter by search term
                  final allProducts = snapshot.data!.docs;
                  final filteredProducts = _filterProductsBySearch(allProducts);

                  // Remove entries without valid images to avoid blank cards
                  final validProducts = filteredProducts.where((doc) {
                    final product = doc.data() as Map<String, dynamic>;
                    final imageString =
                        product['image']?.toString() ??
                        product['imageUrl']?.toString() ??
                        '';
                    return imageString.trim().isNotEmpty;
                  }).toList();

                  if (filteredProducts.isEmpty || validProducts.isEmpty) {
                    return SingleChildScrollView(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: const Color(0xFF1D3B53).withOpacity(0.8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF1D3B53),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          childAspectRatio:
                              0.50, // Reduced further to prevent overflow
                        ),
                    itemCount: validProducts.length,
                    itemBuilder: (context, index) {
                      try {
                        final productDoc = validProducts[index];
                        final product =
                            productDoc.data() as Map<String, dynamic>;
                        final name =
                            product['name']?.toString() ??
                            product['title']?.toString() ??
                            'Product';
                        final imageString =
                            product['image']?.toString() ??
                            product['imageUrl']?.toString() ??
                            '';
                        // Safe price parsing - handle both String and num types
                        double price = 0.0;
                        final priceValue = product['price'];
                        if (priceValue != null) {
                          if (priceValue is num) {
                            price = priceValue.toDouble();
                          } else if (priceValue is String) {
                            price = double.tryParse(priceValue) ?? 0.0;
                          }
                        }
                        final category = product['category']?.toString() ?? '';
                        final categoryGroup =
                            product['categoryGroup']?.toString() ??
                            product['category']?.toString() ??
                            '';
                        final productId = productDoc.id;
                        final isCustomizable =
                            product['isCustomizable'] as bool? ?? false;
                        final productLength = (product['length'] as num?)
                            ?.toDouble();
                        final productWidth = (product['width'] as num?)
                            ?.toDouble();

                        // Format product data for ProductDetailsPage
                        final productData = {
                          'id': productId,
                          'productId': productId,
                          'name': name,
                          'img': imageString,
                          'image': imageString,
                          'imageUrl': imageString,
                          'price': price,
                          'size':
                              product['description']?.toString() ??
                              'Standard Size',
                          'description':
                              product['description']?.toString() ?? '',
                          'category': category,
                          'categoryGroup':
                              categoryGroup, // Add categoryGroup for door detection
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
                      } catch (e, stackTrace) {
                        debugPrint('Error building product card: $e');
                        debugPrint('Stack trace: $stackTrace');
                        // Return error card instead of crashing
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.error,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Error loading product',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(
                                      0xFF1D3B53,
                                    ), // Dark blue for better contrast
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product Image (clickable) - Flexible height
          Expanded(
            flex: 5,
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
          // Product Info - Flexible to prevent overflow
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category Label
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (category.isNotEmpty) const SizedBox(height: 2),
                  // Product Name - Always visible above price
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Price
                  Text(
                    PriceFormatter.formatPrice(price),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Request Quotation Button
                  SizedBox(
                    width: double.infinity,
                    height: 26,
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
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1,
                        ),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'Request Quotation',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Buy Now Button
                  SizedBox(
                    width: double.infinity,
                    height: 26,
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
                        minimumSize: Size.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'Buy Now',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
    final isBase64 =
        imageString.startsWith('data:image/') ||
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
            child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
          );
        },
      );
    }
  }
}
