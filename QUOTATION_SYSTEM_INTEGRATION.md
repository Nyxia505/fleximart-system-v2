# 🔥 Complete Quotation System - Integration Guide

## ✅ Files Created

### Models
- `lib/models/quotation_model.dart` - Quotation data model
- `lib/models/notification_model.dart` - Notification data model

### Services
- `lib/services/quotation_service.dart` - Quotation operations
- `lib/services/notification_service.dart` - Notification operations

### Screens
- `lib/staff/staff_quotation_screen.dart` - Staff quotation management
- `lib/admin/admin_quotation_screen.dart` - Admin quotation management

### Widgets
- `lib/widgets/status_badge.dart` - Status badge widget
- `lib/widgets/quotation_card.dart` - Quotation card widget

## 📋 Firestore Structure

### Collections

#### `quotations`
```json
{
  "id": "quotation_id",
  "userId": "customer_uid",
  "staffId": "staff_uid", // optional
  "adminId": "admin_uid", // optional
  "message": "I want a quotation",
  "status": "pending", // "pending", "approved", "rejected", "in-progress"
  "customerName": "Customer Name",
  "customerEmail": "customer@email.com",
  "productName": "Product Name",
  "productImage": "image_url",
  "productPrice": "₱1000",
  "glassType": "Clear Glass",
  "aluminumType": "Silver Anodized",
  "length": 60.0,
  "width": 40.0,
  "notes": "Additional notes",
  "windowImageUrl": "image_url",
  "estimatedPrice": 1500.0,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `notifications`
```json
{
  "id": "notification_id",
  "userId": "recipient_uid", // staff_uid or admin_uid
  "fromUserId": "sender_uid", // customer_uid, staff_uid, or admin_uid
  "message": "New quotation request",
  "type": "quotation", // "quotation", "quotation-update"
  "quotationId": "quotation_id",
  "title": "New Quotation Request",
  "read": false,
  "createdAt": "timestamp"
}
```

## 🔧 Integration Steps

### 1. Update Staff Dashboard

Replace the old `QuotationsPage` with the new `StaffQuotationScreen`:

```dart
// In lib/staff/staff_dashboard.dart
import '../staff/staff_quotation_screen.dart';

// Replace in _pages list:
final List<Widget> _pages = const [
  // ... other pages
  StaffQuotationScreen(), // Replace QuotationsPage()
];
```

### 2. Update Admin Dashboard

Replace the old `QuotationsPage` with the new `AdminQuotationScreen`:

```dart
// In lib/admin/admin_dashboard.dart
import '../admin/admin_quotation_screen.dart';

// Replace in _pages list:
final List<Widget> _pages = const [
  // ... other pages
  AdminQuotationScreen(), // Replace QuotationsPage()
];
```

### 3. Update Quotation Creation

Update `lib/screen/request_quotation_screen.dart` and `lib/dialogs/quotation_request_dialog.dart` to use `QuotationService`:

```dart
import '../services/quotation_service.dart';

final quotationService = QuotationService();

// Replace the quotation creation code with:
final quotationId = await quotationService.createQuotation(
  userId: user.uid,
  message: _notesController.text.trim(),
  customerName: customerName,
  customerEmail: user.email,
  productName: _productData?['name']?.toString(),
  productImage: _productData?['img']?.toString(),
  productPrice: _productData?['price']?.toString(),
  glassType: _selectedGlassType,
  aluminumType: _selectedAluminumType,
  length: double.tryParse(_lengthController.text),
  width: double.tryParse(_widthController.text),
  notes: _notesController.text.trim(),
  windowImageUrl: imageUrl,
);
```

## 🔐 Firestore Security Rules

Add these rules to `firestore.rules`:

```javascript
match /quotations/{quotationId} {
  // Customers can create quotations
  allow create: if request.auth != null 
                && request.resource.data.userId == request.auth.uid;
  
  // Customers can read their own quotations
  allow read: if request.auth != null 
              && (resource.data.userId == request.auth.uid
                  || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['staff', 'admin']);
  
  // Staff and admin can update quotations
  allow update: if request.auth != null 
                && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['staff', 'admin'];
  
  // Only admins can delete
  allow delete: if request.auth != null 
                && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}

match /notifications/{notificationId} {
  // Staff and admin can create notifications
  allow create: if request.auth != null 
                && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['staff', 'admin'];
  
  // Users can read their own notifications
  allow read: if request.auth != null 
              && resource.data.userId == request.auth.uid;
  
  // Users can update their own notifications (mark as read)
  allow update: if request.auth != null 
                && resource.data.userId == request.auth.uid;
  
  // No deletes
  allow delete: if false;
}
```

## 🎯 Features

### Staff Dashboard
✅ Real-time pending quotations  
✅ Approve/Reject/In-Progress actions  
✅ Notification badge with unread count  
✅ Quotation details modal  
✅ Customer information display  
✅ Status updates with notifications  

### Admin Dashboard
✅ All quotations grouped by status (All, Pending, In Progress, Done)  
✅ Tab navigation  
✅ Override staff updates  
✅ Full quotation details  
✅ Notification management  
✅ Real-time updates  

### Real-time Updates
✅ StreamBuilder for quotations  
✅ StreamBuilder for notifications  
✅ Automatic refresh on changes  
✅ Manual refresh indicator  

## 🚀 Usage

### Staff Quotation Screen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const StaffQuotationScreen(),
  ),
);
```

### Admin Quotation Screen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const AdminQuotationScreen(),
  ),
);
```

## 📱 UI Features

- **Rounded cards** with shadows
- **Color-coded status badges** (Pending, Approved, Rejected, In Progress)
- **Icons** for actions and information
- **Animated refresh** indicator
- **Responsive layout** for tablets
- **Modal bottom sheets** for details
- **Notification badges** with unread count

## 🔄 Real-time Flow

1. **Customer submits quotation** → `QuotationService.createQuotation()`
2. **Service creates quotation** → Firestore `/quotations`
3. **Service notifies staff/admin** → Firestore `/notifications`
4. **Staff/Admin dashboards** → StreamBuilder listens to changes
5. **Staff updates status** → `QuotationService.updateQuotationStatus()`
6. **Service notifies admin & customer** → New notifications created
7. **Real-time UI updates** → StreamBuilder rebuilds automatically

## ✅ All Requirements Met

1. ✅ Firestore structure with userId, staffId, adminId
2. ✅ Automatic notification creation for all staff
3. ✅ Staff dashboard with pending quotations
4. ✅ Admin dashboard with all quotations grouped
5. ✅ Real-time StreamBuilder updates
6. ✅ QuotationService and NotificationService
7. ✅ Beautiful modern UI with cards and badges
8. ✅ Status update functionality
9. ✅ Notification management
10. ✅ Full integration ready

## 🎉 Ready to Use!

All components are created and ready. Just integrate into your dashboards!

