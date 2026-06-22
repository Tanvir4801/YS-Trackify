import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/date_utils.dart';
import '../models/attendance_record.dart';
import '../models/labour.dart';
import '../models/temp_labour_entry.dart';
import '../models/labour_report_summary.dart';
import '../services/hive_service.dart';
import '../services/labour_mode/payment_service.dart';
import '../services/session_service.dart';

class SiteDataProvider extends ChangeNotifier {
  SiteDataProvider({required HiveService hiveService})
      : _hiveService = hiveService;

  final HiveService _hiveService;
  PaymentService get _paymentService => PaymentService(hiveService: _hiveService);
  HiveService get hiveService => _hiveService;
  final Random _random = Random();

  // Stream-backed labour list
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _supervisorLabourSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _contractorLabourSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _supervisorAttendanceSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _contractorAttendanceSubscription;
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _supervisorTempLabourSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _contractorTempLabourSubscription;
  
  Map<String, Labour> _supervisorLabours = {};
  Map<String, Labour> _contractorLabours = {};
  
  List<TempLabourEntry> _tempLabourEntries = [];
  
  List<Labour> _labours = [];
  List<Labour> get labours => _labours;

  List<AttendanceRecord> _attendanceRecords = [];
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;

  String get selectedDateKey => AppDateUtils.toDateKey(_selectedDate);

  List<AttendanceRecord> get selectedDateAttendance {
    return _attendanceRecords
        .where((record) => record.dateKey == selectedDateKey)
        .toList();
  }

  Map<String, AttendanceRecord> get selectedDateAttendanceMap {
    final map = <String, AttendanceRecord>{};
    for (final item in selectedDateAttendance) {
      map[item.labourId] = item;
    }
    return map;
  }

  Future<void> initialize() async {
    _setLoading(true);
    _attendanceRecords = _hiveService.getAllAttendanceRecords();
    _labours = _hiveService.getAllLabours();
    final contractorId = SessionService.instance.contractorId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    if (contractorId.isNotEmpty) {
      startLabourStream(contractorId);
    }
    await _backfillAdvancePayments();
    _setLoading(false);
  }

  // ─── Firestore labour stream ───────────────────────────────────────────────

