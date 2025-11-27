import 'package:flutter/material.dart';

class ProductVariantSheet extends StatefulWidget {
  final Map<String, String> product;
  const ProductVariantSheet({required this.product, super.key});

  @override
  State<ProductVariantSheet> createState() => _ProductVariantSheetState();
}

class _ProductVariantSheetState extends State<ProductVariantSheet> {
  String selectedColor = "Black";
  String selectedSize = "1m × 1m";
  String selectedThickness = "6mm";
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        right: 18,
        left: 18,
        top: 25,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(widget.product["img"]!, width: 60, height: 60, fit: BoxFit.cover),
            ),
            title: Text(widget.product["name"]!, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: const Text("Stock: 999", style: TextStyle(fontSize: 13)),
            trailing: Text(widget.product["price"]!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 32),
          const Text("Color", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(children: [
            ChoiceChip(
              label: const Text("Black"),
              selected: selectedColor == "Black",
              onSelected: (_) => setState(() => selectedColor = "Black"),
            ),
            const SizedBox(width: 7),
            ChoiceChip(
              label: const Text("White"),
              selected: selectedColor == "White",
              onSelected: (_) => setState(() => selectedColor = "White"),
            ),
          ]),
          const SizedBox(height: 18),
          const Text("Dimensions (Length × Width in meters)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              "0.5m × 0.5m",
              "1m × 1m",
              "1.5m × 1.5m",
              "2m × 2m",
              "2.5m × 2.5m",
              "3m × 3m",
              "1m × 2m",
              "2m × 3m",
              "Custom"
            ]
                .map((s) => ChoiceChip(
              label: Text(s),
              selected: selectedSize == s,
              onSelected: (_) => setState(() => selectedSize = s),
            ))
                .toList(),
          ),
          const SizedBox(height: 18),
          const Text("Thickness (mm)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ["3mm", "5mm", "6mm", "8mm", "10mm", "12mm"]
                .map((s) => ChoiceChip(
              label: Text(s),
              selected: selectedThickness == s,
              onSelected: (_) {
                setState(() {
                  selectedThickness = s;
                });
              },
            ))
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Quantity", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.remove_circle), onPressed: qty > 1 ? () => setState(() => qty--) : null),
                Text("$qty", style: const TextStyle(fontSize: 16)),
                IconButton(
                    icon: const Icon(Icons.add_circle), onPressed: () => setState(() => qty++)),
              ],
            ),
          ]),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 118, 200, 173).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 118, 200, 173),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                final finalSize = "$selectedSize / $selectedThickness";
                Navigator.of(context).pop({
                  "variant": { "color": selectedColor, "size": finalSize },
                  "qty": qty,
                });
              },
              child: const Text(
                "Buy Now",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
