const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const nodemailer = require('nodemailer');

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
 * OTP Push Notification:
 * Callable function to send OTP code via push notification.
 * Can be called from Flutter app with FCM token and OTP code.
 */
/**
 * Send OTP via FCM (HTTP v1 API — replaces deprecated sendToDevice).
 * @returns {Promise<string>} message ID
 */
async function sendOtpPushToToken(fcmToken, otpCode, email) {
  const title = 'FlexiMart Verification Code';
  const body = `Your verification code is: ${otpCode}`;

  const messageId = await admin.messaging().send({
    token: fcmToken,
    notification: { title, body },
    data: {
      type: 'otp_verification',
      email: email || '',
      otp: String(otpCode),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'high_importance_channel',
        priority: 'high',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  });

  console.log(`✅ OTP push sent (${messageId}) to ${fcmToken.substring(0, 12)}...`);
  return messageId;
}

exports.sendOtpNotification = functions.https.onCall(async (data, context) => {
  const { fcmToken, otpCode, email } = data;

  if (!fcmToken || !otpCode) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'fcmToken and otpCode are required'
    );
  }

  try {
    await sendOtpPushToToken(fcmToken, otpCode, email || '');
    return {
      success: true,
      message: 'OTP push notification sent successfully',
    };
  } catch (error) {
    console.error('❌ Error sending OTP push notification:', error);
    throw new functions.https.HttpsError(
      'internal',
      error?.message || 'Failed to send OTP push notification'
    );
  }
});

/**
 * Callable function to send OTP via Email using SMTP (recommended path).
 * Expects: { toEmail, otp, toName }
 *
 * This no longer depends on EmailJS from the server side to avoid
 * "Gmail_API: Invalid grant" issues. Configure SMTP via:
 *   firebase functions:config:set smtp.host="..." smtp.port="465" ...
 */
async function loadAppEmailConfig() {
  try {
    const doc = await admin.firestore().collection('app_config').doc('emailjs').get();
    return doc.exists ? doc.data() : {};
  } catch (e) {
    console.warn('⚠️ Could not load app_config/emailjs:', e.message || e);
    return {};
  }
}

/**
 * Send OTP email via SMTP, EmailJS, and/or Firestore mail queue.
 * @returns {{ method: string }}
 */
