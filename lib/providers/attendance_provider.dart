import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/attendance_model.dart';
import '../models/daily_labour_summary.dart';
import '../models/labour_model.dart';
import '../models/temp_labour_entry.dart';
import '../services/attendance_service.dart';
import '../services/session_service.dart';
import '../services/temp_labour_service.dart';
import '../services/telemetry_service.dart';
import '../services/temp_labour_cleanup_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({AttendanceService? service})
      : _service = service ?? AttendanceService(),
        _labourBox = Hive.box<Labour>(Labour.boxName);

  final AttendanceService _service;
  final TempLabourService _tempLabourService = TempLabourService();
  final Box<Labour> _labourBox;

  DateTime selectedDate = DateTime.now();

  List<Labour> labours = <Labour>[];
  List<TempLabourEntry> tempLabours = <TempLabourEntry>[];

  Map<String, DailyLabourSummary> dailyShiftMap = <String, DailyLabourSummary>{};
  Map<String, String> attendanceMap = <String, String>{}; // Kept for backward compatibility/quick lookups
  Map<String, double> overtimeMap = <String, double>{};
  Map<String, String> remarkMap = <String, String>{};
  Map<String, double> wageAtTimeMap = <String, double>{};
  Map<String, String> siteMap = <String, String>{};
  Map<String, double> allowancePetrolMap    = <String, double>{};
  Map<String, double> allowanceLunchMap     = <String, double>{};
  Map<String, double> allowanceBreakfastMap = <String, double>{};
  Map<String, double> allowanceTeaMap       = <String, double>{};
  Map<String, double> advanceMap            = <String, double>{};

  bool isLoading = false;
  String? error;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceNestedStream;

  String get selectedDateStr => Attendance.formatDate(selectedDate);

  /// Labours not yet definitively marked — either no record or pending.
  List<Labour> get unmarkedLabours =>
      labours.where((l) {
        final s = attendanceMap[l.id];
        return s == null || s == 'pending';
      }).toList();

  /// Labours with a definitive status (present/absent/half).
  List<Labour> get markedLabours =>
      labours.where((l) {
        final s = attendanceMap[l.id];
        return s != null && s != 'pending';
      }).toList();

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      error = 'Not logged in';
      isLoading = false;
      notifyListeners();
      return;
    }

    await TempLabourCleanupService.runCleanup();

    _loadLocalLabours(uid);
    _loadLocalAttendance();

    await _fetchLabours(uid);
    await _service.fetchAttendanceForDate(selectedDateStr);
    _loadLocalAttendance();
    _computePendingPool(uid);

    isLoading = false;
    notifyListeners();

    _startAttendanceStream(uid);
  }

  void _computePendingPool(String uid) {
    final markedIds = attendanceMap.keys.toSet();
    notifyListeners();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _flatDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _nestedDocs = [];

  void _rebuildMapsFromStreams(String uid) {
    attendanceMap.clear();
    dailyShiftMap.clear();
    overtimeMap.clear();
    remarkMap.clear();
    wageAtTimeMap.clear();
    siteMap.clear();

    final allDocs = [..._flatDocs, ..._nestedDocs];
    for (final doc in allDocs) {
      final data = doc.data();
      final labourId = (data['labourId'] as String?) ?? doc.id;
      final rawStatus = (data['status'] as String?) ?? '';
      final status = _normalizeStatus(rawStatus);
      final ot = (data['overtimeHours'] as num?)?.toDouble() ?? 0;
      final remark = (data['remark'] as String?) ?? (data['notes'] as String?) ?? '';
      final wage = (data['wageAtTime'] as num?)?.toDouble() ?? 0;
      final site = (data['siteId'] as String?) ?? '';
      final factor = (data['shiftFactor'] as num?)?.toDouble() ?? 0.0;

      if (labourId.isEmpty || status.isEmpty) continue;

      if (status == 'pending') continue;

      if (!dailyShiftMap.containsKey(labourId)) {
        dailyShiftMap[labourId] = DailyLabourSummary(
          labourId: labourId,
          totalShiftFactor: 0.0,
          siteVisits: [],
        );
      }
      
      final summary = dailyShiftMap[labourId]!;
      // prevent duplicate processing from flat+nested for same labourId+site
      final existingVisit = summary.siteVisits.any((v) => v.siteId == site);
      if (!existingVisit) {
        summary.totalShiftFactor += factor;
        if (factor > 0) {
          summary.siteVisits.add(SiteVisit(
            siteId: site,
            siteName: site,
            status: status,
            factor: factor,
            docId: doc.id,
          ));
        }
      }

      if (ot > 0) overtimeMap[labourId] = ot;
      if (remark.isNotEmpty) remarkMap[labourId] = remark;
      if (wage > 0) wageAtTimeMap[labourId] = wage;
      if (site.isNotEmpty) siteMap[labourId] = site;
    }

    for (final summary in dailyShiftMap.values) {
      if (summary.totalShiftFactor >= 1.0) {
        attendanceMap[summary.labourId] = 'present';
      } else if (summary.totalShiftFactor >= 0.75) attendanceMap[summary.labourId] = 'three_quarter';
      else if (summary.totalShiftFactor >= 0.5) attendanceMap[summary.labourId] = 'half';
      else if (summary.totalShiftFactor > 0.0) attendanceMap[summary.labourId] = 'quarter';
      else if (summary.siteVisits.isNotEmpty) attendanceMap[summary.labourId] = 'absent';
    }

    _computePendingPool(uid);
    notifyListeners();
  }

  void _startAttendanceStream(String uid) {
    _attendanceStream?.cancel();
    _attendanceNestedStream?.cancel();
    
    _flatDocs = [];
    _nestedDocs = [];

    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;
    final date = selectedDateStr;

    _attendanceStream = db
        .collection('attendance')
        .where('contractorId', isEqualTo: contractorId)
        .where('date', isEqualTo: date)
        .snapshots()
        .listen((snap) {
      _flatDocs = snap.docs;
      _rebuildMapsFromStreams(uid);
    }, onError: (e) {
      debugPrint('[AttendanceProvider] stream error (flat): $e');
    });

    _attendanceNestedStream = db
        .collection('attendance')
        .doc(contractorId)
        .collection('dates')
        .doc(date)
        .collection('records')
        .snapshots()
        .listen((snap) {
      _nestedDocs = snap.docs;
      _rebuildMapsFromStreams(uid);
    }, onError: (e) {
      debugPrint('[AttendanceProvider] stream error (nested): $e');
    });
  }

  String _normalizeStatus(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'half_day' || s == 'half-day') return 'half';
    if (s == 'present' || s == 'absent' || s == 'half') return s;
    if (s == 'quarter' || s == 'three_quarter') return s;
    if (s == 'pending') return 'pending';
    return '';
  }

  void _loadLocalLabours(String uid) {
    final contractorId = SessionService.instance.contractorId ?? uid;
    labours = _labourBox.values.where((l) {
      if (!l.isActive) return false;
      return l.supervisorId == uid ||
          l.contractorId == uid ||
          (contractorId.isNotEmpty && l.contractorId == contractorId);
    }).toList();
    labours.sort((a, b) => a.name.compareTo(b.name));
    
    // Temporarily clear tempLabours while we wait for network fetch
    tempLabours = [];
  }

  Future<void> refreshLabours() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _fetchLabours(uid);
      notifyListeners();
    }
  }

  Future<void> _fetchLabours(String uid) async {
    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;
    final Map<String, Labour> merged = {};

    for (final q in [
      db.collection('labours').where('supervisorId', isEqualTo: uid).where('isActive', isEqualTo: true).get(),
      db.collection('labours').where('contractorId', isEqualTo: uid).where('isActive', isEqualTo: true).get(),
      if (contractorId != uid && contractorId.isNotEmpty)
        db.collection('labours').where('contractorId', isEqualTo: contractorId).where('isActive', isEqualTo: true).get(),
    ]) {
      try {
        final s = await q;
        for (var d in s.docs) {
          merged[d.id] = Labour.fromFirestore(d);
        }
      } catch (e) {
        debugPrint('_fetchLabours query error: $e');
      }
    }

    for (final labour in merged.values) {
      await _labourBox.put(labour.id, labour);
    }

    labours = merged.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    
    // Fetch temp labours for the current date from the new service
    try {
      tempLabours = await _tempLabourService.fetchEntriesForDate(contractorId, selectedDateStr);
    } catch (e) {
      debugPrint('Error fetching temp labours: $e');
      tempLabours = [];
    }

    notifyListeners();
  }

  void _loadLocalAttendance() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final contractorId = SessionService.instance.contractorId ?? uid;

    final records = Hive.box<Attendance>(Attendance.boxName).values
        .where((a) =>
            a.date == selectedDateStr &&
            (a.contractorId == contractorId || a.supervisorId == uid))
        .toList();

    // Rebuild dailyShiftMap
    dailyShiftMap.clear();
    for (final a in records) {
      if (!dailyShiftMap.containsKey(a.labourId)) {
        dailyShiftMap[a.labourId] = DailyLabourSummary(
          labourId: a.labourId,
          totalShiftFactor: 0.0,
          siteVisits: [],
        );
      }
      final factor = a.shiftFactor > 0 ? a.shiftFactor : a.effectiveShiftFactor;
      final summary = dailyShiftMap[a.labourId]!;
      
      if (factor > 0) {
        // Prevent duplicate entries for the same site visit 
        // (caused by fetching from both flat and nested legacy collections)
        final existingIndex = summary.siteVisits.indexWhere((v) => v.siteId == a.siteId);
        if (existingIndex == -1) {
          summary.totalShiftFactor += factor;
          summary.siteVisits.add(SiteVisit(
            siteId: a.siteId,
            siteName: a.siteId, // Will resolve in UI
            status: a.status.firestoreValue,
            factor: factor,
            docId: a.firestoreId ?? a.id,
          ));
        }
      }
    }

    // Pending status is treated as "not yet marked" — exclude from attendanceMap
    // so the labour reappears in the unmarked/available list.
    attendanceMap.clear();
    for (final summary in dailyShiftMap.values) {
      if (summary.totalShiftFactor >= 1.0) {
        attendanceMap[summary.labourId] = 'present';
      } else if (summary.totalShiftFactor >= 0.75) attendanceMap[summary.labourId] = 'three_quarter';
      else if (summary.totalShiftFactor >= 0.5) attendanceMap[summary.labourId] = 'half';
      else if (summary.totalShiftFactor > 0.0) attendanceMap[summary.labourId] = 'quarter';
      else if (summary.siteVisits.isNotEmpty) attendanceMap[summary.labourId] = 'absent';
    }
    overtimeMap   = {for (final a in records) if (a.overtimeHours > 0) a.labourId: a.overtimeHours};
    remarkMap     = {for (final a in records) if (a.remark.isNotEmpty) a.labourId: a.remark};
    wageAtTimeMap = {for (final a in records) if (a.wageAtTime > 0) a.labourId: a.wageAtTime};
    siteMap              = {for (final a in records) if (a.siteId.isNotEmpty) a.labourId: a.siteId};
    allowancePetrolMap    = {for (final a in records) if (a.petrol > 0)    a.labourId: a.petrol};
    allowanceLunchMap     = {for (final a in records) if (a.lunch > 0)     a.labourId: a.lunch};
    allowanceBreakfastMap = {for (final a in records) if (a.breakfast > 0) a.labourId: a.breakfast};
    allowanceTeaMap       = {for (final a in records) if (a.tea > 0)       a.labourId: a.tea};
    advanceMap            = {for (final a in records) if (a.advance > 0)   a.labourId: a.advance};

    notifyListeners();
  }

  Future<void> _fetchFromFirebase() async {
    isLoading = true;
    notifyListeners();
    await _service.fetchAttendanceForDate(selectedDateStr);
    _loadLocalAttendance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _computePendingPool(uid);
    isLoading = false;
    notifyListeners();
  }

  Future<void> changeDate(DateTime newDate) async {
    selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
    _loadLocalAttendance();
    await _fetchFromFirebase();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) _startAttendanceStream(uid);
  }

  Future<void> markAttendance(String labourId, String status, {
    String remark = '',
    double? wageAtTimeOverride,
    String siteId = '',
  }) async {
    final existingOt = overtimeMap[labourId] ?? 0.0;
    final ot = status == 'absent' ? 0.0 : existingOt;

    double wageAtTime = wageAtTimeOverride ?? wageAtTimeMap[labourId] ?? 0.0;
    if (wageAtTime == 0) {
      final labour = _labourBox.get(labourId);
      wageAtTime = labour?.dailyWage ?? 0.0;
    }

    TelemetryService.instance.trackFeatureUsage('Attendance Marked');

    // siteId comes from whichever site card the supervisor tapped —
    // it is NOT stored on the labour document.
    final resolvedSiteId = siteId.isNotEmpty ? siteId : (siteMap[labourId] ?? '');

    final factor = switch (status) {
      'present'       => 1.0,
      'three_quarter' => 0.75,
      'half'          => 0.5,
      'quarter'       => 0.25,
      'absent'        => 0.0,
      'pending'       => 0.0,
      _               => 0.0,
    };

    final att = Attendance(
      id: '${labourId}_${selectedDateStr}_$resolvedSiteId',
      labourId: labourId,
      supervisorId: FirebaseAuth.instance.currentUser!.uid,
      date: selectedDateStr,
      status: AttendanceStatusX.fromFirestoreValue(status),
      shiftFactor: factor,
      overtimeHours: ot,
      wageAtTime: wageAtTime,
      remark: remark.isNotEmpty ? remark : (remarkMap[labourId] ?? ''),
      siteId: resolvedSiteId,
    );

    // --- OPTIMISTIC UI UPDATE ---
    // This synchronously updates the local map and notifies listeners before the async call.
    // This is required so that Dismissible widgets are immediately removed from the tree upon swipe,
    // avoiding the "dismissed widget still in tree" error.
    if (status == 'pending') {
      attendanceMap.remove(labourId);
    } else {
      attendanceMap[labourId] = status;
    }
    siteMap[labourId] = resolvedSiteId;
    
    // Also tentatively update dailyShiftMap for correct UI filtering
    if (!dailyShiftMap.containsKey(labourId)) {
      dailyShiftMap[labourId] = DailyLabourSummary(labourId: labourId, totalShiftFactor: 0, siteVisits: []);
    }
    if (status != 'pending') {
      final summary = dailyShiftMap[labourId]!;
      final existingIndex = summary.siteVisits.indexWhere((v) => v.siteId == resolvedSiteId);
      if (existingIndex >= 0) {
        final oldFactor = summary.siteVisits[existingIndex].factor;
        summary.totalShiftFactor = summary.totalShiftFactor - oldFactor + factor;
        summary.siteVisits[existingIndex] = SiteVisit(
          siteId: resolvedSiteId,
          siteName: resolvedSiteId,
          status: status,
          factor: factor,
          docId: '',
        );
      } else {
        summary.totalShiftFactor += factor;
        summary.siteVisits.add(SiteVisit(
          siteId: resolvedSiteId,
          siteName: resolvedSiteId,
          status: status,
          factor: factor,
          docId: '',
        ));
      }
    }
    
    notifyListeners();
    // ----------------------------

    try {
      await _service.markAttendanceAtSite(att, wageAtTime: wageAtTime, remark: att.remark);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }

    _loadLocalAttendance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _computePendingPool(uid);
  }

  Future<void> setOvertime(String labourId, double hours) async {
    final safe = hours.isFinite && hours > 0 ? hours : 0.0;
    final status = attendanceMap[labourId] ?? 'present';
    final wageAtTime = wageAtTimeMap[labourId] ?? 0.0;
    final remark = remarkMap[labourId] ?? '';
    // Site is already recorded in siteMap from when attendance was first marked
    final resolvedSiteId = siteMap[labourId] ?? '';

    final att = Attendance(
      id: '${labourId}_${selectedDateStr}_$resolvedSiteId',
      labourId: labourId,
      supervisorId: FirebaseAuth.instance.currentUser!.uid,
      date: selectedDateStr,
      status: AttendanceStatusX.fromFirestoreValue(status),
      shiftFactor: dailyShiftMap[labourId]?.siteVisits.firstWhere((v) => v.siteId == resolvedSiteId, orElse: () => const SiteVisit(siteId: '', siteName: '', status: '', factor: 0.0, docId: '')).factor ?? 0.0,
      overtimeHours: safe,
      wageAtTime: wageAtTime,
      remark: remark,
      siteId: resolvedSiteId,
    );
    await _service.markAttendanceAtSite(att, wageAtTime: wageAtTime, remark: remark);

    attendanceMap[labourId] = status;
    if (safe > 0) {
      overtimeMap[labourId] = safe;
    } else {
      overtimeMap.remove(labourId);
    }
    notifyListeners();
  }

  Future<void> setRemark(String labourId, String remark) async {
    remarkMap[labourId] = remark;
    notifyListeners();

    final status = attendanceMap[labourId];
    if (status != null) {
      await _service.updateAttendanceRemark(
        labourId, 
        selectedDateStr, 
        remark, 
        siteId: siteMap[labourId],
      );
    }
  }

  Future<void> addTempLabour({
    required String name,
    required double dailyWage,
    required double attendanceUnit,
    required String siteId,
    String remarks = '',
    double paidAmount = 0.0,
    String paymentRemark = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final contractorId = SessionService.instance.contractorId ?? uid;
    
    final totalWage = dailyWage * attendanceUnit;
    final remainingAmount = totalWage - paidAmount;
    
    String paymentStatus = 'unpaid';
    if (paidAmount > 0) {
      paymentStatus = remainingAmount <= 0 ? 'paid' : 'partial_paid';
    }

    final entry = TempLabourEntry(
      id: const Uuid().v4(),
      contractorId: contractorId,
      supervisorId: uid,
      siteId: siteId,
      date: selectedDateStr,
      name: name,
      wage: dailyWage,
      attendanceUnit: attendanceUnit,
      remarks: remarks,
      totalWage: totalWage,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      paymentStatus: paymentStatus,
      paymentRemark: paymentRemark,
      paymentDate: paidAmount > 0 ? DateTime.now().toIso8601String().split('T')[0] : null,
      paymentTime: paidAmount > 0 ? '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}' : '',
      paidBy: paidAmount > 0 ? SessionService.instance.name ?? 'Supervisor' : '',
    );

    final newEntry = await _tempLabourService.addEntry(entry);
    tempLabours.add(newEntry);
    notifyListeners();
  }

  Future<void> updateTempLabourPayment({
    required String entryId,
    required double paidAmount,
    required String paymentMethod,
    required String paymentRemark,
  }) async {
    final idx = tempLabours.indexWhere((l) => l.id == entryId);
    if (idx == -1) return;

    final oldEntry = tempLabours[idx];
    final remainingAmount = oldEntry.totalWage - paidAmount;
    String paymentStatus = 'unpaid';
    if (paidAmount > 0) {
      paymentStatus = remainingAmount <= 0 ? 'paid' : 'partial_paid';
    }

    final updatedEntry = oldEntry.copyWith(
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      paymentRemark: paymentRemark,
      paymentDate: paidAmount > 0 ? DateTime.now().toIso8601String().split('T')[0] : null,
      paymentTime: paidAmount > 0 ? '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}' : '',
      paidBy: paidAmount > 0 ? SessionService.instance.name ?? 'Supervisor' : '',
    );

    tempLabours[idx] = updatedEntry;
    notifyListeners();
    await _tempLabourService.updateEntry(updatedEntry);
  }

  Future<void> deleteTempLabour(String entryId) async {
    tempLabours.removeWhere((l) => l.id == entryId);
    notifyListeners();
    await _tempLabourService.deleteEntry(entryId);
  }

  Future<int> applyAllowances({
    required String siteId,
    required double petrol,
    required double lunch,
    required double breakfast,
    required double tea,
  }) async {
    final count = await _service.applyAllowances(
      siteId: siteId,
      date: selectedDateStr,
      petrol: petrol,
      lunch: lunch,
      breakfast: breakfast,
      tea: tea,
    );
    _loadLocalAttendance();
    return count;
  }

  Future<void> setAdvance(String labourId, double amount) async {
    advanceMap[labourId] = amount;
    notifyListeners();
    await _service.setAdvance(
      labourId: labourId,
      date: selectedDateStr,
      amount: amount,
      siteId: siteMap[labourId],
    );
    _loadLocalAttendance();
  }

  Future<void> updateSingleLabourAllowances({
    required String labourId,
    required double petrol,
    required double lunch,
    required double breakfast,
    required double tea,
    required double advance,
  }) async {
    allowancePetrolMap[labourId]    = petrol;
    allowanceLunchMap[labourId]     = lunch;
    allowanceBreakfastMap[labourId] = breakfast;
    allowanceTeaMap[labourId]       = tea;
    advanceMap[labourId]            = advance;
    notifyListeners();
    await _service.updateSingleLabourAllowances(
      labourId:  labourId,
      date:      selectedDateStr,
      petrol:    petrol,
      lunch:     lunch,
      breakfast: breakfast,
      tea:       tea,
      advance:   advance,
      siteId:    siteMap[labourId],
    );
    _loadLocalAttendance();
  }

  Future<void> cycleStatus(String labourId) async {
    final current = attendanceMap[labourId] ?? 'absent';
    final next = _service.cycleStatus(current);
    await markAttendance(labourId, next);
  }

  /// Resets a labour's attendance for [selectedDate] back to "pending"
  /// (not yet marked), removing it from the marked list and the local map
  /// so it reappears as available/unmarked in the UI.
  Future<void> markAsPending(String labourId, {String siteId = ''}) async {
    final resolvedSiteId = siteId.isNotEmpty ? siteId : (siteMap[labourId] ?? '');
    
    // --- OPTIMISTIC UI UPDATE ---
    attendanceMap.remove(labourId);
    if (dailyShiftMap.containsKey(labourId)) {
      final summary = dailyShiftMap[labourId]!;
      final existingIndex = summary.siteVisits.indexWhere((v) => v.siteId == resolvedSiteId);
      if (existingIndex >= 0) {
        summary.totalShiftFactor -= summary.siteVisits[existingIndex].factor;
        summary.siteVisits.removeAt(existingIndex);
      }
    }
    notifyListeners();
    // ----------------------------

    await _service.markAsPending(
      labourId,
      selectedDateStr,
      siteId: resolvedSiteId,
    );

    _loadLocalAttendance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _computePendingPool(uid);
  }

  Future<void> bulkMark(String status) async {
    await _service.bulkMarkAttendance(selectedDateStr, status);
  }

  Future<void> copyYesterdayAttendance(List<Labour> availableLabours, String siteId) async {
    if (availableLabours.isEmpty || siteId.isEmpty) return;
    
    final parts = selectedDateStr.split('-');
    if (parts.length != 3) return;
    final currentDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final yesterday = currentDate.subtract(const Duration(days: 1));
    final yStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    final uid = SessionService.instance.uid ?? FirebaseAuth.instance.currentUser?.uid;
    final contractorId = SessionService.instance.contractorId ?? uid ?? '';
    
    final snap = await FirebaseFirestore.instance
        .collection('attendance')
        .where('contractorId', isEqualTo: contractorId)
        .where('date', isEqualTo: yStr)
        .where('siteId', isEqualTo: siteId)
        .get();
        
    final yesterdayStatusMap = <String, String>{};
    for (final doc in snap.docs) {
       final data = doc.data();
       final lId = data['labourId'] as String?;
       final st = data['status'] as String?;
       if (lId != null && st != null) {
          yesterdayStatusMap[lId] = st;
       }
    }
    
    int copiedCount = 0;
    final futures = <Future<void>>[];
    for (final labour in availableLabours) {
      final yStatus = yesterdayStatusMap[labour.id];
      if (yStatus != null && yStatus != 'pending') {
        final summary = dailyShiftMap[labour.id];
        final totalOtherFactor = summary?.totalShiftFactor ?? 0.0;
        final availableCapacity = 1.0 - totalOtherFactor;

        final factorRequired = switch (yStatus) {
          'present'       => 1.0,
          'three_quarter' => 0.75,
          'half'          => 0.5,
          'quarter'       => 0.25,
          'absent'        => 0.0,
          _               => 0.0,
        };

        if (availableCapacity <= 0 && factorRequired > 0) continue;

        String statusToMark = yStatus;
        if (factorRequired > availableCapacity) {
          if (availableCapacity >= 0.75) {
            statusToMark = 'three_quarter';
          } else if (availableCapacity >= 0.5) statusToMark = 'half';
          else if (availableCapacity >= 0.25) statusToMark = 'quarter';
          else statusToMark = 'absent';
        }

        futures.add(markAttendance(
          labour.id,
          statusToMark,
          siteId: siteId,
        ));
        copiedCount++;
      }
    }
    await Future.wait(futures);
    debugPrint('Copied $copiedCount records from yesterday');
  }

  @override
  void dispose() {
    _attendanceStream?.cancel();
    _attendanceNestedStream?.cancel();
    super.dispose();
  }
}
