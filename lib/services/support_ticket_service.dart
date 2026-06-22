import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/session_service.dart';

class SupportTicketService {
  SupportTicketService._();
  static final SupportTicketService instance = SupportTicketService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createTicket({
    required String type,
    required String issue,
    String? currentScreen,
    String priority = 'Medium',
  }) async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      final sessionUser = SessionService.instance.current;

      if (fbUser == null && sessionUser == null) {
        throw Exception('User not logged in');
      }

      String userId;
      String userName;
      String userRole;
      String companyId;
      String companyName = 'Unknown Company';

      if (fbUser != null) {
        userId = fbUser.uid;
        // Fetch user data for context
        final userDoc = await _db.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        
        userName = userData['name'] ?? fbUser.displayName ?? 'Unknown User';
        userRole = userData['role'] ?? 'Unknown Role';
        companyId = userData['contractorId'] ?? SessionService.instance.contractorId ?? userId;
      } else {
        userId = sessionUser!.uid;
        userName = sessionUser.name ?? 'Unknown User';
        userRole = sessionUser.role ?? 'Unknown Role';
        companyId = sessionUser.contractorId ?? userId;
      }
      
      try {
        final contractorDoc = await _db.collection('contractors').doc(companyId).get();
        if (contractorDoc.exists) {
          companyName = contractorDoc.data()?['name'] ?? 'Unknown Company';
        } else {
          // fallback search
          final snap = await _db.collection('contractors').where('id', isEqualTo: companyId).limit(1).get();
          if (snap.docs.isNotEmpty) {
            companyName = snap.docs.first.data()['name'] ?? 'Unknown Company';
          }
        }
      } catch(e) {
        debugPrint('Failed to fetch company name: $e');
      }

      final deviceInfo = await _getDeviceInfo(currentScreen);

      final ticketPayload = {
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'companyId': companyId,
        'companyName': companyName,
        'type': type,
        'issue': issue,
        'status': 'Open',
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deviceInfo': deviceInfo,
        'history': [
          {
            'type': 'status_change',
            'old': 'None',
            'newStatus': 'Open',
            'createdBy': userName,
            'timestamp': DateTime.now().toIso8601String()
          }
        ]
      };

      await _db.collection('support_tickets').add(ticketPayload);
      
      // Also log to mission_logs for TrackOps feed
      await _db.collection('mission_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'Warning',
        'module': 'SystemLogs',
        'action': 'Support Ticket Created',
        'companyId': companyId,
        'userId': userId,
        'role': userRole,
        'details': type,
      });
      
    } catch (e) {
      debugPrint('Failed to create support ticket: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _getDeviceInfo(String? currentScreen) async {
    final Map<String, String> data = {};
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      data['appVersion'] = packageInfo.version;
      data['buildNumber'] = packageInfo.buildNumber;
      data['screen'] = currentScreen ?? 'Unknown';

      if (kIsWeb) {
        data['platform'] = 'Web';
      } else {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          data['platform'] = 'Android';
          data['osVersion'] = androidInfo.version.release;
          data['device'] = '${androidInfo.brand} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          data['platform'] = 'iOS';
          data['osVersion'] = iosInfo.systemVersion;
          data['device'] = iosInfo.utsname.machine;
        } else {
          data['platform'] = Platform.operatingSystem;
        }
      }
    } catch (e) {
      data['platform'] = 'Unknown';
    }
    return data;
  }
}
