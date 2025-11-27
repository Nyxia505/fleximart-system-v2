import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to seed sample data into Firestore for development/testing
class SampleDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seeds sample products to Firestore
  static Future<void> seedProducts() async {
    final products = [
      // Mantle Category
      {
        'title': 'Classic Wood Mantle',
        'description': 'Elegant wooden fireplace mantle with traditional design. Perfect for adding warmth to your living space.',
        'price': 8500.0,
        'stock': 8,
        'imageUrl': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
        'category': 'Mantle',
        'minStock': 5,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Modern Marble Mantle',
        'description': 'Sleek marble fireplace mantle with contemporary design. Adds luxury and sophistication.',
        'price': 12500.0,
        'stock': 5,
        'imageUrl': 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=400',
        'category': 'Mantle',
        'minStock': 3,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Rustic Stone Mantle',
        'description': 'Natural stone fireplace mantle with rustic charm. Durable and weather-resistant.',
        'price': 9800.0,
        'stock': 6,
        'imageUrl': 'https://images.unsplash.com/photo-1600607687644-c7171b42498b?w=400',
        'category': 'Mantle',
        'minStock': 4,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Custom Carved Mantle',
        'description': 'Handcrafted custom mantle with intricate carvings. Available in various wood types.',
        'price': 15000.0,
        'stock': 4,
        'imageUrl': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
        'category': 'Mantle',
        'minStock': 2,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      
      // Frames Category
      {
        'title': 'Aluminum Window Frame',
        'description': 'Lightweight and durable aluminum frame. Corrosion-resistant and low maintenance.',
        'price': 3200.0,
        'stock': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Frames',
        'minStock': 10,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'UPVC Window Frame',
        'description': 'Energy-efficient UPVC frame with excellent insulation. Weather-resistant and long-lasting.',
        'price': 2800.0,
        'stock': 18,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Frames',
        'minStock': 12,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Wooden Frame Set',
        'description': 'Classic wooden window frame with natural finish. Perfect for traditional homes.',
        'price': 4500.0,
        'stock': 12,
        'imageUrl': 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=400',
        'category': 'Frames',
        'minStock': 8,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Steel Frame System',
        'description': 'Strong steel frame for large openings. Ideal for commercial and residential use.',
        'price': 5500.0,
        'stock': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Frames',
        'minStock': 6,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Composite Frame',
        'description': 'Modern composite frame combining wood and aluminum. Best of both materials.',
        'price': 4800.0,
        'stock': 14,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Frames',
        'minStock': 10,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      
      // Sliding window Category
      {
        'title': 'Double Sliding Window',
        'description': 'Smooth double-pane sliding window with thermal insulation. Easy to operate and maintain.',
        'price': 4200.0,
        'stock': 12,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Sliding window',
        'minStock': 8,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Triple Track Sliding Window',
        'description': 'Three-panel sliding window system. Maximum ventilation and space efficiency.',
        'price': 5800.0,
        'stock': 8,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Sliding window',
        'minStock': 5,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Energy Star Sliding Window',
        'description': 'Energy-efficient sliding window with low-E glass. Reduces heating and cooling costs.',
        'price': 5200.0,
        'stock': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Sliding window',
        'minStock': 6,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Frosted Sliding Window',
        'description': 'Privacy sliding window with frosted glass panels. Perfect for bathrooms and bedrooms.',
        'price': 3800.0,
        'stock': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Sliding window',
        'minStock': 10,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Custom Size Sliding Window',
        'description': 'Made-to-order sliding window in any size. Professional installation available.',
        'price': 6500.0,
        'stock': 6,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Sliding window',
        'minStock': 3,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      
      // Doors Category
      {
        'title': 'Folding Door (Accordion Door)',
        'description': 'A folding or accordion door is made of multiple connected panels that fold neatly to one side when opened. It is ideal for saving space in compact rooms, closets, and partitions. Its flexible design makes it practical for both residential and commercial interiors.',
        'price': 3200.0,
        'stock': 12,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Doors',
        'minStock': 8,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Screen Door Closer',
        'description': 'A screen door closer is a hydraulic or spring-operated device that automatically returns a screen door to the closed position. It prevents slamming, reduces noise, and helps keep insects out, making it a reliable accessory for maintaining comfort and convenience.',
        'price': 850.0,
        'stock': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Doors',
        'minStock': 12,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Panel Door',
        'description': 'A panel door is constructed with raised or recessed sections framed by stiles and rails. It is a timeless and versatile design used in bedrooms, living spaces, and interior partitions. Panel doors are valued for their durability and classic appearance.',
        'price': 4500.0,
        'stock': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Doors',
        'minStock': 6,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'French Door (Double Swing Door)',
        'description': 'A French door features two hinged panels with large glass sections that swing open from the center. Its elegant design brings ample daylight into a room and provides a beautiful visual connection between indoor and outdoor living spaces.',
        'price': 4800.0,
        'stock': 8,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Doors',
        'minStock': 5,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Aluminum Swing Door',
        'description': 'An aluminum swing door opens inward or outward using side hinges. Its lightweight yet durable frame makes it suitable for main entryways, bedrooms, offices, and commercial areas. It is a strong, low-maintenance, and modern door option.',
        'price': 3800.0,
        'stock': 14,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Doors',
        'minStock': 9,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Sliding Glass Door',
        'description': 'A sliding glass door moves smoothly along a horizontal track and features wide glass panels that maximize natural light. It is ideal for patios, balconies, and modern living rooms, offering a bright and open feel while saving space.',
        'price': 3500.0,
        'stock': 12,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Doors',
        'minStock': 8,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'French Glass Door',
        'description': 'Classic French door design with clear tempered glass. Perfect for patios and entrances.',
        'price': 4200.0,
        'stock': 8,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Doors',
        'minStock': 5,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Frosted Glass Door',
        'description': 'Privacy glass door with elegant frosted finish. Ideal for bathrooms and bedrooms.',
        'price': 2800.0,
        'stock': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Doors',
        'minStock': 10,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Aluminum Frame Glass Door',
        'description': 'Durable aluminum frame with tempered glass. Weather-resistant and low maintenance.',
        'price': 3800.0,
        'stock': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Doors',
        'minStock': 6,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'PVC Transparent Door',
        'description': 'Durable PVC door with transparent panels. Perfect for indoor use.',
        'price': 1929.0,
        'stock': 25,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Doors',
        'minStock': 15,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      
      // Glass type Category
      {
        'title': 'Tempered Glass 5mm',
        'description': 'Strong tempered glass suitable for windows and doors. Heat-treated for enhanced durability.',
        'price': 1200.0,
        'stock': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Glass type',
        'minStock': 12,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Frosted Glass Panel',
        'description': 'Decorative frosted glass for bathroom partitions. Provides privacy while allowing light.',
        'price': 1500.0,
        'stock': 12,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Glass type',
        'minStock': 8,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Laminated Glass 6mm',
        'description': 'Safety glass with PVB interlayer. Resistant to breakage and UV rays.',
        'price': 1800.0,
        'stock': 8,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Glass type',
        'minStock': 5,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Low-E Glass',
        'description': 'Energy-efficient low-emissivity glass. Reduces heat transfer and UV radiation.',
        'price': 2200.0,
        'stock': 10,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Glass type',
        'minStock': 6,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Tinted Glass',
        'description': 'Bronze-tinted glass with UV protection. Available in multiple sizes and shades.',
        'price': 1450.0,
        'stock': 15,
        'imageUrl': 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
        'category': 'Glass type',
        'minStock': 10,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Clear Float Glass',
        'description': 'Standard clear float glass for general applications. High clarity and quality.',
        'price': 950.0,
        'stock': 30,
        'imageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400',
        'category': 'Glass type',
        'minStock': 20,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();
    for (var product in products) {
      final docRef = _firestore.collection('products').doc();
      batch.set(docRef, product);
    }
    await batch.commit();
  }

  /// Seeds sample orders to Firestore
  static Future<void> seedOrders(String? userId) async {
    if (userId == null) return;

    final orders = [
      {
        'userId': userId,
        'items': [
          {'productId': 'p1', 'title': 'Tempered Glass 5mm', 'price': 1200.0, 'quantity': 2},
          {'productId': 'p3', 'title': 'Mirror Glass 4mm', 'price': 900.0, 'quantity': 1},
        ],
        'total': 3300.0,
        'status': 'completed',
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2))),
        'customerName': 'John Doe',
        'customerEmail': 'john@example.com',
        'shippingAddress': '123 Main St, City',
      },
      {
        'userId': userId,
        'items': [
          {'productId': 'p2', 'title': 'Frosted Glass Panel', 'price': 1500.0, 'quantity': 1},
        ],
        'total': 1500.0,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 30))),
        'customerName': 'Jane Smith',
        'customerEmail': 'jane@example.com',
        'shippingAddress': '456 Oak Ave, City',
      },
      {
        'userId': userId,
        'items': [
          {'productId': 'p4', 'title': 'PVC Transparent Door', 'price': 1929.0, 'quantity': 1},
        ],
        'total': 1929.0,
        'status': 'shipped',
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 5))),
        'customerName': 'Bob Johnson',
        'customerEmail': 'bob@example.com',
        'shippingAddress': '789 Pine Rd, City',
      },
      {
        'userId': userId,
        'items': [
          {'productId': 'p1', 'title': 'Tempered Glass 5mm', 'price': 1200.0, 'quantity': 3},
          {'productId': 'p8', 'title': 'Double Pane Window', 'price': 2800.0, 'quantity': 2},
        ],
        'total': 9200.0,
        'status': 'processing',
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
        'customerName': 'Alice Brown',
        'customerEmail': 'alice@example.com',
        'shippingAddress': '321 Elm St, City',
      },
      {
        'userId': userId,
        'items': [
          {'productId': 'p7', 'title': 'Sliding Glass Door', 'price': 3500.0, 'quantity': 1},
        ],
        'total': 3500.0,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 15))),
        'customerName': 'Charlie Wilson',
        'customerEmail': 'charlie@example.com',
        'shippingAddress': '654 Maple Dr, City',
      },
    ];

    final batch = _firestore.batch();
    for (var order in orders) {
      final docRef = _firestore.collection('orders').doc();
      batch.set(docRef, order);
    }
    await batch.commit();
  }

  /// Seeds all sample data
  static Future<void> seedAllData({String? userId}) async {
    try {
      await seedProducts();
      if (userId != null) {
        await seedOrders(userId);
      }
    } catch (e) {
      print('Error seeding data: $e');
    }
  }

  /// Clears all sample data (use with caution!)
  static Future<void> clearAllData() async {
    try {
      // Clear products
      final productsSnapshot = await _firestore.collection('products').get();
      final productsBatch = _firestore.batch();
      for (var doc in productsSnapshot.docs) {
        productsBatch.delete(doc.reference);
      }
      await productsBatch.commit();

      // Clear orders
      final ordersSnapshot = await _firestore.collection('orders').get();
      final ordersBatch = _firestore.batch();
      for (var doc in ordersSnapshot.docs) {
        ordersBatch.delete(doc.reference);
      }
      await ordersBatch.commit();
    } catch (e) {
      print('Error clearing data: $e');
    }
  }
}