async function deliverOtpEmail(toEmail, otp, toName, data = {}) {
  const firestoreCfg = await loadAppEmailConfig();
  const smtpConfig = functions.config().smtp || {};
  const gmailConfig = functions.config().gmail || {};

  let smtpHost = process.env.SMTP_HOST || smtpConfig.host;
  let smtpPortRaw = process.env.SMTP_PORT || smtpConfig.port;
  let smtpUser = data.smtpUser || process.env.SMTP_USER || smtpConfig.user || firestoreCfg.smtpUser;
  let smtpPass = data.smtpPass || process.env.SMTP_PASS || smtpConfig.pass || firestoreCfg.smtpPass;

  if ((!smtpHost || !smtpUser || !smtpPass) && (gmailConfig.user || process.env.GMAIL_USER)) {
    smtpHost = 'smtp.gmail.com';
    smtpPortRaw = smtpPortRaw || '465';
    smtpUser = process.env.GMAIL_USER || gmailConfig.user;
    smtpPass = process.env.GMAIL_PASS || gmailConfig.pass;
  }

  if ((!smtpHost || !smtpUser || !smtpPass) && firestoreCfg.smtpUser && firestoreCfg.smtpPass) {
    smtpHost = 'smtp.gmail.com';
    smtpPortRaw = smtpPortRaw || '465';
    smtpUser = firestoreCfg.smtpUser;
    smtpPass = firestoreCfg.smtpPass;
  }

  if (smtpUser && smtpPass && !smtpHost) {
    smtpHost = 'smtp.gmail.com';
    smtpPortRaw = smtpPortRaw || '465';
  }

  const smtpPort = smtpPortRaw ? parseInt(smtpPortRaw, 10) : 465;
  const fromEmail = process.env.FROM_EMAIL || smtpConfig.from_email || smtpUser || 'queenyvonnedalahay@gmail.com';
  const fromName = process.env.FROM_NAME || smtpConfig.from_name || 'FlexiMart';
  const displayName = toName || toEmail;

  if (smtpHost && smtpPort && smtpUser && smtpPass) {
    try {
      const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: smtpPort,
        secure: smtpPort === 465,
        auth: { user: smtpUser, pass: smtpPass },
      });

      await transporter.sendMail({
        from: `${fromName} <${fromEmail}>`,
        to: toEmail,
        subject: 'Your FlexiMart verification code',
        text: `Your FlexiMart verification code is: ${otp}. This code expires in 5 minutes.`,
        html: `<p>Hello ${displayName},</p><p>Your FlexiMart verification code is: <strong>${otp}</strong></p><p>This code expires in 5 minutes. Open Gmail on your phone to read this message.</p>`,
      });
      console.log('✅ deliverOtpEmail via SMTP to', toEmail);
      return { method: 'smtp' };
    } catch (smtpErr) {
      const smtpMsg = smtpErr?.message || String(smtpErr);
      console.error('❌ deliverOtpEmail SMTP failed:', smtpMsg);
      if (smtpMsg.toLowerCase().includes('invalid login') ||
          smtpMsg.toLowerCase().includes('authentication') ||
          smtpMsg.toLowerCase().includes('username and password')) {
        throw new Error(
          'GMAIL_SMTP_AUTH_FAILED: smtpPass must be a 16-character Gmail App Password '
          + '(Google Account → Security → App passwords), not your normal Gmail password.'
        );
      }
    }
  } else if (smtpUser && !smtpPass) {
    console.warn('⚠️ smtpUser set but smtpPass missing in app_config/emailjs');
  }

  const hasEmailJsTemplate = !!(
    data.templateId ||
    firestoreCfg.templateId ||
    process.env.EMAILJS_TEMPLATE_ID ||
    (functions.config().emailjs || {}).template_id ||
    'template_ac0np7l'
  );
  if (hasEmailJsTemplate) {
    try {
      await sendOtpViaEmailJs(toEmail, otp, displayName, data, firestoreCfg);
      return { method: 'emailjs' };
    } catch (emailJsErr) {
      console.error('❌ deliverOtpEmail EmailJS failed:', emailJsErr?.response?.data || emailJsErr?.message || emailJsErr);
    }
  }

  try {
    await admin.firestore().collection('mail').add({
      to: toEmail,
      message: {
        subject: 'Your FlexiMart verification code',
        text: `Your FlexiMart verification code is: ${otp}. Expires in 5 minutes.`,
        html: `<p>Hello ${displayName},</p><p>Your FlexiMart verification code is: <strong>${otp}</strong></p>`,
      },
    });
    console.log('📧 deliverOtpEmail queued mail collection (needs Trigger Email extension)');
  } catch (mailErr) {
    console.error('❌ deliverOtpEmail mail queue failed:', mailErr?.message || mailErr);
  }

  throw new Error(
    'EMAIL_SETUP_REQUIRED: In Firestore app_config/emailjs set smtpUser + smtpPass (Gmail App Password), ' +
    'or enable EmailJS non-browser API at dashboard.emailjs.com/admin/account/security'
  );
}

function buildEmailJsTemplateParams(toEmail, toName, otp) {
  const code = String(otp);
  return {
    to_email: toEmail,
    to_name: toName,
    otp: code,
    email: toEmail,
    name: toName,
    user_email: toEmail,
    user_name: toName,
    verification_code: code,
    passcode: code,
    code,
    message: `Your FlexiMart verification code is ${code}. It expires in 5 minutes.`,
    subject: 'FlexiMart Verification Code',
    from_name: 'FlexiMart',
  };
}

