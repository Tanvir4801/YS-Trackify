import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:vibration/vibration.dart';

import '../models/labour_model.dart';
import 'closing_report_service.dart';
import 'firestore_paths.dart';
import 'qr_validator.dart';
import 'session_service.dart';

class ScannerService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  String get supervisorId => _auth.currentUser?.uid ?? '';

  String get _contractorId {
    final cached = SessionService.instance.contractorId;
    if (cached != null && cached.isNotEmpty) return cached;
    return supervisorId;
  }

  // ── JSON QR decoder (admin format + v2 QR format) ──────────────────────────

  Map<String, dynamic>? decodeJsonQr(String raw) {
    try {
      final dynamic parsed = jsonDecode(raw);
      if (parsed is! Map) return null;

      final labourId = (parsed['labourId'] as String?)?.trim() ?? '';
      if (labourId.isEmpty) return {'error': 'invalid'};

      // Admin format: {"type":"labour_qr","labourId":"...","name":"...","appId":"..."}
      final type = (parsed['type'] as String?)?.trim() ?? '';
      if (type == 'labour_qr') {
        final labourName = (parsed['name'] as String?) ?? 'Labour';
        return {'labourId': labourId, 'labourName': labourName};
      }

      // V2 format: {"labourId":"...","contractorId":"...","labourName":"...","expiresAt":...}
      final contractorId = (parsed['contractorId'] as String?)?.trim() ?? '';
      final labourName   = (parsed['labourName']   as String?) ?? 'Labour';
      final expiresAt    = (parsed['expiresAt']    as num?)?.toInt() ?? 0;

      if (contractorId.isEmpty) return {'error': 'invalid'};
      if (expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt) {
        return {'error': 'expired'};
      }
      if (contractorId != _contractorId) {
        return {'error': 'wrong_contractor'};
      }
      return {
        'labourId':     labourId,
        'contractorId': contractorId,
        'labourName':   labourName,
        'expiresAt':    expiresAt,
      };
    } catch (_) {
      return null;
    }
  }

  // ── Duplicate check ─────────────────────────────────────────────────────────

  Future<bool> isAlreadyMarkedToday(String labourId, {String siteId = ''}) async {
    final today    = _todayString();
    final localKey = '${labourId}_$today';

    try {
      final box = Hive.box('pending_attendance');
      if (box.containsKey(localKey)) {
        // A pending-status record means "not yet marked" — allow re-scan.
        final record = box.get(localKey);
        if (record is Map && (record['status'] as String?) == 'pending') {
          // fall through — pending is not considered "already marked"
        } else {
          return true;
        }
      }
    } catch (_) {}

    try {
      final nested = await FirestorePaths
          .attendanceRecordRef(_contractorId, today, labourId, siteId: siteId)
          .get();
      if (nested.exists) {
        // If the record has status 'pending', treat it as not marked.
        final nestedStatus = (nested.data()?['status'] as String?) ?? '';
        if (nestedStatus == 'pending') return false;
        return true;
      }
    } catch (_) {}

    try {
      final snap = await _db
          .collection('attendance')
          .where('labourId',     isEqualTo: labourId)
          .where('date',         isEqualTo: today)
          .where('supervisorId', isEqualTo: supervisorId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final status = (snap.docs.first.data()['status'] as String?) ?? '';
        // pending records are not considered "already marked"
        return status != 'pending';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Pre-validation (decode + duplicate check, no write) ────────────────────

  Future<QRPrecheck> precheckQR(String rawToken) async {
    // Try JSON QR first (v2 format)
    final json = decodeJsonQr(rawToken);
    if (json != null) {
      final err = json['error'] as String?;
      if (err == 'expired') {
        return QRPrecheck.invalid(
            'QR Code Expired. Ask labour to refresh.', ScanResultType.expired);
      }
      if (err == 'wrong_contractor') {
        return QRPrecheck.invalid(
            'This labour belongs to a different contractor', ScanResultType.invalid);
      }
      if (err != null) {
        return QRPrecheck.invalid('Invalid QR Code', ScanResultType.invalid);
      }
      final labourId   = json['labourId']   as String;
      final labourName = json['labourName'] as String? ?? 'Labour';
      return QRPrecheck.valid(labourId: labourId, labourName: labourName);
    }

    // Fall back to legacy HMAC token
    final validation = QRValidator.validate(rawToken);
    if (validation.isExpired) {
      return QRPrecheck.invalid(
          'QR Code Expired. Ask labour to refresh.', ScanResultType.expired);
    }
    if (!validation.isValid) {
      return QRPrecheck.invalid('Invalid QR Code', ScanResultType.invalid);
    }
    final labourId = validation.labourId!;
    final name = await _getLabourName(labourId);
    return QRPrecheck.valid(labourId: labourId, labourName: name);
  }

  // ── Main scan entry point (used by scanner_screen) ─────────────────────────

  Future<ScanResult> processScan(String rawToken) async {
    return processScanWithType(rawToken: rawToken, status: 'present', siteId: '',sessionId: '',);
  }

  // ── Scan with explicit attendance type ──────────────────────────────────────

  Future<ScanResult> processScanWithType({
    required String rawToken,
    required String status,
    required String siteId,
    required String sessionId,
    
  }) async {
    if (supervisorId.isEmpty) {
      return const ScanResult(
          success: false, message: 'Not logged in', type: ScanResultType.invalid);
    }

    // Try JSON QR first
    final json = decodeJsonQr(rawToken);
    if (json != null) {
      final err = json['error'] as String?;
      if (err == 'expired') {
        return const ScanResult(
            success: false, message: 'QR Code Expired.', type: ScanResultType.expired);
      }
      if (err != null) {
        return const ScanResult(
            success: false, message: 'Invalid QR Code', type: ScanResultType.invalid);
      }
      final labourId   = json['labourId']   as String;
      final labourName = json['labourName'] as String? ?? 'Labour';
      
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline     = !connectivity.contains(ConnectivityResult.none);
      if (isOnline) {
        return _markOnline(labourId, labourName, status, siteId: siteId);
      }
      return _markOffline(labourId, status: status, labourName: labourName, siteId: siteId);
    }

    // Fall back to legacy HMAC token
    final validation = QRValidator.validate(rawToken);
    if (validation.isExpired) {
      return const ScanResult(
          success: false,
          message: 'QR Code Expired. Ask labour to refresh.',
          type: ScanResultType.expired);
    }
    if (!validation.isValid) {
      return ScanResult(
          success: false,
          message: validation.errorMessage ?? 'Invalid QR Code',
          type: ScanResultType.invalid);
    }

    final labourId = validation.labourId!;
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline     = !connectivity.contains(ConnectivityResult.none);
    if (isOnline) {
      final name = await _getLabourName(labourId);
      return _markOnline(labourId, name, status, siteId: siteId);
    }
    return _markOffline(labourId, status: status, siteId: siteId);
  }

  // ── Status label helper — exhaustive mapping of all 5 attendance statuses ────

  String _statusLabel(String status) {
    return switch (status) {
      'present'       => 'Present',
      'three_quarter' => '3/4 Day',
      'half'          => 'Half Day',
      'quarter'       => '1/4 Day',
      'absent'        => 'Absent',
      _               => status,
    };
  }

  // ── shiftFactor helper (mirrors AttendanceStatusX.wageFactor) ────────────────

  double _statusToShiftFactor(String status) {
    return switch (status) {
      'present'       => 1.0,
      'three_quarter' => 0.75,
      'half'          => 0.5,
      'quarter'       => 0.25,
      _               => 0.0, // absent, pending, unknown
    };
  }

  // ── Online write: direct Firestore (no Cloud Function) ─────────────────────

  Future<ScanResult> _markOnline(
      String labourId, String labourName, String status, {String siteId = ''}) async {
    final today        = _todayString();
    final contractorId = _contractorId;
    final supId        = supervisorId;
    final supRef       = FirestorePaths.userRef(supId);
    final wageAtTime   = await _getLabourWage(labourId);
    final shiftFactor  = _statusToShiftFactor(status);

    // QR-001: Enforce day locking — reject scan if the day has been closed.
    try {
      final isClosed = await ClosingReportService().isDayClosed(contractorId, today);
      if (isClosed) {
        return ScanResult(
          success:    false,
          message:    'Day is closed. Attendance cannot be modified.',
          type:       ScanResultType.invalid,
          labourName: labourName,
        );
      }
    } catch (e) {
      // If we cannot determine closed status (e.g. network glitch), log and
      // fall through so legitimate online scans are not blocked unexpectedly.
      debugPrint('isDayClosed check failed in _markOnline: $e — proceeding');
    }

    try {
      // Write to nested path (new multi-tenant model)
      final nestedRef =
          FirestorePaths.attendanceRecordRef(contractorId, today, labourId, siteId: siteId);
      await nestedRef.set({
        'labourId':      labourId,
        'labourName':    labourName,
        'contractorId':  contractorId,
        'supervisorId':  supId,
        'supervisorRef': supRef,
        'date':          today,
        'status':        status,
        'shiftFactor':   shiftFactor,
        'siteId':        siteId,
        'overtimeHours': 0,
        'wageAtTime':    wageAtTime,
        'markedVia':     'qr',
        'markedAt':      FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirestorePaths.attendanceDateDoc(contractorId, today).set({
        'date':         today,
        'contractorId': contractorId,
        'updatedAt':    FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mirror to flat collection for existing dashboard/attendance screens
      try {
        final existing = await _db
            .collection('attendance')
            .where('labourId',     isEqualTo: labourId)
            .where('date',         isEqualTo: today)
            .where('siteId',       isEqualTo: siteId)
            .where('supervisorId', isEqualTo: supId)
            .limit(1)
            .get();
        if (existing.docs.isEmpty) {
          await _db.collection('attendance').doc('${labourId}_${today}_$siteId').set({
            'id':            '${labourId}_${today}_$siteId',
            'labourId':      labourId,
            'labourName':    labourName,
            'supervisorId':  supId,
            'supervisorRef': supRef,
            'contractorId':  contractorId,
            'date':          today,
            'status':        status,
            'shiftFactor':   shiftFactor,
            'siteId':        siteId,
            'overtimeHours': 0,
            'wageAtTime':    wageAtTime,
            'markedVia':     'qr',
            'isSynced':      true,
            'syncedAt':      FieldValue.serverTimestamp(),
          });
        }
      } catch (flatErr) {
        // Log prominently — admin panel reads the flat collection.
        debugPrint('⚠️ QR flat-collection mirror failed for $labourId on $today: $flatErr');
      }

      _saveToHive(labourId, status, labourName: labourName, isSynced: true, siteId: siteId);
      // ATT-001: Use exhaustive label mapping instead of a ternary chain.
      final label = _statusLabel(status);
      return ScanResult(
          success:    true,
          message:    '$labourName marked $label ✓',
          type:       ScanResultType.success,
          labourName: labourName);
    } catch (e) {
      debugPrint('_markOnline error: $e — falling back to offline');
      return _markOffline(labourId, status: status, labourName: labourName);
    }
  }

  // ── Offline write: Hive queue ───────────────────────────────────────────────

  Future<ScanResult> _markOffline(String labourId,
      {String? labourName, String status = 'present', String siteId = ''}) async {
    final name = labourName ?? await _getLabourName(labourId);
    final wageAtTime = await _getLabourWage(labourId);
    // QR-001 (offline path): We cannot call isDayClosed reliably while offline
    // so we store the scan for later sync. syncPendingScans() will check
    // isDayClosed using the ORIGINAL scan date before writing to Firestore.
    _saveToHive(labourId, status, labourName: name, isSynced: false, wageAtTime: wageAtTime, siteId: siteId);
    // ATT-001: Use exhaustive label mapping.
    final label = _statusLabel(status);
    return ScanResult(
        success:    true,
        message:    '$name marked $label (offline). Will sync later.',
        type:       ScanResultType.offline,
        labourName: name);
  }

  // ── Sync pending offline scans ──────────────────────────────────────────────

  Future<int> syncPendingScans() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return 0;

    Box box;
    try {
      box = Hive.box('pending_attendance');
    } catch (_) {
      box = await Hive.openBox('pending_attendance');
    }

    final contractorId = _contractorId;
    var synced = 0;

    for (final key in box.keys.toList()) {
      final rawRecord = box.get(key);
      if (rawRecord == null) continue;
      final record = Map<String, dynamic>.from(rawRecord as Map);
      if (record['isSynced'] == true) continue;

      final labourId       = (record['labourId']     as String?) ?? '';
      final date           = (record['date']         as String?) ?? _todayString();
      final status         = (record['status']       as String?) ?? 'present';
      final recContractorId =
          ((record['contractorId'] as String?)?.isNotEmpty == true)
              ? record['contractorId'] as String
              : contractorId;
      final recSupervisorId =
          ((record['supervisorId'] as String?)?.isNotEmpty == true)
              ? record['supervisorId'] as String
              : uid;

      if (labourId.isEmpty) {
        record['isSynced'] = true;
        await box.put(key, record);
        continue;
      }

      try {
        // OFFLINE-001 + QR-001: Check isDayClosed using the ORIGINAL scan date
        // (not today's date) before syncing to prevent writing to closed days.
        bool dayIsClosed = false;
        try {
          dayIsClosed = await ClosingReportService().isDayClosed(recContractorId, date);
        } catch (e) {
          debugPrint('isDayClosed check failed during sync for $date: $e — proceeding with write');
        }

        if (dayIsClosed) {
          // Day is closed — mark as synced (to remove from queue) but do not write.
          record['isSynced']     = true;
          record['skippedReason'] = 'day_closed';
          await box.put(key, record);
          debugPrint('⚠️ Skipped offline sync for $labourId on $date — day is closed');
          continue;
        }

        final siteId      = (record['siteId'] as String?) ?? '';
        // QR-002: compute shiftFactor from status so Firestore records are complete.
        final shiftFactor = _statusToShiftFactor(status);
        final wageAtTime  = (record['wageAtTime'] as num?)?.toDouble() ?? 0;

        // Write to nested path
        try {
          await FirestorePaths
              .attendanceRecordRef(recContractorId, date, labourId, siteId: siteId)
              .set({
            'labourId':      labourId,
            'contractorId':  recContractorId,
            'supervisorId':  recSupervisorId,
            'supervisorRef': FirestorePaths.userRef(recSupervisorId),
            'date':          date,
            'status':        status,
            'shiftFactor':   shiftFactor,
            'siteId':        siteId,
            'overtimeHours': record['overtimeHours'] ?? 0,
            'wageAtTime':    wageAtTime,
            'markedVia':     'offline_qr',
            'markedAt':      FieldValue.serverTimestamp(),
            'offlineSync':   true,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Nested path sync failed: $e — trying flat collection');
        }

        // Write to flat collection — include shiftFactor (QR-002).
        final docRef = await _db.collection('attendance').add({
          'labourId':      labourId,
          'supervisorId':  recSupervisorId,
          'contractorId':  recContractorId,
          'date':          date,
          'status':        status,
          'shiftFactor':   shiftFactor,
          'siteId':        siteId,
          'overtimeHours': record['overtimeHours'] ?? 0,
          'wageAtTime':    wageAtTime,
          'markedVia':     'offline_qr',
          'isSynced':      true,
          'syncedAt':      FieldValue.serverTimestamp(),
        });
        await docRef.update({'id': docRef.id});

        record['isSynced']    = true;
        record['firestoreId'] = docRef.id;
        await box.put(key, record);
        synced++;

        debugPrint('Synced scan: $labourId → $status on $date');
      } catch (e) {
        debugPrint('Sync error for key $key: $e');
      }
    }

    debugPrint('syncPendingScans complete: $synced synced');
    return synced;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  int getPendingCount() {
    try {
      final box = Hive.box('pending_attendance');
      return box.values.where((v) {
        try { return (v as Map)['isSynced'] != true; }
        catch (_) { return false; }
      }).length;
    } catch (_) {
      return 0;
    }
  }

  void _saveToHive(String labourId, String status,
      {String? labourName, required bool isSynced, double wageAtTime = 0, String siteId = ''}) {
    try {
      final box   = Hive.box('pending_attendance');
      final today = _todayString();
      box.put('${labourId}_${today}_$siteId', {
        'labourId':     labourId,
        'labourName':   labourName ?? '',
        'supervisorId': supervisorId,
        'contractorId': _contractorId,
        'siteId':       siteId,
        'date':         today,
        'status':       status,
        'wageAtTime':   wageAtTime,
        'isSynced':     isSynced,
        'scannedAt':    DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('_saveToHive error: $e');
    }
  }

  Future<String> _getLabourName(String labourId) async {
    try {
      final box    = Hive.box<Labour>(Labour.boxName);
      final labour = box.get(labourId) ??
          box.values.cast<Labour?>().firstWhere(
              (l) => l?.firestoreId == labourId,
              orElse: () => null);
      if (labour != null && labour.name.isNotEmpty) return labour.name;
    } catch (_) {}
    try {
      final doc = await _db.collection('labours').doc(labourId).get();
      if (doc.exists) return doc.data()?['name'] as String? ?? labourId;
    } catch (_) {}
    return labourId;
  }

  // Historical wage snapshot: same rationale as manual markAttendance —
  // record the labour's current daily wage at scan-time so future wage
  // changes never retroactively distort past salary/report calculations.
  Future<double> _getLabourWage(String labourId) async {
    try {
      final box    = Hive.box<Labour>(Labour.boxName);
      final labour = box.get(labourId) ??
          box.values.cast<Labour?>().firstWhere(
              (l) => l?.firestoreId == labourId,
              orElse: () => null);
      if (labour != null && labour.dailyWage > 0) return labour.dailyWage;
    } catch (_) {}
    try {
      final doc = await _db.collection('labours').doc(labourId).get();
      if (doc.exists) {
        return (doc.data()?['dailyWage'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  String _todayString() {
    final n = DateTime.now();
    return '${n.year}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> playSuccessFeedback() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 200, amplitude: 128);
      }
    } catch (_) {}
    try { await SystemSound.play(SystemSoundType.click); } catch (_) {}
  }

  Future<void> playErrorFeedback() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 100, 100, 100]);
      }
    } catch (_) {}
  }
}

// ── Result models ────────────────────────────────────────────────────────────

enum ScanResultType { success, duplicate, expired, invalid, offline }

class ScanResult {
  const ScanResult({
    required this.success,
    required this.message,
    required this.type,
    this.labourName,
    this.rawToken,
  });

  final bool           success;
  final String         message;
  final ScanResultType type;
  final String?        labourName;
  final String?        rawToken;
}

// ── Precheck result model ────────────────────────────────────────────────────

enum QRPrecheckStatus { valid, duplicate, invalid }

class QRPrecheck {
  const QRPrecheck._({
    required this.status,
    required this.errorMessage,
    required this.errorType,
    required this.labourId,
    required this.labourName,
  });

  final QRPrecheckStatus status;
  final String           errorMessage;
  final ScanResultType   errorType;
  final String           labourId;
  final String           labourName;

  bool get isValid     => status == QRPrecheckStatus.valid;
  bool get isDuplicate => status == QRPrecheckStatus.duplicate;

  factory QRPrecheck.valid({
    required String labourId,
    required String labourName,
  }) => QRPrecheck._(
    status:       QRPrecheckStatus.valid,
    errorMessage: '',
    errorType:    ScanResultType.success,
    labourId:     labourId,
    labourName:   labourName,
  );

  factory QRPrecheck.duplicate({
    required String labourId,
    required String labourName,
  }) => QRPrecheck._(
    status:       QRPrecheckStatus.duplicate,
    errorMessage: '$labourName already marked today',
    errorType:    ScanResultType.duplicate,
    labourId:     labourId,
    labourName:   labourName,
  );

  factory QRPrecheck.invalid(String message, ScanResultType type) =>
      QRPrecheck._(
        status:       QRPrecheckStatus.invalid,
        errorMessage: message,
        errorType:    type,
        labourId:     '',
        labourName:   '',
      );
}
