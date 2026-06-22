import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> recordSession(String uid, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('current_session_id') ?? _db.collection('sessions').doc().id;
      
      String deviceName = 'Unknown';
      String osVersion = 'Unknown';
      
      if (!kIsWeb) {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceName = '${androidInfo.brand} ${androidInfo.model}';
          osVersion = 'Android ${androidInfo.version.release}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceName = iosInfo.name ?? iosInfo.model ?? 'iPhone';
          osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        }
      } else {
        deviceName = 'Web Browser';
        osVersion = 'Web';
      }

      String appVersion = 'Unknown';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (_) {}

      final sessionData = {
        'sessionId': sessionId,
        'userId': uid,
        'role': role,
        'deviceId': deviceName,
        'deviceName': deviceName,
        'osVersion': osVersion,
        'appVersion': appVersion,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'lastSeen': FieldValue.serverTimestamp(),
        'isActive': true,
        'terminated': false,
      };

      if (!prefs.containsKey('current_session_id')) {
        sessionData['loginAt'] = FieldValue.serverTimestamp();
      }

      await _db.collection('sessions').doc(sessionId).set(sessionData, SetOptions(merge: true));
      await prefs.setString('current_session_id', sessionId);
    } catch (e) {
      debugPrint('Failed to record session: $e');
    }
  }

  Future<void> pingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('current_session_id');
      if (sessionId != null) {
        await _db.collection('sessions').doc(sessionId).update({
          'lastSeen': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }
    } catch (_) {}
  }

  Future<void> endSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('current_session_id');
      if (sessionId != null) {
        await _db.collection('sessions').doc(sessionId).update({
          'terminated': true,
          'isActive': false,
          'terminatedAt': FieldValue.serverTimestamp(),
        });
        await prefs.remove('current_session_id');
      }
    } catch (_) {}
  }
}
