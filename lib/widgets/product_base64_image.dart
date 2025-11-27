import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProductBase64Image extends StatelessWidget {
  final String base64String;
  final double height;
  final double width;

  const ProductBase64Image({
    super.key,
    required this.base64String,
    this.height = 180,
    this.width = double.infinity,
  });

  Uint8List? decode() {
    try {
      final cleaned = base64String
          .replaceAll("data:image/jpeg;base64,", "")
          .replaceAll("data:image/png;base64,", "")
          .replaceAll(RegExp(r'\s+'), "")
          .trim();

      return base64Decode(cleaned);
    } catch (e) {
      print("❌ ERROR DECODING BASE64: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = decode();

    return Container(
      height: height,
      width: width,
      color: Colors.grey.shade300,
      child: bytes == null
          ? const Icon(Icons.broken_image, size: 40)
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }
}
