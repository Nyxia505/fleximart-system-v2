import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'product_card.dart';

/// Product Grid Widget
/// 
/// Displays products in a responsive grid layout using StreamBuilder
/// Fetches products from Firestore in real-time
class ProductGrid extends StatelessWidget {
  final ProductService? productService;
  final Function(Product)? onProductTap;

  const ProductGrid({
    super.key,
    this.productService,
    this.onProductTap,
  });

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

  @override
  Widget build(BuildContext context) {
    final service = productService ?? ProductService();
    
    return StreamBuilder<QuerySnapshot>(
      stream: service.getProductsStream(),
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
        final products = snapshot.data!.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getCrossAxisCount(context),
            childAspectRatio: 0.7,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onTap: onProductTap != null
                  ? () => onProductTap!(product)
                  : null,
            );
          },
        );
      },
    );
  }
}

