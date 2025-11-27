# How to Add Products to FlexiMart App

## 📱 Methods to Add Products

### **Method 1: Through Admin Dashboard (Recommended)**

1. **Login as Admin**
   - Open the app
   - Login with admin credentials

2. **Navigate to Products Section**
   - Go to Admin Dashboard
   - Click on "Products" tab/section
   - Click "Add Product" button

3. **Fill Product Form**
   - **Title**: Product name (e.g., "Premium Sliding Window")
   - **Description**: Product details and features
   - **Price**: Product price in PHP (e.g., 4800.0)
   - **Stock**: Available quantity (e.g., 10)
   - **Category**: Select from dropdown:
     - Mantle
     - Frames
     - Sliding window
     - Doors
     - Glass type
   - **Image**: Upload product image or enter image URL
   - **Min Stock**: Minimum stock level (optional, defaults to half of stock)

4. **Save Product**
   - Click "Add Product" button
   - Product will be saved to Firestore
   - Success message will appear

---

### **Method 2: Programmatically (For Developers)**

#### **Option A: Add Single Product**

```dart
import 'package:fleximart/services/product_add_helper.dart';

// Add a single product
await ProductAddHelper.addProduct(
  title: 'Premium Sliding Window',
  description: 'High-quality sliding window with built-in screen',
  price: 4800.0,
  stock: 10,
  category: 'Sliding window',
  imageUrl: 'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=400',
  minStock: 6,
);
```

#### **Option B: Add Multiple Products**

```dart
import 'package:fleximart/services/product_add_helper.dart';

// Add multiple sliding window products
await ProductAddHelper.addMoreSlidingWindowProducts();

// Add more door products
await ProductAddHelper.addMoreDoorProducts();

// Add more glass products
await ProductAddHelper.addMoreGlassProducts();

// Add more frame products
await ProductAddHelper.addMoreFrameProducts();
```

#### **Option C: Custom Product List**

```dart
import 'package:fleximart/services/product_add_helper.dart';

final products = [
  {
    'title': 'Custom Product 1',
    'description': 'Product description here',
    'price': 3000.0,
    'stock': 15,
    'minStock': 8,
    'category': 'Sliding window',
    'imageUrl': 'https://example.com/image.jpg',
  },
  {
    'title': 'Custom Product 2',
    'description': 'Another product description',
    'price': 4500.0,
    'stock': 12,
    'minStock': 6,
    'category': 'Doors',
    'imageUrl': 'https://example.com/image2.jpg',
  },
];

await ProductAddHelper.addMultipleProducts(products);
```

---

### **Method 3: Using Sample Data Service**

```dart
import 'package:fleximart/services/sample_data_service.dart';

// Seed all sample products (includes existing products)
await SampleDataService.seedProducts();
```

**Note:** This will add all predefined products. Check `lib/services/sample_data_service.dart` to see existing products.

---

## 📋 Product Data Structure

Each product must have the following fields:

```dart
{
  'title': String,              // Required: Product name
  'description': String,        // Required: Product description
  'price': double,             // Required: Product price
  'stock': int,                // Required: Available quantity
  'category': String,          // Required: Product category
  'imageUrl': String?,         // Optional: Product image URL
  'minStock': int?,            // Optional: Minimum stock level
  'createdAt': Timestamp,      // Auto-generated
  'updatedAt': Timestamp,      // Auto-generated
}
```

### **Available Categories:**
- `'Mantle'`
- `'Frames'`
- `'Sliding window'`
- `'Doors'`
- `'Glass type'`

---

## 🎯 Quick Add Examples

### **Add More Sliding Windows:**

```dart
await ProductAddHelper.addMoreSlidingWindowProducts();
```

This adds 5 new sliding window products:
1. Premium Sliding Window with Screen - ₱4,800
2. Soundproof Sliding Window - ₱6,200
3. Bay Sliding Window - ₱7,500
4. Picture Sliding Window - ₱6,800
5. Tilt & Slide Window - ₱5,500

### **Add More Doors:**

```dart
await ProductAddHelper.addMoreDoorProducts();
```

This adds 3 new door products:
1. Bi-Fold Glass Door - ₱4,500
2. Pivot Glass Door - ₱5,800
3. Frameless Glass Door - ₱5,200

### **Add More Glass Types:**

```dart
await ProductAddHelper.addMoreGlassProducts();
```

This adds 3 new glass products:
1. Reflective Glass 6mm - ₱1,950
2. Smart Glass - ₱8,500
3. Bulletproof Glass - ₱12,000

---

## ✅ Verification

After adding products:

1. **Check Firestore Console**
   - Go to Firebase Console
   - Navigate to Firestore Database
   - Check `products` collection
   - Verify new products are added

2. **Check in App**
   - Open customer dashboard
   - Go to Shop
   - Filter by category
   - Verify products appear

---

## 🔧 Troubleshooting

### **Product Not Appearing:**
- Check Firestore rules allow read access
- Verify category name matches exactly (case-sensitive)
- Check if product has valid imageUrl
- Ensure stock > 0

### **Error Adding Product:**
- Check internet connection
- Verify Firestore rules allow write access for admin
- Ensure all required fields are filled
- Check price is a valid number (not negative)

---

## 📝 Notes

- Products are stored in Firestore `products` collection
- Products automatically appear in customer shop after adding
- Stock levels can be updated later through admin dashboard
- Images can be uploaded to Firebase Storage or use external URLs
- Categories are case-sensitive - use exact category names

