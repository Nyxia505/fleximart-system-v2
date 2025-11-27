import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/product_base64_image.dart';
import 'product_details_page.dart';
import '../utils/price_formatter.dart';

/// Product Listing Page
/// 
/// Fetches all products from Firestore `/products` collection
/// Displays products in a responsive grid layout with:
/// - Base64 images (using ProductBase64Image widget)
/// - Product name, category, and price
class ProductListingPage extends StatelessWidget {
  const ProductListingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Products',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getProductsStream(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          // Error state
          if (snapshot.hasError) {
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
                      style: AppTextStyles.heading3(color: AppColors.error),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Refresh by rebuilding
                        (context as Element).markNeedsBuild();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
                      style: AppTextStyles.heading3(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Products will appear here once added',
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Products grid
          final productsList = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
          
          // Sort by createdAt if available (manual sort to avoid index requirement)
          productsList.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreated = aData['createdAt'] as Timestamp?;
            final bCreated = bData['createdAt'] as Timestamp?;
            
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated); // Descending
          });

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              childAspectRatio: 0.7,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: productsList.length,
            itemBuilder: (context, index) {
              return _ProductCard(
                productDoc: productsList[index],
              );
            },
          );
        },
      ),
    );
  }

  /// Get products stream with error handling
  Stream<QuerySnapshot> _getProductsStream() {
    // Use simple query to avoid index requirements
    return FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .handleError((error) {
      // Log error but don't crash
      print('Error fetching products: $error');
    });
  }

  /// Calculate responsive cross axis count based on screen width
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      return 4; // Desktop
    } else if (width > 800) {
      return 3; // Tablet
    } else if (width > 600) {
      return 2; // Large phone
    } else {
      return 2; // Phone
    }
  }
}

/// Product Card Widget
/// 
/// Displays a single product in a card format with:
/// - Base64 image
/// - Product name
/// - Category
/// - Price
class _ProductCard extends StatelessWidget {
  final QueryDocumentSnapshot productDoc;

  const _ProductCard({
    required this.productDoc,
  });

  @override
  Widget build(BuildContext context) {
    final product = productDoc.data() as Map<String, dynamic>;
    
    // Extract product data
    final name = product['name'] as String? ?? 'Unnamed Product';
    final category = product['category'] as String? ?? 'Uncategorized';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final imageBase64 = product['imageBase64'] as String? ?? 
                       product['image'] as String? ?? 
                       '';
    
    // Debug: Print Base64 length
    if (imageBase64.isNotEmpty) {
      print("BASE64 LENGTH: ${imageBase64.length}");
    }
    final createdAt = product['createdAt'] as Timestamp?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to product details with full product data
          final productId = productDoc.id;
          final isCustomizable = product['isCustomizable'] as bool? ?? false;
          final productLength = (product['length'] as num?)?.toDouble();
          final productWidth = (product['width'] as num?)?.toDouble();
          
          final productData = <String, dynamic>{
            'id': productId,
            'productId': productId,
            'name': name,
            'img': imageBase64,
            'image': imageBase64,
            'imageUrl': imageBase64,
            'price': price, // Pass as number
            'size': category,
            'description': category,
            'category': category,
            'isCustomizable': isCustomizable,
            if (productLength != null) 'length': productLength,
            if (productWidth != null) 'width': productWidth,
          };
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(product: productData),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: imageBase64.isNotEmpty
                    ? ProductBase64Image(
                        base64String: imageBase64,
                      )
                    : _buildImagePlaceholder(),
              ),
            ),
            
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Category Badge
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
                        style: AppTextStyles.caption(
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Product Name
                    Text(
                      name,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textPrimary,
                      ).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const Spacer(),
                    
                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          PriceFormatter.formatPrice(price),
                          style: AppTextStyles.heading3(
                            color: AppColors.primary,
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            _formatDate(createdAt.toDate()),
                            style: AppTextStyles.caption(
                              color: AppColors.textHint,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: AppColors.textSecondary.withOpacity(0.3),
        ),
      ),
    );
  }


  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

