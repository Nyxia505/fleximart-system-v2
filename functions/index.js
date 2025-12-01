const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function: Automatically create notifications for staff/admin
 * when a customer creates a new quotation.
 *
 * Trigger: onCreate on /quotations/{quotationId}
 */
exports.onQuotationCreated = functions.firestore
  .document('quotations/{quotationId}')
  .onCreate(async (snap, context) => {
    const quotationData = snap.data();
    const quotationId = context.params.quotationId;
    const customerName = quotationData.customerName || 'Customer';
    const productName = quotationData.productName || 'product';

    try {
      // Get all admin users
      const adminSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'admin')
        .get();

      // Get all staff users
      const staffSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'staff')
        .get();

      // Create batch for Firestore notifications
      const batch = admin.firestore().batch();

      // Collect FCM tokens for push notifications
      const tokens = [];

      // Create notification for each admin
      adminSnapshot.forEach((adminDoc) => {
        const notificationRef = admin.firestore()
          .collection('notifications')
          .doc();
        
        batch.set(notificationRef, {
          userId: adminDoc.id,
          type: 'new_quotation',
          title: 'New Quotation Request',
          message: `New Quotation Request from ${customerName}`,
          quotationId: quotationId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Collect FCM token
        const adminData = adminDoc.data() || {};
        if (adminData.fcmToken) {
          tokens.push(adminData.fcmToken);
        }
      });

      // Create notification for each staff
      staffSnapshot.forEach((staffDoc) => {
        const notificationRef = admin.firestore()
          .collection('notifications')
          .doc();
        
        batch.set(notificationRef, {
          userId: staffDoc.id,
          type: 'new_quotation',
          title: 'New Quotation Request',
          message: `New Quotation Request from ${customerName}`,
          quotationId: quotationId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Collect FCM token
        const staffData = staffDoc.data() || {};
        if (staffData.fcmToken) {
          tokens.push(staffData.fcmToken);
        }
      });

      // Commit all Firestore notifications
      await batch.commit();

      // Send push notifications
      if (tokens.length > 0) {
        const title = 'New Quotation Request';
        const body = `New quotation request from ${customerName} for ${productName}`;

        const payload = {
          notification: {
            title,
            body,
          },
          data: {
            type: 'new_quotation',
            quotationId,
          },
        };

        await admin.messaging().sendToDevice(tokens, payload);
        console.log(`✅ Push notifications sent to ${tokens.length} admin/staff tokens for quotation ${quotationId}`);
      }

      console.log(`✅ Created notifications for ${adminSnapshot.size} admins and ${staffSnapshot.size} staff members for quotation ${quotationId}`);
      
      return null;
    } catch (error) {
      console.error('❌ Error creating notifications:', error);
      throw error;
    }
  });

/**
 * Chat push notification:
 * Triggered when a new message is created under /chats/{chatRoomId}/messages/{messageId}
 */
exports.sendChatNotification = functions.firestore
  .document('chats/{chatRoomId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const { chatRoomId, messageId } = context.params;

    const senderId = messageData.senderId;
    const receiverId = messageData.receiverId;
    const type = messageData.type || 'text';
    const text = messageData.message || messageData.text || '';

    try {
      if (!receiverId) {
        console.log('⚠️ No receiverId on message, skipping push.');
        return null;
      }

      // Load receiver user document to get FCM token
      const userSnap = await admin.firestore().collection('users').doc(receiverId).get();
      if (!userSnap.exists) {
        console.log(`⚠️ Receiver user ${receiverId} not found.`);
        return null;
      }
      const userData = userSnap.data() || {};
      const token = userData.fcmToken;

      if (!token) {
        console.log(`⚠️ No fcmToken for user ${receiverId}.`);
        return null;
      }

      // Get sender name for title
      let senderName = 'New message';
      if (senderId) {
        const senderSnap = await admin.firestore().collection('users').doc(senderId).get();
        if (senderSnap.exists) {
          const sData = senderSnap.data() || {};
          senderName = sData.fullName || sData.name || sData.email || senderName;
        }
      }

      const body = type === 'image' ? '[Photo]' : (text || 'New message');

      const payload = {
        notification: {
          title: senderName,
          body,
        },
        data: {
          type: 'chat',
          chatRoomId,
          messageId,
        },
      };

      await admin.messaging().sendToDevice(token, payload);
      console.log(`✅ Chat notification sent to ${receiverId} for chat ${chatRoomId}.`);
      return null;
    } catch (error) {
      console.error('❌ Error sending chat notification:', error);
      return null;
    }
  });

/**
 * Order push notification:
 * Triggered when a new order is created under /orders/{orderId}
 * Sends to all admin and staff who have fcmToken.
 */
exports.sendOrderNotification = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const orderData = snap.data();
    const { orderId } = context.params;

    try {
      const customerName =
        orderData.customerName ||
        orderData.fullName ||
        'New order';
      const totalPrice = orderData.totalPrice || 0;
      const orderShortId = orderId.substring(0, 8).toUpperCase();

      const title = 'New Order Placed';
      const body = `Order #${orderShortId} from ${customerName} - ₱${totalPrice.toFixed(2)}`;

      const usersRef = admin.firestore().collection('users');
      const [adminsSnap, staffSnap] = await Promise.all([
        usersRef.where('role', '==', 'admin').get(),
        usersRef.where('role', '==', 'staff').get(),
      ]);

      const tokens = [];
      adminsSnap.forEach((doc) => {
        const data = doc.data() || {};
        if (data.fcmToken) tokens.push(data.fcmToken);
      });
      staffSnap.forEach((doc) => {
        const data = doc.data() || {};
        if (data.fcmToken) tokens.push(data.fcmToken);
      });

      if (tokens.length === 0) {
        console.log('⚠️ No admin/staff FCM tokens found, skipping order push.');
        return null;
      }

      const payload = {
        notification: {
          title,
          body,
        },
        data: {
          type: 'new_order',
          orderId,
        },
      };

      await admin.messaging().sendToDevice(tokens, payload);
      console.log(`✅ Order notification sent to ${tokens.length} admin/staff tokens.`);
      return null;
    } catch (error) {
      console.error('❌ Error sending order notification:', error);
      return null;
    }
  });

