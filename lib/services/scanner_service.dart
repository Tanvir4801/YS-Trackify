import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:vibration/vibration.dart';

import 'firestore_paths.dart';
import 'session_service.dart';

class ScannerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get supervisorId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated supervisor found.');
    }
    return user.uid;
  }

  String get _contractorId {
    final cached = SessionService.instance.contractorId;
    if (cached != null && cached.isNotEmpty) return cached;
    return supervisorId; // fallback (legacy supervisor with no contractorId)
  }

  // ---- Decoders --------------------------------------------------------------

  /// Tries to parse the new v2 JSON QR payload.
  ///
  /// Returns null when the input is not JSON. Returns a map with `error: ...`
  /// when JSON parses but is invalid/expired/cross-contractor.
  Map<String, dynamic>? decodeJsonQr(String raw) {
    try {
      final dynamic parsed = jsonDecode(raw);
      if (parsed is! Map) return null;
      final labourId = (parsed['labourId'] as String?)?.trim() ?? '';
      final contractorId = (parsed['contractorId'] as String?)?.trim() ?? '';
      final labourName = (parsed['labourName'] as String?) ?? 'Labour';
      final expiresAt = (parsed['expiresAt'] as num?)?.toInt() ?? 0;

      if (labourId.isEmpty || contractorId.isEmpty) {
        return {'error': 'invalid'};
      }
      if (expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt) {
        return {'error': 'expired'};
      }
      if (contractorId != _contractorId) {
        return {'error': 'wrong_contractor'};
      }
      return {
        'labourId': labourId,
        'contractorId': contractorId,
        'labourName': labourName,
        'expiresAt': expiresAt,
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, String>? decodeQRToken(String rawToken) {
    try {
      final decoded = utf8.decode(base64Url.decode(rawToken));
      final parts = decoded.split('|');
      if (parts.length != 3) {
        return null;
      }

      final labourId = parts[0];
      final windowSeconds = int.parse(parts[1]);
      final signature = parts[2];

      final nowWindow = DateTime.now().millisecondsSinceEpoch ~/ 30000;
      if ((nowWindow - windowSeconds).abs() > 2) {
        return {'error': 'expired'};
      }

      return {
        'labourId': labourId,
        'windowSeconds': windowSeconds.toString(),
        'signature': signature,
      };
    } catch (_) {
      return {'error': 'invalid'};
    }
  }

  // ---- Duplicate check -------------------------------------------------------

  Future<bool> isAlreadyMarkedToday(String labourId) async {
    final today = _todayString();

    final box = Hive.box('pending_attendance');
    final localKey = '${labourId}_$today';
    if (box.containsKey(localKey)) {
      return true;
    }

    // New nested path is the source of truth when present.
    try {
      final nested = await FirestorePaths
          .attendanceRecordRef(_contractorId, today, labourId)
          .get();
      if (nested.exists) return true;
    } catch (_) {/* fall through */}

    try {
      final snap = await _db
          .collection('attendance')
          .where('labourId', isEqualTo: labourId)
          .where('date', isEqualTo: today)
          .where('supervisorId', isEqualTo: supervisorId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---- Main entry point ------------------------------------------------------

  Future<ScanResult> processScan(String rawToken) async {
    // 1) Try new JSON format first.
    final json = decodeJsonQr(rawToken);
    if (json != null) {
      final err = json['error'] as String?;
      if (err == 'expired') {
        return ScanResult(
          success: false,
          message: 'QR Code Expired. Ask labour to refresh.',
          type: ScanResultType.expired,
        );
      }
      if (err == 'invalid') {
        return ScanResult(
          success: false,
          message: 'Invalid QR Code',
          type: ScanResultType.invalid,
        );
      }
      if (err == 'wrong_contractor') {
        return ScanResult(
          success: false,
          message: 'This labour belongs to a different contractor',
          type: ScanResultType.invalid,
        );
      }

      final labourId = json['labourId'] as String;
      final labourName = json['labourName'] as String;
      final alreadyMarked = await isAlreadyMarkedToday(labourId);
      if (alreadyMarked) {
        return ScanResult(
          success: false,
          message: '$labourName already marked today',
          type: ScanResultType.duplicate,
          labourName: labourName,
        );
      }

      final connectivityResults = await Connectivity().checkConnectivity();
      final isOnline = !connectivityResults.contains(ConnectivityResult.none);

      if (isOnline) {
        return _markViaNewPath(labourId, labourName);
      }
      return _markOffline(labourId, labourName: labourName);
    }

    // 2) Fall back to legacy HMAC token decoding.
    final decoded = decodeQRToken(rawToken);
    if (decoded == null || decoded['error'] == 'invalid') {
      return ScanResult(
        success: false,
        message: 'Invalid QR Code',
        type: ScanResultType.invalid,
      );
    }

    if (decoded['error'] == 'expired') {
      return ScanResult(
        success: false,
        message: 'QR Code Expired. Ask labour to refresh.',
        type: ScanResultType.expired,
      );
    }

    final labourId = decoded['labourId']!;

    final alreadyMarked = await isAlreadyMarkedToday(labourId);
    if (alreadyMarked) {
      final name = await _getLabourName(labourId);
      return ScanResult(
        success: false,
        message: '$name already marked today',
        type: ScanResultType.duplicate,
        labourName: name,
      );
    }

    final connectivityResults = await Connectivity().checkConnectivity();
    final isOnline = !connectivityResults.contains(ConnectivityResult.none);

    if (isOnline) {
      return _markViaCloudFunction(labourId, rawToken);
    }
    return _markOffline(labourId);
  }

  // ---- Write paths -----------------------------------------------------------

  /// Direct Firestore write for the new JSON QR flow.
  ///
  /// Writes to the new nested path AND mirrors a legacy flat doc so existing
  /// supervisor screens (which still query `attendance` flat) keep showing
  /// today's attendance until everything is migrated.
  Future<ScanResult> _markViaNewPath(String labourId, String labourName) async {
    final today = _todayString();
    try {
      final contractorId = _contractorId;
      final supId = supervisorId;
      final supRef = FirestorePaths.userRef(supId);

      final nestedRef =
          FirestorePaths.attendanceRecordRef(contractorId, today, labourId);
      await nestedRef.set({
        'labourId': labourId,
        'labourName': labourName,
        'contractorId': contractorId,
        'supervisorId': supId,
        'supervisorRef': supRef,
        'date': today,
        'status': 'present',
        'overtimeHours': 0,
        'markedVia': 'qr',
        'markedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirestorePaths.attendanceDateDoc(contractorId, today).set({
        'date': today,
        'contractorId': contractorId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mirror to legacy flat collection for compatibility.
      try {
        final existing = await _db
            .collection('attendance')
            .where('labourId', isEqualTo: labourId)
            .where('date', isEqualTo: today)
            .where('supervisorId', isEqualTo: supId)
            .limit(1)
            .get();
        if (existing.docs.isEmpty) {
          await _db.collection('attendance').add({
            'labourId': labourId,
            'supervisorId': supId,
            'supervisorRef': supRef,
            'contractorId': contractorId,
            'date': today,
            'status': 'present',
            'overtimeHours': 0,
            'markedVia': 'qr',
            'isSynced': true,
            'syncedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        // Legacy mirror is best-effort; new path already succeeded.
      }

      _saveToHive(labourId, 'present', isSynced: true);
      return ScanResult(
        success: true,
        message: '$labourName marked Present ✓',
        type: ScanResultType.success,
        labourName: labourName,
      );
    } catch (_) {
      return _markOffline(labourId, labourName: labourName);
    }
  }

  Future<ScanResult> _markViaCloudFunction(String labourId, String rawToken) async {
    try {
      final callable = _functions.httpsCallable('validateAndMarkAttendance');
      final result = await callable.call(<String, dynamic>{
        'token': rawToken,
        'supervisorId': supervisorId,
        'contractorId': _contractorId,
        'date': _todayString(),
        'status': 'present',
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['success'] == true) {
        final name = (data['labourName'] as String?) ?? 'Labour';
        _saveToHive(labourId, 'present', isSynced: true);
        return ScanResult(
          success: true,
          message: '$name marked Present ✓',
          type: ScanResultType.success,
          labourName: name,
        );
      }

      return ScanResult(
        success: false,
        message: (data['message'] as String?) ?? 'Validation failed',
        type: ScanResultType.invalid,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        return ScanResult(
          success: false,
          message: 'Already marked today',
          type: ScanResultType.duplicate,
        );
      }
      return _markOffline(labourId);
    } catch (_) {
      return _markOffline(labourId);
    }
  }

  Future<ScanResult> _markOffline(String labourId, {String? labourName}) async {
    final name = labourName ?? await _getLabourName(labourId);
    _saveToHive(labourId, 'present', isSynced: false);

    return ScanResult(
      success: true,
      message: '$name marked offline. Will sync when online.',
      type: ScanResultType.offline,
      labourName: name,
    );
  }

  void _saveToHive(String labourId, String status, {required bool isSynced}) {
    final box = Hive.box('pending_attendance');
    final today = _todayString();
    box.put('${labourId}_$today', {
      'labourId': labourId,
      'supervisorId': supervisorId,
      'contractorId': _contractorId,
      'date': today,
      'status': status,
      'isSynced': isSynced,
      'scannedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<int> syncPendingScans() async {
    final box = Hive.box('pending_attendance');
    var synced = 0;

    for (final key in box.keys) {
      final record = Map<String, dynamic>.from(box.get(key) as Map);
      if (record['isSynced'] == true) {
        continue;
      }

      try {
        final labourId = (record['labourId'] as String?) ?? '';
        final date = (record['date'] as String?) ?? _todayString();
        final contractorId =
            (record['contractorId'] as String?)?.trim().isNotEmpty == true
                ? record['contractorId'] as String
                : _contractorId;

        // Prefer direct nested write for offline-queued scans.
        try {
          await FirestorePaths
              .attendanceRecordRef(contractorId, date, labourId)
              .set({
            'labourId': labourId,
            'contractorId': contractorId,
            'supervisorId': record['supervisorId'] ?? supervisorId,
            'supervisorRef':
                FirestorePaths.userRef(record['supervisorId'] as String? ?? supervisorId),
            'date': date,
            'status': record['status'] ?? 'present',
            'overtimeHours': 0,
            'markedVia': 'qr',
            'markedAt': FieldValue.serverTimestamp(),
            'offlineSync': true,
          }, SetOptions(merge: true));
        } catch (_) {
          // Fall back to the legacy callable.
          final callable = _functions.httpsCallable('validateAndMarkAttendance');
          await callable.call(<String, dynamic>{
            ...record,
            'offlineSync': true,
          });
        }

        record['isSynced'] = true;
        await box.put(key, record);
        synced += 1;
      } catch (_) {
        continue;
      }
    }

    return synced;
  }

  int getPendingCount() {
    final box = Hive.box('pending_attendance');
    return box.values
        .where((value) => Map<String, dynamic>.from(value as Map)['isSynced'] == false)
        .length;
  }

  Future<String> _getLabourName(String labourId) async {
    try {
      final snap = await _db
          .collection('labours')
          .where('id', isEqualTo: labourId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return (snap.docs.first.data()['name'] as String?) ?? 'Labour';
      }
    } catch (_) {
      return 'Labour';
    }

    return 'Labour';
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> playSuccessFeedback() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      Vibration.vibrate(duration: 200, amplitude: 128);
    }
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> playErrorFeedback() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      Vibration.vibrate(pattern: [0, 100, 100, 100]);
    }
  }
}

enum ScanResultType { success, duplicate, expired, invalid, offline }

class ScanResult {
  ScanResult({
    required this.success,
    required this.message,
    required this.type,
    this.labourName,
  });

  final bool success;
  final String message;
  final ScanResultType type;
  final String? labourName;
}