async function sendOtpViaEmailJs(toEmail, otp, toName, data, firestoreCfg = {}) {
  const emailjsConfig = functions.config().emailjs || {};
  const serviceId = data.serviceId || firestoreCfg.serviceId || process.env.EMAILJS_SERVICE_ID || emailjsConfig.service_id || 'service_1dhvvdp';
  const templateId = data.templateId || firestoreCfg.templateId || process.env.EMAILJS_TEMPLATE_ID || emailjsConfig.template_id || 'template_ac0np7l';
  const publicKey = data.publicKey || firestoreCfg.publicKey || process.env.EMAILJS_PUBLIC_KEY || emailjsConfig.public_key || 'TMXZA9w62NrPr-zjY';
  const privateKey = data.privateKey || firestoreCfg.privateKey || process.env.EMAILJS_PRIVATE_KEY || emailjsConfig.private_key || 'mgsii9qp4xF4Fphe19cj_';

  const templateParams = buildEmailJsTemplateParams(toEmail, toName, otp);

  const trySend = async (usePrivateKey) => {
    const payload = {
      service_id: serviceId,
      template_id: templateId,
      user_id: publicKey,
      template_params: templateParams,
    };
    if (usePrivateKey && privateKey) {
      payload.accessToken = privateKey;
    }
    await axios.post(
      'https://api.emailjs.com/api/v1.0/email/send',
      payload,
      { headers: { 'Content-Type': 'application/json' }, timeout: 20000 }
    );
  };

  const configuredId = (templateId || '').trim();
  if (!configuredId) {
    throw new Error('EmailJS template ID not configured in app_config/emailjs');
  }

  let lastErr;
  try {
    await trySend(true);
    console.log('✅ sendOtpViaEmailJs sent to', toEmail);
    return;
  } catch (err) {
    lastErr = err;
    const msg = String(err?.response?.data || err?.message || '');
    if (msg.toLowerCase().includes('non-browser')) {
      try {
        await trySend(false);
        console.log('✅ sendOtpViaEmailJs sent (public key) to', toEmail);
        return;
      } catch (err2) {
        lastErr = err2;
      }
    }
  }
  const errText = lastErr?.response?.data?.text || lastErr?.response?.data || lastErr?.message || lastErr;
  throw new Error(`EmailJS failed: ${errText}`);
}

exports.sendOtpEmail = functions.https.onCall(async (data, context) => {
  const toEmail = data.toEmail || data.email;
  const otp = data.otp || data.otpCode;
  const toName = data.toName || data.displayName || toEmail;

  if (!toEmail || !otp) {
    throw new functions.https.HttpsError('invalid-argument', 'toEmail and otp are required');
  }

  try {
    const result = await deliverOtpEmail(toEmail, otp, toName, data);
    return { success: true, method: result.method };
  } catch (err) {
    const msg = String(err?.message || err);
    console.error('❌ sendOtpEmail failed:', msg);
    const isSetup =
      msg.includes('GMAIL_SMTP_AUTH_FAILED') ||
      msg.includes('EMAIL_SETUP_REQUIRED');
    throw new functions.https.HttpsError(
      'failed-precondition',
      isSetup
        ? msg.replace(/^[^:]+:\s*/, '')
        : `${msg} — Ensure smtpPass is sent from the app (emailjs.secrets.json) or Firestore app_config/emailjs.`
    );
  }
});

/**
 * Auto-send verification email when a new OTP document is created (signup).
 */