/**
 * Order status update push notification:
 * Triggered when an order status is updated under /orders/{orderId}
 * Sends push notification to the customer.
 */
exports.sendOrderStatusUpdateNotification = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const { orderId } = context.params;

    const oldStatus = beforeData.status;
    const newStatus = afterData.status;

    // Only send notification if status actually changed
    if (oldStatus === newStatus) {
      return null;
    }

    try {
      const customerId = afterData.customerId;
      if (!customerId) {
        console.log('⚠️ No customerId found in order, skipping push.');
        return null;
      }

      // Get customer FCM token
      const userSnap = await admin.firestore().collection('users').doc(customerId).get();
      if (!userSnap.exists) {
        console.log(`⚠️ Customer ${customerId} not found, skipping push.`);
        return null;
      }

      const userData = userSnap.data() || {};
      const token = userData.fcmToken;
      if (!token) {
        console.log(`⚠️ No fcmToken for customer ${customerId}, skipping push.`);
        return null;
      }

      // Get product name
      let productName = afterData.productName || 'order';
      if (!productName && afterData.items && Array.isArray(afterData.items) && afterData.items.length > 0) {
        productName = afterData.items[0].productName || 'order';
      }

      // Map status to notification details
      let title, body;
      switch (newStatus.toLowerCase()) {
        case 'paid':
        case 'pending_payment':
          title = 'Payment Received';
          body = `Your ${productName} payment has been received. We are preparing your order.`;
          break;
        case 'shipped':
        case 'for_installation':
          title = 'Order Shipped';
          body = `Your ${productName} has been shipped. Track your delivery.`;
          break;
        case 'awaiting_installation':
        case 'awaiting installation':
        case 'to_receive':
          title = 'Order Received';
          body = `Your ${productName} has been received. Installation will be scheduled soon.`;
          break;
        case 'processing':
          title = 'Order Status Updated';
          body = `Your ${productName} is now processing.`;
          break;
        case 'completed':
          title = 'Order Completed';
          body = `Your ${productName} has been completed. Thank you for your purchase!`;
          break;
        case 'delivered':
          title = 'Order Delivered';
          body = `Your ${productName} has been delivered.`;
          break;
        default:
          title = 'Order Status Updated';
          body = `Your ${productName} is now ${newStatus}.`;
      }

      const payload = {
        notification: {
          title,
          body,
        },
        data: {
          type: 'order_status_update',
          orderId,
          status: newStatus,
        },
      };

      await admin.messaging().sendToDevice(token, payload);
      console.log(`✅ Order status update notification sent to customer ${customerId} for order ${orderId}.`);
      return null;
    } catch (error) {
      console.error('❌ Error sending order status update notification:', error);
      return null;
    }
  });

