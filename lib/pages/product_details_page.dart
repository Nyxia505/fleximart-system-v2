import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/product_base64_image.dart';
import '../screen/proceed_to_buy_page.dart';
import '../screen/request_quotation_screen.dart';
import '../utils/price_formatter.dart';

class ProductDetailsPage extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductDetailsPage({required this.product, super.key});

  void _proceedToOrder(BuildContext context) {
    // Navigate to Proceed to Buy page with product data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProceedToBuyPage(),
        settings: RouteSettings(arguments: product),
      ),
    );
  }

  void _requestQuotation(BuildContext context) {
    // Navigate to Request Quotation page with product data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RequestQuotationScreen(),
        settings: RouteSettings(arguments: product),
      ),
    );
  }


  Widget _buildSizeGuide(BuildContext context) {
    final sizeText = (product["size"]?.toString() ?? 
                     product["description"]?.toString() ?? 
                     '').trim();
    
    // Check if size is valid (not empty, not corrupted-looking)
    final isValidSize = sizeText.isNotEmpty && 
                       sizeText.length < 100 && 
                       !sizeText.contains(RegExp(r'[^\w\s\-.,()x×]', caseSensitive: false));
    
    if (!isValidSize) {
      // Show a clickable "View Size Guide" link instead
      return GestureDetector(
        onTap: () {
          _showSizeGuideDialog(context);
        },
        child: Row(
          children: [
            const Text(
              "Size Guide: ",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "View Size Guide",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.primary,
            ),
          ],
        ),
      );
    }
    
    // Show the size as a clickable link
    return GestureDetector(
      onTap: () {
        _showSizeGuideDialog(context, sizeText);
      },
      child: Row(
        children: [
          const Text(
            "Size Guide: ",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sizeText,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  void _showSizeGuideDialog(BuildContext context, [String? sizeInfo]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Size Guide',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sizeInfo != null && sizeInfo.isNotEmpty) ...[
                Text(
                  sizeInfo,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],
              const Text(
                'Standard Sizes Available:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Windows: 1m x 1m, 1.2m x 1m, 1.5m x 1.2m\n'
                '• Doors: 2m x 0.8m, 2m x 0.9m, 2.1m x 0.9m\n'
                '• Custom sizes available upon request\n\n'
                'For custom dimensions, please use "Request Quotation" to get an accurate price.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestQuotation(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Request Quotation'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(dynamic imageData) {
    final imageString = imageData?.toString() ?? '';
    if (imageString.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 56),
      );
    }
    
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
        errorBuilder: (c, e, s) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.image, size: 56),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get product fields with fallbacks
    final productName = product['name']?.toString() ?? 
                       product['title']?.toString() ?? 
                       'Product';
    final productImage = product['img'] ?? 
                        product['image'] ?? 
                        product['imageUrl'] ?? 
                        '';
    final productPrice = product['price']?.toString() ?? 
                        (product['price'] is num 
                          ? PriceFormatter.formatPrice((product['price'] as num).toDouble())
                          : '₱0.00');
    
    // Check if product is customizable
    final isCustomizable = product['isCustomizable'] as bool? ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(productName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1.2,
                child: _buildProductImage(productImage),
              ),
              const SizedBox(height: 16), // Reduced from 18 to 16
              Text(
                productName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                productPrice,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Only show size guide for customizable products
              if (isCustomizable) ...[
                const SizedBox(height: 12),
                _buildSizeGuide(context),
              ],
              const SizedBox(height: 16), // Reduced from 24 to 16
              // REQUEST QUOTATION Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _requestQuotation(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Request Quotation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12), // Reduced from 16 to 12 for closer spacing
              // PROCEED TO BUY Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _proceedToOrder(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'PROCEED TO BUY',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
