import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> init(String labourId) async {
    try {
      // 1. Request permission for iOS/Android 13+
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else {
        debugPrint('User declined or has not accepted notification permissions');
        return;
      }

      // 2. Get FCM Token
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _saveTokenToFirestore(labourId, token);
      }

      // 3. Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(labourId, newToken);
      });

      // 4. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground message: ${message.notification?.title}');
        // You can use flutter_local_notifications here to show a banner in the app
      });

    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String labourId, String token) async {
    try {
      await _db.collection('labours').doc(labourId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  Future<void> clearToken(String labourId) async {
    try {
      await _db.collection('labours').doc(labourId).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }
}
