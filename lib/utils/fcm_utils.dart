import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> saveFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  final token = await messaging.getToken();
  if (token == null) return;

  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    // Single token field for Cloud Functions / server use
    'fcmToken': token,
    // Map for tracking multiple devices (backward compatible)
    'fcmTokens': {token: true},
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

void initFcmTokenRefresh() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': newToken,
      'fcmTokens': {newToken: true},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}


