# 📦 Product Listing Page

## Overview

A dedicated product listing page that fetches all products from Firestore `/products` collection and displays them in a responsive grid layout.

## Features

✅ **Fetches from Firestore** - Real-time updates using `StreamBuilder`  
✅ **Base64 Image Support** - Uses `ProductBase64Image` widget for displaying images  
✅ **Responsive Grid Layout** - Adapts to different screen sizes:
   - Desktop (>1200px): 4 columns
   - Tablet (>800px): 3 columns
   - Large Phone (>600px): 2 columns
   - Phone: 2 columns

✅ **Product Information Display**:
   - Product name
   - Category (with badge)
   - Price (formatted as ₱)
   - Created date (relative format)

✅ **Error Handling**:
   - Loading state
   - Error state with retry button
   - Empty state

✅ **Navigation** - Tapping a product navigates to product details page

## Product Data Structure

The page expects products from Firestore `/products` collection with:

```dart
{
  'name': String,           // Product name
  'category': String,       // Product category
  'price': Number,          // Product price
  'imageBase64': String,    // Base64 encoded image (or 'image' field)
  'createdAt': Timestamp,   // Creation timestamp
}
```

## Usage

### Navigate to Product Listing

```dart
Navigator.pushNamed(context, '/products');
```

Or directly:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const ProductListingPage(),
  ),
);
```

### Example: Add Button to Navigate

```dart
ElevatedButton(
  onPressed: () {
    Navigator.pushNamed(context, '/products');
  },
  child: const Text('View All Products'),
)
```

## File Structure

- **`lib/pages/product_listing_page.dart`** - Main product listing page
- **`lib/widgets/product_base64_image.dart`** - Base64 image widget (reused)
- **Route**: `/products` (defined in `lib/main.dart`)

## Customization

### Change Grid Layout

Edit `_getCrossAxisCount()` method in `ProductListingPage`:

```dart
int _getCrossAxisCount(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width > 1200) return 4;  // Desktop
  else if (width > 800) return 3;  // Tablet
  else return 2;  // Phone
}
```

### Change Card Aspect Ratio

Edit `childAspectRatio` in `GridView.builder`:

```dart
gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: _getCrossAxisCount(context),
  childAspectRatio: 0.7,  // Adjust this value (lower = taller cards)
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
),
```

### Change Sorting

Edit the Firestore query in `StreamBuilder`:

```dart
stream: FirebaseFirestore.instance
    .collection('products')
    .orderBy('createdAt', descending: true)  // Change this
    .snapshots(),
```

Options:
- `.orderBy('price', descending: false)` - Sort by price (low to high)
- `.orderBy('name')` - Sort alphabetically
- `.orderBy('category')` - Sort by category

## Testing

1. **Add test products** to Firestore `/products` collection:
   ```json
   {
     "name": "Test Product",
     "category": "Windows",
     "price": 2500,
     "imageBase64": "/9j/4AAQSkZJRg...",
     "createdAt": "2025-01-16T12:00:00Z"
   }
   ```

2. **Navigate to the page**:
   ```dart
   Navigator.pushNamed(context, '/products');
   ```

3. **Verify**:
   - Products load from Firestore
   - Images display correctly
   - Grid layout is responsive
   - Tapping a product navigates to details

## Integration with Existing Code

The page integrates seamlessly with:
- **Product Details Page** - Navigates to `ProductDetailsPage` when tapped
- **Product Base64 Image Widget** - Reuses existing image widget
- **App Colors & Text Styles** - Uses app-wide design system

## Notes

- The page handles both `imageBase64` and `image` field names for backward compatibility
- Images are decoded using `base64Decode()` from `dart:convert`
- Real-time updates: Products appear/disappear automatically when Firestore data changes
- Error handling includes user-friendly messages and retry functionality

