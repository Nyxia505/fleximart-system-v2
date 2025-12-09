import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../constants/app_colors.dart';
import '../utils/image_url_helper.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, String> product;
  final String style;
  final String size;
  final int quantity;
  const CheckoutScreen({
    super.key,
    required this.product,
    required this.style,
    required this.size,
    required this.quantity,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? userAddress;

  int get priceNum => int.tryParse(widget.product['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  int get total => priceNum * widget.quantity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userAddress == null
                      ? "Please select address"
                      : userAddress!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final address = await showDialog<String>(
                    context: context,
                    builder: (_) => AddressDialog(address: userAddress),
                  );
                  if (address != null && address.isNotEmpty) {
                    setState(() => userAddress = address);
                  }
                },
                child: Text(userAddress == null ? "Add Address" : "Edit"),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  ImageUrlHelper.encodeUrl(widget.product['img']!),
                  width: 65,
                  height: 65,
                  fit: BoxFit.cover,
                  cacheWidth: kIsWeb ? null : 130,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 65,
                      height: 65,
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
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 65,
                      height: 65,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 32),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product['name']!),
                    Text("${widget.style}, ${widget.size}"),
                  ],
                ),
              ),
              Text('₱$priceNum', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("x${widget.quantity}"),
            ],
          ),
          const Divider(height: 32),
          const Text("Product Details", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.product['name']!),
                    Text('₱$priceNum', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text("${widget.style}, ${widget.size}"),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Quantity: x${widget.quantity}"),
                    Text("Subtotal: ₱$total", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("₱$total", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935), // Red color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: userAddress == null
                  ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please add your address before placing order!")),
                );
              }
                  : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Order Placed!")),
                );
                Navigator.pop(context);
              },
              child: const Text("Place Order"),
            ),
          ),
        ],
      ),
    );
  }
}

class AddressDialog extends StatefulWidget {
  final String? address;
  const AddressDialog({super.key, this.address});

  @override
  State<AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<AddressDialog> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.address ?? "");
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Enter Delivery Address"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: "Your address",
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text("Save"),
        ),
      ],
    );
  }
}
