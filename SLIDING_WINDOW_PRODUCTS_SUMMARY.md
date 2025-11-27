# Sliding Window Products in FlexiMart App

## 📱 Overview

The app includes **sliding window products** that customers can browse, view details, request quotations for, and purchase directly.

---

## 🪟 Sliding Window Products Available

### 1. **Double Sliding Window**
- **Price:** ₱4,200.00
- **Description:** Smooth double-pane sliding window with thermal insulation. Easy to operate and maintain.
- **Stock:** 12 units
- **Category:** Sliding window

### 2. **Triple Track Sliding Window**
- **Price:** ₱5,800.00
- **Description:** Three-panel sliding window system. Maximum ventilation and space efficiency.
- **Stock:** 8 units
- **Category:** Sliding window

### 3. **Energy Star Sliding Window**
- **Price:** ₱5,200.00
- **Description:** Energy-efficient sliding window with low-E glass. Reduces heating and cooling costs.
- **Stock:** 10 units
- **Category:** Sliding window

### 4. **Frosted Sliding Window**
- **Price:** ₱3,800.00
- **Description:** Privacy sliding window with frosted glass panels. Perfect for bathrooms and bedrooms.
- **Stock:** 15 units
- **Category:** Sliding window

### 5. **Custom Size Sliding Window**
- **Price:** ₱6,500.00
- **Description:** Made-to-order sliding window in any size. Professional installation available.
- **Stock:** 6 units
- **Category:** Sliding window

---

## 🎯 Where Sliding Window Products Appear

### 1. **Home Dashboard**
- Products are displayed in a grid layout
- Shows up to 6 products by default
- Can be filtered by category "WINDOWS" or "DOORS"
- Each product card shows:
  - Product image
  - Product name
  - Price
  - "REQUEST QUOTATION" button
  - "PROCEED BUY" button

### 2. **Shop Dashboard**
- Full product catalog
- Can filter by "Sliding window" category
- Search functionality
- Product cards with:
  - Image thumbnail
  - Product title
  - Price
  - Description
  - Action buttons

### 3. **Product Details Page**
- Full product information
- Large product image
- Detailed description
- Price display
- Options to:
  - Request Quotation
  - Proceed to Buy

---

## 🔄 User Flow for Sliding Window Products

### **Option 1: Request Quotation**
1. User browses products → Finds sliding window
2. Clicks "REQUEST QUOTATION" button
3. Fills out quotation form:
   - Select Glass Type (Clear, Frosted, Tinted, Laminated, Tempered)
   - Select Aluminum Frame (Silver Anodized, Black Powder-Coated, White Powder-Coated, Bronze Finish)
   - Enter Dimensions (Length ≥ 48", Width ≤ 70")
   - Upload reference image (optional)
   - Add notes
4. Submits quotation request
5. Admin reviews and provides quote

### **Option 2: Proceed to Buy**
1. User browses products → Finds sliding window
2. Clicks "PROCEED BUY" button
3. Fills out order form:
   - Select Glass Type
   - Select Aluminum Frame
   - Enter Dimensions
   - Upload image (optional)
   - Review Material Breakdown
   - Add notes
4. Reviews order summary
5. Clicks "Proceed to Buy"
6. Order is created and saved to Firestore

---

## 📊 Product Data Structure

```dart
{
  'title': 'Double Sliding Window',
  'description': 'Smooth double-pane sliding window...',
  'price': 4200.0,
  'stock': 12,
  'imageUrl': 'https://...',
  'category': 'Sliding window',
  'minStock': 8,
  'createdAt': Timestamp,
  'updatedAt': Timestamp,
}
```

---

## 🛠️ Technical Implementation

### **Files Involved:**
1. `lib/services/sample_data_service.dart` - Product data seeding
2. `lib/customer/dashboard_home.dart` - Home dashboard display
3. `lib/customer/dashboard_shop.dart` - Shop catalog display
4. `lib/screen/request_quotation_screen.dart` - Quotation form
5. `lib/screen/proceed_buy_screen.dart` - Purchase form
6. `lib/pages/product_details_page.dart` - Product detail view

### **Category Mapping:**
- Route category: `'sliding window'`
- Firestore category: `'Sliding window'`
- Display category: `'WINDOWS'` or `'DOORS'`

---

## ✅ Features Available

- ✅ Browse sliding window products
- ✅ View product details
- ✅ Search for sliding windows
- ✅ Filter by category
- ✅ Request custom quotation
- ✅ Direct purchase with customization
- ✅ Material breakdown display
- ✅ Image upload for reference
- ✅ Dimension validation
- ✅ Order tracking

---

## 🎨 Product Display Example

```
┌─────────────────────────────────┐
│  [Product Image]                │
│                                 │
│  Double Sliding Window          │
│  ₱4,200.00                      │
│                                 │
│  [REQUEST QUOTATION] [BUY NOW]  │
└─────────────────────────────────┘
```

---

## 📝 Notes

- All sliding window products are stored in Firestore `products` collection
- Products can be managed by admin through admin dashboard
- Stock levels are tracked
- Custom orders can be placed with specific dimensions and materials
- Quotations allow customers to get price estimates before purchasing

