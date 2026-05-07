import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:vibration/vibration.dart';

import '../models/labour_model.dart';
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
    return supervisorId;
  }

  // ---- Decoders --------------------------------------------------------------

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

    try {
      final nested = await FirestorePaths
          .attendanceRecordRef(_contractorId, today, labourId)
          .get();
      if (nested.exists) return true;
    } catch (_) {}

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

    // Fall back to legacy HMAC token decoding.
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

      // Mirror to flat collection for dashboard/attendance screens.
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
        // Mirror is best-effort; nested path already succeeded.
      }

      _saveToHive(labourId, 'present', labourName: labourName, isSynced: true);
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
        _saveToHive(labourId, 'present', labourName: name, isSynced: true);
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
    _saveToHive(labourId, 'present', labourName: name, isSynced: false);

    return ScanResult(
      success: true,
      message: '$name marked offline. Will sync when online.',
      type: ScanResultType.offline,
      labourName: name,
    );
  }

  void _saveToHive(String labourId, String status,
      {String? labourName, required bool isSynced}) {
    final box = Hive.box('pending_attendance');
    final today = _todayString();
    box.put('${labourId}_$today', {
      'labourId': labourId,
      'labourName': labourName ?? '',
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
    final uid = _auth.currentUser?.uid ?? '';
    final contractorId = _contractorId;

    if (uid.isEmpty) {
      debugPrint('syncPendingScans: not logged in');
      return 0;
    }

    var synced = 0;

    for (final key in box.keys.toList()) {
      final rawRecord = box.get(key);
      if (rawRecord == null) continue;

      final record = Map<String, dynamic>.from(rawRecord as Map);
      if (record['isSynced'] == true) continue;

      final labourId = (record['labourId'] as String?) ?? '';
      final date = (record['date'] as String?) ?? _todayString();
      final status = (record['status'] as String?) ?? 'present';
      final recContractorId =
          ((record['contractorId'] as String?)?.isNotEmpty == true)
              ? record['contractorId'] as String
              : contractorId;
      final recSupervisorId =
          ((record['supervisorId'] as String?)?.isNotEmpty == true)
              ? record['supervisorId'] as String
              : uid;

      if (labourId.isEmpty) {
        // Invalid record — remove from queue
        record['isSynced'] = true;
        await box.put(key, record);
        continue;
      }

      try {
        // Check if already exists in flat collection
        final existing = await _db
            .collection('attendance')
            .where('labourId', isEqualTo: labourId)
            .where('date', isEqualTo: date)
            .where('supervisorId', isEqualTo: recSupervisorId)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          record['isSynced'] = true;
          await box.put(key, record);
          synced++;
          continue;
        }

        // Write to nested path
        try {
          await FirestorePaths
              .attendanceRecordRef(recContractorId, date, labourId)
              .set({
            'labourId': labourId,
            'contractorId': recContractorId,
            'supervisorId': recSupervisorId,
            'supervisorRef': FirestorePaths.userRef(recSupervisorId),
            'date': date,
            'status': status,
            'overtimeHours': record['overtimeHours'] ?? 0,
            'markedVia': 'offline_qr',
            'markedAt': FieldValue.serverTimestamp(),
            'offlineSync': true,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Nested path sync failed: $e — trying flat collection');
        }

        // Write to flat collection
        final docRef = await _db.collection('attendance').add({
          'labourId': labourId,
          'supervisorId': recSupervisorId,
          'contractorId': recContractorId,
          'date': date,
          'status': status,
          'overtimeHours': record['overtimeHours'] ?? 0,
          'markedVia': 'offline_qr',
          'isSynced': true,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        await docRef.update({'id': docRef.id});

        record['isSynced'] = true;
        record['firestoreId'] = docRef.id;
        await box.put(key, record);
        synced++;

        debugPrint('Synced scan: $labourId → $status on $date');
      } catch (e) {
        debugPrint('Sync failed for $labourId: $e');
        // Don't mark synced — will retry next time
      }
    }

    debugPrint('syncPendingScans complete: $synced synced');
    return synced;
  }

  int getPendingCount() {
    try {
      final box = Hive.box('pending_attendance');
      return box.values
          .where((v) {
            final m = Map<String, dynamic>.from(v as Map);
            return m['isSynced'] != true;
          })
          .length;
    } catch (_) {
      return 0;
    }
  }

  /// Look up labour name — checks Hive box first (fast), then Firestore.
  Future<String> _getLabourName(String labourId) async {
    if (labourId.isEmpty) return 'Labour';

    // Check Hive Labour box first
    try {
      final labourBox = Hive.box<Labour>(Labour.boxName);
      final labour = labourBox.get(labourId) ??
          labourBox.values
              .cast<Labour?>()
              .firstWhere((l) => l?.firestoreId == labourId, orElse: () => null);
      if (labour != null && labour.name.isNotEmpty) return labour.name;
    } catch (_) {}

    // Firestore: try doc by ID directly
    try {
      final doc = await _db.collection('labours').doc(labourId).get();
      if (doc.exists) {
        return (doc.data()?['name'] as String?) ?? 'Labour';
      }
    } catch (_) {}

    // Firestore: try querying by id field (legacy)
    try {
      final snap = await _db
          .collection('labours')
          .where('id', isEqualTo: labourId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return (snap.docs.first.data()['name'] as String?) ?? 'Labour';
      }
    } catch (_) {}

    return 'Labour';
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> playSuccessFeedback() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(duration: 200, amplitude: 128);
      }
    } catch (_) {}
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> playErrorFeedback() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 100, 100, 100]);
      }
    } catch (_) {}
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