exports.onOtpVerificationCreated = functions.firestore
  .document('otp_verifications/{otpId}')
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const toEmail = (data.toEmail || data.userId || '').toString().trim().toLowerCase();
    const otp = (data.otpCode || '').toString();
    const toName = (data.displayName || toEmail).toString();

    if (!toEmail || otp.length !== 6) {
      console.warn('⚠️ onOtpVerificationCreated: missing toEmail or otp');
      return null;
    }

    const updates = {};

    try {
      const result = await deliverOtpEmail(toEmail, otp, toName, {});
      updates.emailSent = true;
      updates.emailMethod = result.method;
      updates.emailSentAt = admin.firestore.FieldValue.serverTimestamp();
      console.log('✅ onOtpVerificationCreated emailed', toEmail, 'via', result.method);
    } catch (err) {
      updates.emailSent = false;
      updates.emailError = String(err?.message || err).slice(0, 500);
      console.error('❌ onOtpVerificationCreated email failed for', toEmail, err?.message || err);
    }

    let fcmToken = (data.fcmToken || '').toString().trim();
    if (!fcmToken) {
      try {
        const pending = await admin.firestore().collection('pending_signup').doc(toEmail).get();
        if (pending.exists) {
          fcmToken = (pending.data()?.fcmToken || '').toString().trim();
        }
      } catch (pendingErr) {
        console.warn('⚠️ Could not load pending_signup FCM token:', pendingErr?.message || pendingErr);
      }
    }

    if (fcmToken) {
      try {
        await sendOtpPushToToken(fcmToken, otp, toEmail);
        updates.pushSent = true;
        updates.pushSentAt = admin.firestore.FieldValue.serverTimestamp();
      } catch (pushErr) {
        updates.pushSent = false;
        updates.pushError = String(pushErr?.message || pushErr).slice(0, 500);
        console.error('❌ onOtpVerificationCreated push failed for', toEmail, pushErr?.message || pushErr);
      }
    } else {
      updates.pushSent = false;
      updates.pushError = 'No FCM token (enable notifications on device before signup)';
    }

    await snap.ref.update(updates);
    return null;
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

/**
 * Admin/Staff function to create another user account.
 *
 * Usage from Flutter:
 *   final fn = FirebaseFunctions.instance.httpsCallable('adminCreateUser');
 *   await fn.call({
 *     'email': 'newuser@example.com',
 *     'password': 'SomeStrongPassword123',
 *     'fullName': 'New User',
 *     'role': 'customer', // optional, defaults to 'customer'
 *   });
 *
 * Rules:
 * - Callers must be authenticated.
 * - Caller must have custom claim role = 'admin' or 'staff'.
 * - Admin can create admin or staff accounts.
 * - Staff can only create staff accounts.
 */
