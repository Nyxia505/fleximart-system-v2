# Order History Test Guide

## ✅ How to Verify Order History is Functional

### Method 1: Quick Test (Using Firebase Console)

1. **Open Firebase Console**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Navigate to **Firestore Database**

2. **Find or Create a Test Order**
   - Go to `orders` collection
   - Find an order with your user ID in `customerId` field
   - Or create a test order document

3. **Update Order Status**
   - Edit the order document
   - Change `status` field to one of these:
     - `"completed"` ✅
     - `"awaiting_installation"` ✅
     - `"delivered"` ✅

4. **Check Order History in App**
   - Open your app
   - Go to **Quick Actions** → **Order History**
   - The order should appear immediately!

### Method 2: Full Flow Test

1. **Place an Order**
   - Log in as customer
   - Add items to cart
   - Complete checkout
   - Order status: `pending_payment` or `paid`

2. **Admin/Staff Updates Status**
   - Admin/Staff marks order as `shipped`
   - Order appears in customer's "To Receive" tab

3. **Customer Confirms Receipt**
   - Go to **My Purchases** → **To Receive** tab
   - Find the shipped order
   - Click **"Confirm Received"** button
   - Order status changes to:
     - `awaiting_installation` (if installation needed)
     - `completed` (if no installation)

4. **Check Order History**
   - Go to **Quick Actions** → **Order History**
   - Order should now appear! ✅

## 🔍 Debug Logging

I've added debug logging to help you verify it's working. Check your console/debug output:

### When Opening Order History:
```
📦 Order History: Found X total orders for user
   - Order ABC12345: status = "paid"
   - Order DEF67890: status = "completed"
   ⚠️ Order ABC12345 filtered out (status: "paid")
✅ Order History: Showing 1 received/completed orders
```

### When Confirming Order Receipt:
```
✅ Confirming order receipt: orderId123
   - New status: completed
   - Requires installation: false
✅ Order status updated successfully. Order should now appear in Order History.
```

## 📋 What Order History Shows

Order History displays orders with these statuses:
- ✅ `completed` - Order received and completed
- ✅ `awaiting_installation` - Order received, waiting for installation
- ✅ `delivered` - Legacy delivered status

**Does NOT show:**
- ❌ `pending_payment` - Not paid yet
- ❌ `paid` - Paid but not shipped
- ❌ `shipped` - Shipped but not received
- ❌ `to_receive` - Waiting for customer to receive

## 🧪 Quick Test Checklist

- [ ] Open Order History page
- [ ] Check console for debug logs showing order counts
- [ ] If empty, manually update an order status in Firestore to `completed`
- [ ] Refresh Order History - order should appear
- [ ] Click "View Details" on an order - should navigate to order details
- [ ] Verify order information is correct (date, amount, items)

## 🐛 Troubleshooting

### If Order History is Empty:

1. **Check Order Status in Firestore**
   - Order must have status: `completed`, `awaiting_installation`, or `delivered`
   - Order must have `customerId` matching your user ID

2. **Check Debug Logs**
   - Look for: `📦 Order History: Found X total orders`
   - Look for: `⚠️ Order filtered out` messages
   - Look for: `✅ Order History: Showing X received/completed orders`

3. **Verify User ID**
   - Make sure `customerId` in order matches your Firebase Auth user ID

### If Orders Don't Appear After Confirming Receipt:

1. **Check Console Logs**
   - Should see: `✅ Order status updated successfully`
   - Should see: `✅ Order History: Showing X orders` (increased count)

2. **Verify Status Update**
   - Check Firestore - order status should be `completed` or `awaiting_installation`
   - Wait a few seconds for StreamBuilder to refresh

3. **Check Network Connection**
   - Firestore needs internet connection to sync

## 📊 Expected Behavior

✅ **Working Correctly:**
- Orders appear in Order History after confirming receipt
- Orders sorted by date (newest first)
- Real-time updates when order status changes
- Empty state shows helpful message when no orders
- "View Details" button works

❌ **Not Working:**
- Order History always empty
- Orders don't appear after confirming receipt
- Error messages in console
- App crashes when opening Order History

## 🎯 Test Scenario

**Complete Test Flow:**
1. Create order → Status: `paid`
2. Admin marks as shipped → Status: `shipped`
3. Customer confirms receipt → Status: `completed`
4. Check Order History → Order appears! ✅

**Quick Test:**
1. Open Firestore
2. Change any order status to `completed`
3. Open Order History → Should appear immediately! ✅

