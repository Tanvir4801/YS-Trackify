import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:vibration/vibration.dart';

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

  Future<bool> isAlreadyMarkedToday(String labourId) async {
    final today = _todayString();

    final box = Hive.box('pending_attendance');
    final localKey = '${labourId}_$today';
    if (box.containsKey(localKey)) {
      return true;
    }

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

  Future<ScanResult> processScan(String rawToken) async {
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

  Future<ScanResult> _markViaCloudFunction(String labourId, String rawToken) async {
    try {
      final callable = _functions.httpsCallable('validateAndMarkAttendance');
      final result = await callable.call(<String, dynamic>{
        'token': rawToken,
        'supervisorId': supervisorId,
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

  Future<ScanResult> _markOffline(String labourId) async {
    final name = await _getLabourName(labourId);
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
        final callable = _functions.httpsCallable('validateAndMarkAttendance');
        await callable.call(<String, dynamic>{
          ...record,
          'offlineSync': true,
        });

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