exports.adminCreateUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in to create a user.'
    );
  }

  const callerUid = context.auth.uid;
  let callerRole = (context.auth.token || {}).role;

  // If role not in custom claims, get it from Firestore (app uses Firestore for role)
  if (callerRole !== 'admin' && callerRole !== 'staff') {
    try {
      const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
      const data = callerDoc.exists ? (callerDoc.data() || {}) : {};
      const raw = data.role;
      callerRole = typeof raw === 'string' ? raw.toLowerCase().trim() : null;
    } catch (e) {
      console.error('adminCreateUser: failed to read caller role from Firestore', e);
    }
  }

  if (callerRole !== 'admin' && callerRole !== 'staff') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins or staff can create new user accounts. Your account may not have a role assigned yet.'
    );
  }

  const { email, password, fullName, username, role } = data || {};

  if (!email || !password) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'You must provide both email and password.'
    );
  }

  const trimmedEmail = String(email).toLowerCase().trim();
  const displayName = fullName ? String(fullName).trim() : '';
  const usernameStr = username ? String(username).trim() : '';

  // Determine role for the new user
  let newUserRole = (role || 'staff').toLowerCase().trim();
  const allowedRoles = ['admin', 'staff', 'customer'];

  if (!allowedRoles.includes(newUserRole)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid role. Allowed roles are: ${allowedRoles.join(', ')}`
    );
  }

  // Staff can only create staff; admins can create admin, staff, or customer
  if (callerRole === 'staff' && newUserRole !== 'staff') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Staff can only create staff accounts.'
    );
  }

  try {
    // 1. Create Firebase Auth user (only include displayName if non-empty to avoid invalid-display-name)
    const createUserOpts = {
      email: trimmedEmail,
      password: String(password),
      emailVerified: false, // Explicitly set to false - no email verification required
      disabled: false, // Ensure account is enabled
    };
    if (displayName && displayName.length > 0) {
      createUserOpts.displayName = displayName;
    }
    
    console.log(`Creating user with email: ${trimmedEmail}, role: ${newUserRole}`);
    const userRecord = await admin.auth().createUser(createUserOpts);

    const uid = userRecord.uid;
    console.log(`User created successfully with UID: ${uid}`);

    // 2. Set custom claims (for admin/staff; optional for customer)
    await admin.auth().setCustomUserClaims(uid, { role: newUserRole });

    // 3. Create Firestore user document (used by your app & rules)
    const userDoc = {
      fullName: displayName,
      email: trimmedEmail,
      role: newUserRole,
      emailVerified: false,
      isVerified: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (usernameStr) userDoc.username = usernameStr;
    await admin.firestore().collection('users').doc(uid).set(userDoc, { merge: true });

    return {
      success: true,
      uid,
      email: trimmedEmail,
      role: newUserRole,
      message: `User ${trimmedEmail} created with role '${newUserRole}'.`,
    };
  } catch (error) {
    const code = error.code || '';
    const errMsg = error.message || String(error);
    console.error('adminCreateUser error:', code, errMsg);

    // Firebase Admin Auth uses error.code (e.g. 'auth/email-already-exists')
    if (code === 'auth/email-already-exists' || errMsg.includes('email-already-exists')) {
      throw new functions.https.HttpsError(
        'already-exists',
        'An account with this email already exists.'
      );
    }
    if (code === 'auth/invalid-password' || errMsg.includes('invalid-password') || errMsg.includes('WEAK_PASSWORD')) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'The password is too weak. Use at least 6 characters.'
      );
    }
    if (code === 'auth/invalid-email' || errMsg.includes('invalid-email')) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Please enter a valid email address.'
      );
    }
    if (code === 'auth/invalid-display-name' || errMsg.includes('invalid-display-name')) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Please enter a full name.'
      );
    }
    if (code === 'auth/operation-not-allowed' || errMsg.includes('operation-not-allowed')) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Email/password sign-in is not enabled. In Firebase Console go to Authentication > Sign-in method and enable Email/Password.'
      );
    }
    if (code === 'auth/internal-error' || code === 'auth/internal') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Authentication service error. Enable Email/Password in Firebase Console under Authentication > Sign-in method, then try again.'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      'Failed to create user. Please try again or contact support.'
    );
  }
});

const STORAGE_BUCKET = 'fleximart-system.firebasestorage.app';
const PROXY_ALLOWED_PREFIXES = [
  'chat_images/',
  'profile_images/',
  'product_images/',
];

/**
 * Serves Storage files over HTTP with CORS (Flutter Web image loads).
 * GET ?path=chat_images/... or profile_images/...
 */
exports.serveStorageImage = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).send('Method not allowed');
    return;
  }

  const rawPath = req.query.path;
  if (!rawPath || typeof rawPath !== 'string') {
    res.status(400).send('Missing path');
    return;
  }

  let storagePath;
  try {
    storagePath = decodeURIComponent(rawPath).replace(/^\/+/, '');
  } catch (_) {
    res.status(400).send('Invalid path');
    return;
  }

  const allowed = PROXY_ALLOWED_PREFIXES.some((prefix) =>
    storagePath.startsWith(prefix)
  );
  if (!allowed) {
    res.status(403).send('Forbidden');
    return;
  }

  try {
    const bucket = admin.storage().bucket(STORAGE_BUCKET);
    const file = bucket.file(storagePath);
    const [exists] = await file.exists();
    if (!exists) {
      res.status(404).send('Not found');
      return;
    }

    const [metadata] = await file.getMetadata();
    res.set('Content-Type', metadata.contentType || 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=3600');

    file
      .createReadStream()
      .on('error', (err) => {
        console.error('serveStorageImage stream error:', err);
        if (!res.headersSent) {
          res.status(500).send('Error');
        }
      })
      .pipe(res);
  } catch (err) {
    console.error('serveStorageImage error:', err);
    if (!res.headersSent) {
      res.status(500).send('Error');
    }
  }
});
