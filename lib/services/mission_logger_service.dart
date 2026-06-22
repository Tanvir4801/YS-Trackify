import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum MissionSeverity { Info, Success, Warning, Error, Critical }
enum MissionModule { UserLogs, BusinessLogs, SecurityLogs, ProductLogs, SystemLogs }

/// Centralized service to push audit logs to the Trackify Mission Control stream.
class MissionLoggerService {
  MissionLoggerService._();
  static final MissionLoggerService instance = MissionLoggerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Log an action to the `mission_logs` collection.
  Future<void> logAction({
    required MissionSeverity severity,
    required MissionModule module,
    required String action,
    required String companyId,
    required String userId,
    required String role,
    String? details,
  }) async {
    try {
      final payload = {
        'timestamp': FieldValue.serverTimestamp(),
        'severity': severity.name,
        'module': module.name,
        'action': action,
        'companyId': companyId,
        'userId': userId,
        'role': role,
        'details': details ?? '',
      };

      await _db.collection('mission_logs').add(payload);
    } catch (e) {
      debugPrint('Failed to send mission log: $e');
    }
  }
}
