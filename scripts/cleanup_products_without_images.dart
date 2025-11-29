/// Firestore Product Cleanup Script
/// 
/// This script finds and deletes all product documents in the "products" collection
/// where the imageUrl field is null, empty, or missing.
/// 
/// Usage:
///   dart run scripts/cleanup_products_without_images.dart
/// 
/// IMPORTANT: This script will DELETE data permanently. Use with caution!

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fleximart/firebase_options.dart';

void main() async {
  print('=' * 60);
  print('Firestore Product Cleanup Script');
  print('=' * 60);
  print('');
  
  try {
    // Initialize Firebase
    print('🔧 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully\n');

    // Get Firestore instance
    final firestore = FirebaseFirestore.instance;
    
    // Query all products
    print('📦 Fetching all products from Firestore...');
    final productsSnapshot = await firestore.collection('products').get();
    final allProducts = productsSnapshot.docs;
    print('✅ Found ${allProducts.length} total products\n');

    // Filter products with invalid imageUrl
    print('🔍 Analyzing products for invalid imageUrl...');
    final productsToDelete = <QueryDocumentSnapshot>[];
    
    for (final productDoc in allProducts) {
      final data = productDoc.data() as Map<String, dynamic>?;
      
      // Check if imageUrl is null, empty, or missing
      final imageUrl = data?['imageUrl'];
      final image = data?['image']; // Also check 'image' field (base64)
      
      final hasInvalidImageUrl = imageUrl == null || 
                                 imageUrl.toString().trim().isEmpty;
      final hasNoImage = image == null || 
                        image.toString().trim().isEmpty;
      
      // Also check if both imageUrl and image are missing/invalid
      if (hasInvalidImageUrl && hasNoImage) {
        productsToDelete.add(productDoc);
      }
    }

    print('📊 Analysis complete:');
    print('   - Total products: ${allProducts.length}');
    print('   - Products with invalid/missing imageUrl: ${productsToDelete.length}');
    print('   - Products to keep: ${allProducts.length - productsToDelete.length}\n');

    if (productsToDelete.isEmpty) {
      print('✅ No products to delete. All products have valid imageUrl fields.');
      exit(0);
    }

    // Show preview of products to be deleted
    print('⚠️  Products that will be DELETED:');
    print('-' * 60);
    for (int i = 0; i < productsToDelete.length && i < 10; i++) {
      final doc = productsToDelete[i];
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] ?? data['title'] ?? 'Unnamed Product';
      final id = doc.id;
      print('   ${i + 1}. $name (ID: $id)');
    }
    if (productsToDelete.length > 10) {
      print('   ... and ${productsToDelete.length - 10} more products');
    }
    print('-' * 60);
    print('');

    // Confirmation prompt
    print('⚠️  WARNING: This will permanently delete ${productsToDelete.length} product(s)!');
    print('   This action cannot be undone.\n');
    print('Do you want to proceed? (yes/no): ');
    
    final confirmation = stdin.readLineSync()?.toLowerCase().trim();
    
    if (confirmation != 'yes' && confirmation != 'y') {
      print('\n❌ Deletion cancelled. No products were deleted.');
      exit(0);
    }

    // Delete products in batches (Firestore batch limit is 500)
    print('\n🗑️  Deleting products...');
    const batchSize = 500;
    int deletedCount = 0;
    int failedCount = 0;
    final failedProducts = <String>[];

    for (int i = 0; i < productsToDelete.length; i += batchSize) {
      final batch = firestore.batch();
      final batchProducts = productsToDelete.skip(i).take(batchSize).toList();
      
      for (final productDoc in batchProducts) {
        try {
          batch.delete(productDoc.reference);
        } catch (e) {
          print('   ⚠️  Error preparing deletion for ${productDoc.id}: $e');
          failedProducts.add(productDoc.id);
          failedCount++;
        }
      }

      try {
        await batch.commit();
        deletedCount += batchProducts.length;
        print('   ✅ Deleted batch ${(i ~/ batchSize) + 1}: ${batchProducts.length} products');
      } catch (e) {
        print('   ❌ Error deleting batch ${(i ~/ batchSize) + 1}: $e');
        failedCount += batchProducts.length;
        for (final productDoc in batchProducts) {
          failedProducts.add(productDoc.id);
        }
      }
    }

    // Summary
    print('\n' + '=' * 60);
    print('Cleanup Summary');
    print('=' * 60);
    print('✅ Successfully deleted: $deletedCount product(s)');
    if (failedCount > 0) {
      print('❌ Failed to delete: $failedCount product(s)');
      print('   Failed product IDs:');
      for (final id in failedProducts) {
        print('     - $id');
      }
    }
    print('📦 Remaining products: ${allProducts.length - deletedCount}');
    print('=' * 60);
    print('\n✅ Cleanup complete!');

  } catch (e, stackTrace) {
    print('\n❌ Error during cleanup:');
    print('   $e');
    print('\nStack trace:');
    print('   $stackTrace');
    exit(1);
  } finally {
    // Cleanup
    await Firebase.app().delete();
    exit(0);
  }
}

