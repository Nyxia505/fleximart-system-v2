import 'package:flutter/material.dart';

class CheckoutPage extends StatelessWidget {
  final Map<String, String> product;
  final Map<String, dynamic> variant;
  final int qty;

  const CheckoutPage({
    required this.product,
    required this.variant,
    required this.qty,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Checkout")),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product["img"]!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, size: 36),
                  ),
                ),
              ),
              title: Text(product["name"]!),
              subtitle: Text("${variant['color']} - ${variant['size']} x$qty"),
              trailing: Text(
                product["price"]!,
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 32),
            const ListTile(
              title: Text("Shipping Option"),
              subtitle: Text("Standard Local (get by 4-10 Nov)\nFree return"),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935), // Red color
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  elevation: 2,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Order Placed!")),
                  );
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text("Place Order"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