/**
 * Quotation price update push notification:
 * Triggered when a quotation price is updated under /quotations/{quotationId}
 * Sends push notification to the customer.
 */
exports.sendQuotationPriceUpdateNotification = functions.firestore
  .document('quotations/{quotationId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const { quotationId } = context.params;

    const oldPrice = beforeData.adminTotalPrice;
    const newPrice = afterData.adminTotalPrice;

    // Only send notification if price was set (was null/undefined before and now has value)
    if (oldPrice === newPrice || !newPrice) {
      return null;
    }

    try {
      const customerId = afterData.customerId || afterData.userId;
      if (!customerId) {
        console.log('⚠️ No customerId found in quotation, skipping push.');
        return null;
      }

      // Get customer FCM token
      const userSnap = await admin.firestore().collection('users').doc(customerId).get();
      if (!userSnap.exists) {
        console.log(`⚠️ Customer ${customerId} not found, skipping push.`);
        return null;
      }

      const userData = userSnap.data() || {};
      const token = userData.fcmToken;
      if (!token) {
        console.log(`⚠️ No fcmToken for customer ${customerId}, skipping push.`);
        return null;
      }

      const productName = afterData.productName || 'product';
      const formattedPrice = `₱${newPrice.toFixed(2)}`;

      const title = 'Quotation Ready';
      const body = `Your quotation for ${productName} is ${formattedPrice}`;

      const payload = {
        notification: {
          title,
          body,
        },
        data: {
          type: 'quotation_updated',
          quotationId,
        },
      };

      await admin.messaging().sendToDevice(token, payload);
      console.log(`✅ Quotation price update notification sent to customer ${customerId} for quotation ${quotationId}.`);
      return null;
    } catch (error) {
      console.error('❌ Error sending quotation price update notification:', error);
      return null;
    }
  });

/**
 * Admin-only function to assign roles.
 * Callable from Flutter using FirebaseFunctions.instance.httpsCallable()
 */
exports.setUserRole = functions.https.onCall(async (data, context) => {
  // 1. Ensure caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be authenticated to call this function.'
    );
  }

  // 2. Ensure caller is an admin
  const callerClaims = context.auth.token;
  if (callerClaims.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can assign roles.'
    );
  }

  // 3. Validate input
  const { uid, role } = data;

  if (!uid || !role) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'You must provide both uid and role'
    );
  }

  const allowedRoles = ['admin', 'staff', 'customer'];
  if (!allowedRoles.includes(role)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid role. Allowed roles are: ${allowedRoles.join(', ')}`
    );
  }

  try {
    // 4. Assign custom claims
    await admin.auth().setCustomUserClaims(uid, { role });

    // 5. Update Firestore user document for UI display
    await admin.firestore().collection('users').doc(uid).set(
      {
        role: role,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 6. Success response
    return {
      success: true,
      message: `Role '${role}' assigned to user ${uid}`,
    };

  } catch (error) {
    console.error('Error setting user role: ', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to assign role. Check Cloud Function logs.'
    );
  }
});

