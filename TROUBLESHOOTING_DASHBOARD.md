# Troubleshooting: Admin/Staff Dashboard Access

## Problem: Cannot access Admin or Staff dashboard

### Common Causes & Solutions:

## 1. ✅ Check User Role in Firestore

The most common issue is that your user doesn't have the correct role set in Firestore.

### How to Fix:

1. **Open Firebase Console** → Firestore Database
2. **Navigate to** `users` collection
3. **Find your user document** (by UID or email)
4. **Check/Add the `role` field:**
   - For Admin: Set `role` = `"admin"`
   - For Staff: Set `role` = `"staff"`
   - For Customer: Set `role` = `"customer"` (default)

### Quick Fix Script:

You can use the helper function in `lib/utils/role_helper.dart`:

```dart
import 'lib/utils/role_helper.dart';

// Set admin role
await RoleHelper.setUserRole('admin');

// Set staff role  
await RoleHelper.setUserRole('staff');
```

## 2. ✅ Verify User Document Exists

Make sure your user document exists in Firestore `users` collection with:
- `email`: user's email
- `role`: "admin" or "staff"
- `fullName`: (optional) user's display name

## 3. ✅ Check Authentication Flow

The app routes based on `auth.role` from `AuthProvider`:
- Admin role → AdminDashboard
- Staff role → StaffDashboard  
- Customer role (or no role) → CustomerDashboard

## 4. ✅ Test Access Directly

You can test dashboard access by navigating directly:
- `/admin` route for Admin Dashboard
- `/staff` route for Staff Dashboard

## 5. ✅ Debug Current Role

Add this to check your current role:

```dart
import 'lib/utils/role_helper.dart';

// Check current role
final role = await RoleHelper.getUserRole();
print('Current role: $role');
```

## 6. ✅ Manual Firestore Setup

**For Admin User:**
```json
{
  "email": "admin@email.com",
  "fullName": "Admin User",
  "role": "admin"
}
```

**For Staff User:**
```json
{
  "email": "staff@email.com", 
  "fullName": "Staff User",
  "role": "staff"
}
```

## Quick Test Steps:

1. **Logout** from the app
2. **Login** with your admin/staff credentials
3. **Check Firestore** - verify role is set correctly
4. **Refresh app** or restart
5. **Should redirect** to correct dashboard automatically

## Still Not Working?

1. Check console for errors
2. Verify Firebase connection
3. Check if AuthProvider is loading correctly
4. Ensure user is properly authenticated in Firebase Auth