  void startLabourStream(String contractorId) {
    _supervisorLabourSubscription?.cancel();
    _contractorLabourSubscription?.cancel();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirebaseFirestore.instance;

    void updateLabours() {
      final merged = <String, Labour>{
        ..._supervisorLabours,
        ..._contractorLabours,
      };
      // Keep legacy temporary labours so older records compute cost accurately
      _labours = merged.values.toList();
      debugPrint('🔴 SiteDataProvider stream: ${_labours.length} labours (merged)');
      notifyListeners();
    }

    // Legacy V1 data: queried by supervisorId
    _supervisorLabourSubscription = db
        .collection('labours')
        .where('supervisorId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      _supervisorLabours = {
        for (final doc in snap.docs)
          doc.id: _docToLabour(doc.id, doc.data())
      };
      updateLabours();
    }, onError: (e) => debugPrint('❌ Supervisor labour stream error: $e'));

    // V2 data: queried by contractorId
    if (contractorId.isNotEmpty) {
      _contractorLabourSubscription = db
          .collection('labours')
          .where('contractorId', isEqualTo: contractorId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snap) {
        _contractorLabours = {
          for (final doc in snap.docs)
            doc.id: _docToLabour(doc.id, doc.data())
        };
        updateLabours();
      }, onError: (e) => debugPrint('❌ Contractor labour stream error: $e'));
    }

    _startMonthAttendanceStream(contractorId, uid);
  }

  Labour _docToLabour(String id, Map<String, dynamic> data) {
    return Labour(
      id: id,
      name: (data['name'] as String?) ?? '',
      role: (data['skill'] as String?) ?? (data['role'] as String?) ?? '',
      dailyWage: ((data['dailyWage'] ?? data['dailyRate']) as num?)?.toDouble() ?? 0,
      phoneNumber: (data['phone'] as String?) ?? (data['phoneNumber'] as String?) ?? '',
      advanceAmount: ((data['advanceAmount'] as num?) ?? 0).toDouble(),
      extraHours: ((data['defaultOvertimeHours'] as num?) ?? 0).toDouble(),
      overtimeRate: ((data['overtimeWagePerHour'] as num?) ?? 0).toDouble(),
    );
  }

  void _startMonthAttendanceStream(String contractorId, String uid) {
    _supervisorAttendanceSubscription?.cancel();
    _contractorAttendanceSubscription?.cancel();

    final now = DateTime.now();
    final monthStart =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        
    Map<String, AttendanceRecord> supervisorRecords = {};
    Map<String, AttendanceRecord> contractorRecords = {};
    
    void updateAttendance() {
      // Merge: Firestore records override Hive records for same key
      final mergedMap = <String, AttendanceRecord>{
        for (final r in _hiveService.getAllAttendanceRecords())
          '${r.labourId}_${r.dateKey}': r,
      };
      
      for (final r in supervisorRecords.values) {
        mergedMap['${r.labourId}_${r.dateKey}'] = r;
      }
      for (final r in contractorRecords.values) {
        mergedMap['${r.labourId}_${r.dateKey}'] = r;
      }

      _attendanceRecords = mergedMap.values.toList();
      notifyListeners();
    }

    void updateTempLabours(QuerySnapshot<Map<String, dynamic>> snap, bool isContractor) {
      final entries = snap.docs.map((d) => TempLabourEntry.fromFirestore(d)).toList();
      // Remove old entries from this specific source (using contractorId/supervisorId)
      if (isContractor) {
        _tempLabourEntries.removeWhere((e) => e.contractorId == contractorId);
      } else {
        _tempLabourEntries.removeWhere((e) => e.supervisorId == uid && e.contractorId != contractorId);
      }
      _tempLabourEntries.addAll(entries);
      // Remove duplicates by ID
      final unique = {for (final e in _tempLabourEntries) e.id: e};
      _tempLabourEntries = unique.values.toList();
      notifyListeners();
    }

    _supervisorAttendanceSubscription = FirebaseFirestore.instance
        .collection('attendance')
        .where('supervisorId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: monthStart)
        .snapshots()
        .listen(
      (snap) {
        supervisorRecords = {
          for (final doc in snap.docs)
            if (_docToRecord(doc.id, doc.data()) != null)
              doc.id: _docToRecord(doc.id, doc.data())!
        };
        updateAttendance();
      },
      onError: (e) => debugPrint('❌ Supervisor attendance stream error: $e'),
    );

    _supervisorTempLabourSubscription = FirebaseFirestore.instance
        .collection('temp_labour_entries')
        .where('supervisorId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: monthStart)
        .snapshots()
        .listen(
      (snap) => updateTempLabours(snap, false),
      onError: (e) => debugPrint('❌ Supervisor temp labour stream error: $e'),
    );

    if (contractorId.isNotEmpty) {
      _contractorAttendanceSubscription = FirebaseFirestore.instance
          .collection('attendance')
          .where('contractorId', isEqualTo: contractorId)
          .where('date', isGreaterThanOrEqualTo: monthStart)
          .snapshots()
          .listen(
        (snap) {
          contractorRecords = {
            for (final doc in snap.docs)
              if (_docToRecord(doc.id, doc.data()) != null)
                doc.id: _docToRecord(doc.id, doc.data())!
          };
          updateAttendance();
        },
        onError: (e) => debugPrint('❌ Contractor attendance stream error: $e'),
      );
      
      _contractorTempLabourSubscription = FirebaseFirestore.instance
          .collection('temp_labour_entries')
          .where('contractorId', isEqualTo: contractorId)
          .where('date', isGreaterThanOrEqualTo: monthStart)
          .snapshots()
          .listen(
        (snap) => updateTempLabours(snap, true),
        onError: (e) => debugPrint('❌ Contractor temp labour stream error: $e'),
      );
    }
  }

  AttendanceRecord? _docToRecord(String id, Map<String, dynamic> data) {
    final labourId = (data['labourId'] as String?) ?? '';
    final dateKey = (data['date'] as String?) ?? '';
    final statusStr = (data['status'] as String?) ?? 'absent';
    final ot = ((data['overtimeHours'] as num?) ?? 0).toDouble();
    final shiftFactor = ((data['shiftFactor'] as num?) ?? -1.0).toDouble();

    if (labourId.isEmpty || dateKey.isEmpty) return null;

    AttendanceStatus status;
    switch (statusStr) {
      case 'present':
        status = AttendanceStatus.present;
        break;
      case 'half':
      case 'half_day':
      case 'half-day':
        status = AttendanceStatus.halfDay;
        break;
      default:
        status = AttendanceStatus.absent;
    }

    return AttendanceRecord(
      id: id,
      labourId: labourId,
      dateKey: dateKey,
      status: status,
      overtimeHours: ot,
      shiftFactor: shiftFactor,
    );
  }

  void stopLabourStream() {
    _supervisorLabourSubscription?.cancel();
    _supervisorLabourSubscription = null;
    _contractorLabourSubscription?.cancel();
    _contractorLabourSubscription = null;
    
    _supervisorAttendanceSubscription?.cancel();
    _supervisorAttendanceSubscription = null;
    _contractorAttendanceSubscription?.cancel();
    _contractorAttendanceSubscription = null;
    
    _supervisorTempLabourSubscription?.cancel();
    _supervisorTempLabourSubscription = null;
    _contractorTempLabourSubscription?.cancel();
    _contractorTempLabourSubscription = null;
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> addLabour({
    required String name,
    required String role,
    required double dailyWage,
    required String phoneNumber,
    double advanceAmount = 0,
    double extraHours = 0,
    double overtimeRate = 0,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;

    try {
      final docRef = await db.collection('labours').add({
        'name': name,
        'skill': role,
        'role': role,
        'dailyWage': dailyWage,
        'dailyRate': dailyWage,
        'phone': phoneNumber,
        'phoneNumber': phoneNumber,
        'advanceAmount': advanceAmount,
        'defaultOvertimeHours': extraHours,
        'overtimeWagePerHour': overtimeRate,
        'supervisorId': uid,
        'supervisorRef': db.doc('users/$uid'),
        'contractorId': contractorId,
        'isActive': true,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      });

      await docRef.update({'id': docRef.id});
      debugPrint('✅ Labour added: $name → ${docRef.id}');
    } catch (e) {
      debugPrint('❌ addLabour failed: $e');
      rethrow;
    }
  }

  Future<void> updateLabour(Labour labour) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;

    try {
      await db.collection('labours').doc(labour.id).set({
        'name': labour.name,
        'skill': labour.role,
        'role': labour.role,
        'dailyWage': labour.dailyWage,
        'dailyRate': labour.dailyWage,
        'phone': labour.phoneNumber,
        'phoneNumber': labour.phoneNumber,
        'advanceAmount': labour.advanceAmount,
        'defaultOvertimeHours': labour.extraHours,
        'overtimeWagePerHour': labour.overtimeRate,
        'supervisorId': uid,
        'supervisorRef': db.doc('users/$uid'),
        'contractorId': contractorId,
        'isActive': true,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Labour updated: ${labour.name}');
    } catch (e) {
      debugPrint('❌ updateLabour failed: $e');
      rethrow;
    }
  }

  Future<void> assignSite(String labourId, String siteId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('labours')
          .doc(labourId)
          .set({'siteId': siteId}, SetOptions(merge: true));
      debugPrint('✅ Labour $labourId assigned to site $siteId');
    } catch (e) {
      debugPrint('❌ assignSite failed: $e');
      rethrow;
    }
  }

  Future<void> deleteLabour(String labourId) async {
    try {
      await FirebaseFirestore.instance
          .collection('labours')
          .doc(labourId)
          .update({
        'isActive': false,
        'syncedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Labour deleted: $labourId');
    } catch (e) {
      debugPrint('❌ deleteLabour failed: $e');
      rethrow;
    }
  }

  Future<void> addAdvancePayment({
    required String labourId,
    required double amount,
  }) async {
    if (amount <= 0) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;

    try {
      await db.collection('labours').doc(labourId).update({
        'advanceAmount': FieldValue.increment(amount),
        'syncedAt': FieldValue.serverTimestamp(),
      });

      await db.collection('payments').add({
        'contractorId': contractorId,
        'labourId': labourId,
        'labourRef': db.doc('labours/$labourId'),
        'amount': amount,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'paid',
        'notes': 'Advance payment',
        'createdBy': db.doc('users/$uid'),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Advance added: Rs$amount for $labourId');
    } catch (e) {
      debugPrint('❌ addAdvancePayment failed: $e');
      rethrow;
    }
  }

  // ─── Attendance (local Hive) ───────────────────────────────────────────────

  void setSelectedDate(DateTime value) {
    _selectedDate = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  Future<void> markAttendance({
    required String labourId,
    required AttendanceStatus status,
  }) async {
    final record = AttendanceRecord(
      id: _id(),
      labourId: labourId,
      dateKey: selectedDateKey,
      status: status,
    );

    await _hiveService.upsertAttendance(record);
    _attendanceRecords = _hiveService.getAllAttendanceRecords();
    notifyListeners();
  }

  Future<void> addOvertimeRecord({
    required String labourId,
    required double hours,
    required double rate,
  }) async {
    if (hours <= 0 || rate <= 0) return;

    final index = _labours.indexWhere((item) => item.id == labourId);
    if (index == -1) return;

    final labour = _labours[index];
    final newExtraHours = labour.extraHours + hours;

    await updateLabour(
      labour.copyWith(
        extraHours: newExtraHours,
        overtimeRate: rate,
      ),
    );
  }

  // ─── Computed stats ────────────────────────────────────────────────────────

  int get totalLabourCount => _labours.length;

  int get todayPresentCount =>
      _countByStatus(DateTime.now(), AttendanceStatus.present);
  int get todayAbsentCount =>
      _countByStatus(DateTime.now(), AttendanceStatus.absent);
  int get todayHalfDayCount =>
      _countByStatus(DateTime.now(), AttendanceStatus.halfDay);

  double get todayWageTotal => wageTotalForDate(DateTime.now());
  double get weekWageTotal => wageTotalForWeek(DateTime.now());
  double get monthWageTotal => wageTotalForMonth(DateTime.now());

  double get totalAdvancePaid =>
      _labours.fold(0, (sum, item) => sum + item.advanceAmount);

  double wageTotalForDate(DateTime date) {
    final dateKey = AppDateUtils.toDateKey(date);
    final attendanceByLabour = {
      for (final item
          in _attendanceRecords.where((record) => record.dateKey == dateKey))
        item.labourId: item,
    };

    var total = 0.0;
    for (final labour in _labours) {
      final record = attendanceByLabour[labour.id];
      if (record == null) continue;
      total += labour.dailyWage * (record.shiftFactor > 0 ? record.shiftFactor : record.effectiveShiftFactor);
      if (record.overtimeHours > 0 && labour.overtimeRate > 0) {
        total += record.overtimeHours * labour.overtimeRate;
      }
    }
    
    // Add V2 temporary labour costs
    for (final temp in _tempLabourEntries) {
      if (temp.date == dateKey) {
        total += temp.wage * temp.attendanceUnit;
      }
    }

    return total;
  }

  double wageTotalForWeek(DateTime date) {
    final start = AppDateUtils.startOfWeek(date);
    var total = 0.0;
    for (var i = 0; i < 7; i++) {
      total += wageTotalForDate(start.add(Duration(days: i)));
    }
    return total;
  }

  double wageTotalForMonth(DateTime date) {
    var total = 0.0;
    final first = DateTime(date.year, date.month, 1);
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    final days = nextMonth.difference(first).inDays;
    for (var i = 0; i < days; i++) {
      total += wageTotalForDate(first.add(Duration(days: i)));
    }
    return total;
  }

  List<LabourReportSummary> buildLabourReport() {
    final result = <LabourReportSummary>[];

    for (final labour in _labours) {
      final records =
          _attendanceRecords.where((record) => record.labourId == labour.id);
      var present = 0;
      var absent = 0;
      var half = 0;
      var wage = 0.0;
      var perDayOtHours = 0.0;
      var perDayOtPay = 0.0;

      for (final record in records) {
        switch (record.status) {
          case AttendanceStatus.present:
            present += 1;
            wage += labour.dailyWage;
            break;
          case AttendanceStatus.absent:
            absent += 1;
            break;
          case AttendanceStatus.halfDay:
            half += 1;
            wage += labour.dailyWage * 0.5;
            break;
        }
        if (record.overtimeHours > 0) {
          perDayOtHours += record.overtimeHours;
          perDayOtPay += record.overtimeHours * labour.overtimeRate;
        }
      }

      final overtimePay =
          perDayOtPay > 0 ? perDayOtPay : labour.overtimePay;
      final extraHours =
          perDayOtHours > 0 ? perDayOtHours : labour.extraHours;

      result.add(
        LabourReportSummary(
          labourName: labour.name,
          role: labour.role,
          presentDays: present,
          halfDays: half,
          absentDays: absent,
          totalEarned: wage,
          overtimePay: overtimePay,
          advanceAmount: labour.advanceAmount,
          extraHours: extraHours,
        ),
      );
    }

    return result;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _backfillAdvancePayments() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('backfill_v1_done') == true) return;

    for (final labour in _labours) {
      if (labour.advanceAmount <= 0) continue;

      final existingPayments = _hiveService.getPaymentsForLabour(labour.id);
      if (existingPayments.isNotEmpty) continue;

      await _paymentService.recordPayment(
        labourId: labour.id,
        amount: labour.advanceAmount,
        date: AppDateUtils.toDateKey(DateTime.now()),
      );
    }
    await prefs.setBool('backfill_v1_done', true);
  }

  int _countByStatus(DateTime date, AttendanceStatus status) {
    final dateKey = AppDateUtils.toDateKey(date);
    return _attendanceRecords
        .where((record) => record.dateKey == dateKey && record.status == status)
        .length;
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(999)}';

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _supervisorLabourSubscription?.cancel();
    _contractorLabourSubscription?.cancel();
    _supervisorAttendanceSubscription?.cancel();
    _contractorAttendanceSubscription?.cancel();
    super.dispose();
  }
}
