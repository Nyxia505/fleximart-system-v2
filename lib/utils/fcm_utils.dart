import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> saveFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final messaging = FirebaseMessaging.instance;
    
    // Request permission (web uses browser notification API)
    if (kIsWeb) {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } else {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }

    final token = await messaging.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      // Single token field for Cloud Functions / server use
      'fcmToken': token,
      // Map for tracking multiple devices (backward compatible)
      'fcmTokens': {token: true},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    // Silently handle errors (e.g., service worker not available, permissions denied)
    // Error is already logged by Firebase, no need to print again
  }
}

void initFcmTokenRefresh() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': newToken,
        'fcmTokens': {newToken: true},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently handle errors
      // Error is already logged by Firebase, no need to print again
    }
  });
}


