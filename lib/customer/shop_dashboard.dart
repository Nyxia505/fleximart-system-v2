import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../pages/product_details_page.dart';
import '../widgets/product_base64_image.dart';
import '../utils/price_formatter.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../utils/image_url_helper.dart';

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
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      // Cart Icon with Badge
                      StreamBuilder<int>(
                        stream: CartService().getCartCountStream(),
                        builder: (context, snapshot) {
                          final cartCount = snapshot.data ?? 0;
                          
                          return GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/cart');
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                if (cartCount > 0)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Text(
                                        cartCount > 99 ? '99+' : '$cartCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      suffixIcon: _searchTerm.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchTerm = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.25),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.6),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    );
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
                                  color: AppColors.textSecondary,
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
                                color: AppColors.primary.withOpacity(0.6),
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
                                color: AppColors.primary.withOpacity(0.6),
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
                                  color: AppColors.textSecondary,
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
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
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
                          productId: productId,
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
  final String productId;

  const _ProductCard({
    required this.title,
    required this.imageString,
    required this.price,
    required this.category,
    required this.productData,
    required this.onImageTap,
    required this.productId,
  });

  Future<void> _addToCartAndNavigate(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add items to cart'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    try {
      final cartService = CartService();
      final productId = productData['id']?.toString() ?? productData['productId']?.toString() ?? '';
      final productName = productData['name']?.toString() ?? 'Product';
      final productImage = productData['image']?.toString() ?? productData['imageUrl']?.toString();
      final productLength = (productData['length'] as num?)?.toDouble();
      final productWidth = (productData['width'] as num?)?.toDouble();

      await cartService.addToCart(
        productId: productId,
        productName: productName,
        price: price,
        quantity: 1,
        productImage: productImage,
        length: productLength,
        width: productWidth,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
        // Navigate to cart page
        Navigator.pushNamed(context, '/cart');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to cart: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
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
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category Label
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.secondary.withOpacity(0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (category.isNotEmpty) const SizedBox(height: 2),
                  // Product Name with Cart Icon
                  Flexible(
                    child: Row(
                      children: [
                        Expanded(
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
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            // Add to cart and navigate
                            _addToCartAndNavigate(context);
                          },
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Sold Count Badge - More prominent display
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
                  const SizedBox(height: 4),
                  // Price
                  Text(
                    PriceFormatter.formatPrice(price),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Request Quotation Button
                  SizedBox(
                    width: double.infinity,
                    height: 28,
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
                        side: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Request Quotation',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
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
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/proceed-buy',
                            arguments: productData,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Buy Now',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    final isBase64 =
        imageString.startsWith('data:image/') ||
        (imageString.length > 100 && !imageString.startsWith('http'));

    if (isBase64) {
      return ProductBase64Image(base64String: imageString);
    } else {
      return Image.network(
        ImageUrlHelper.encodeUrl(imageString),
        fit: BoxFit.cover,
        cacheWidth: kIsWeb ? null : 400,
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

