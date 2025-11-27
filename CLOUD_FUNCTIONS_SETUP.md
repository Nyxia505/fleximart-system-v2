# 🔧 Cloud Functions Setup Guide

## 📦 Step 1: Install Dependencies

First, install the Flutter package:

```bash
flutter pub get
```

This will install the `cloud_functions` package that was added to `pubspec.yaml`.

## 🚀 Step 2: Deploy Cloud Functions

Navigate to the functions directory and install Node.js dependencies:

```bash
cd functions
npm install
```

Then deploy the functions to Firebase:

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy from project root
cd ..
firebase deploy --only functions
```

## ✅ Step 3: Verify Functions are Deployed

Check Firebase Console → Functions to see:
- `onQuotationCreated` - Triggered when quotations are created
- `setUserRole` - Callable function for role assignment

## 📱 Step 4: Use in Flutter

### Basic Usage

```dart
import 'package:fleximart/services/role_service.dart';

// Assign a role to a user
try {
  final result = await RoleService.assignUserRole(
    'user_uid_here',
    'staff', // or 'admin', 'customer'
  );
  
  print('Success: ${result['message']}');
} catch (e) {
  print('Error: $e');
}
```

### Helper Methods

```dart
// Assign admin role
await RoleService.assignAdminRole('user_uid_here');

// Assign staff role
await RoleService.assignStaffRole('user_uid_here');

// Assign customer role
await RoleService.assignCustomerRole('user_uid_here');
```

### Example in Admin Dashboard

The admin dashboard already has role assignment integrated. When you click "Edit" on a staff member, you can change their role using the Cloud Function.

## 🔐 Security Notes

1. **Only admins can call `setUserRole`** - The Cloud Function checks for admin role in custom claims
2. **Custom claims are set** - The function sets both:
   - Firebase Auth custom claims (for security rules)
   - Firestore user document (for UI display)

## 🐛 Troubleshooting

### Error: "Target of URI doesn't exist"
- Run `flutter pub get` to install dependencies

### Error: "permission-denied"
- Make sure the current user has admin role set in Firebase Auth custom claims
- The function checks `context.auth.token.role === 'admin'`

### Error: "unauthenticated"
- User must be logged in to call the function

### Functions not deploying
- Make sure you're logged in: `firebase login`
- Check Firebase project: `firebase use fleximart-system`
- Verify Node.js is installed: `node --version` (should be 18+)

## 📝 Files Created

- `functions/index.js` - Cloud Functions code
- `functions/package.json` - Node.js dependencies
- `lib/services/role_service.dart` - Flutter service to call functions
- `lib/examples/role_service_example.dart` - Example usage

## 🎯 Next Steps

1. Run `flutter pub get`
2. Deploy functions: `firebase deploy --only functions`
3. Test role assignment in admin dashboard
4. Verify notifications are created automatically when quotations are created

