import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/attendance_model.dart';
import '../models/labour_model.dart';
import '../models/payment_model.dart';
import '../models/site_model.dart';
import '../models/material_purchase_model.dart';
import '../models/site_expense_model.dart';
import '../services/session_service.dart';

class ReportsProvider extends ChangeNotifier {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int    month = DateTime.now().month;
  int    year  = DateTime.now().year;

  List<LabourMonthlyReport> reports = [];
  ReportSummary?            summary;
  bool    isLoading = false;
  String? error;

  Timer? _debounce;
  final List<StreamSubscription> _subs = [];
  bool _isFetchingRemote = false;

  String get uid => _auth.currentUser?.uid ?? '';

  String get _contractorId {
    final cached = SessionService.instance.contractorId;
    if (cached != null && cached.isNotEmpty) return cached;
    return uid;
  }

  void loadReport({int? month, int? year}) {
    if (month != null) this.month = month;
    if (year  != null) this.year  = year;

    // 1. FAST LOCAL HYDRATION: Build report from local cache immediately (<5ms)
    _buildFromLocalCache();

    // 2. REMOTE REFRESH: Fetch fresh updates from Firestore in the background
    _cancelSubs();
    _fetchRemoteAndBuild();
  }

  /// Safe query executor that never throws and bounds execution with a timeout.
  Future<QuerySnapshot<Map<String, dynamic>>?> _safeGet(
    Query<Map<String, dynamic>> query, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      return await query.get().timeout(timeout);
    } catch (e) {
      debugPrint('[ReportsProvider] Query notice: $e');
      return null;
    }
  }

  /// Synchronously builds reports from Hive boxes for instant, zero-delay rendering.
  void _buildFromLocalCache() {
    try {
      if (!Hive.isBoxOpen(Labour.boxName) || !Hive.isBoxOpen(Attendance.boxName)) {
        if (reports.isEmpty) {
          isLoading = true;
          notifyListeners();
        }
        return;
      }

      final labourBox = Hive.box<Labour>(Labour.boxName);
      final attBox    = Hive.box<Attendance>(Attendance.boxName);
      final payBox    = Hive.isBoxOpen(Payment.boxName) ? Hive.box<Payment>(Payment.boxName) : null;
      final siteBox   = Hive.isBoxOpen(SiteModel.boxName) ? Hive.box<SiteModel>(SiteModel.boxName) : null;
      final matBox    = Hive.isBoxOpen(MaterialPurchaseModel.boxName) ? Hive.box<MaterialPurchaseModel>(MaterialPurchaseModel.boxName) : null;
      final expBox    = Hive.isBoxOpen(SiteExpenseModel.boxName) ? Hive.box<SiteExpenseModel>(SiteExpenseModel.boxName) : null;

      final monthStr = '$year-${month.toString().padLeft(2, '0')}';
      final cId = _contractorId;

      // Filter labours for this contractor / supervisor
      final relevantLabours = labourBox.values.where((l) {
        return l.supervisorId == uid ||
            l.contractorId == uid ||
            (cId.isNotEmpty && l.contractorId == cId);
      }).toList();

      if (relevantLabours.isEmpty && reports.isEmpty) {
        isLoading = true;
        notifyListeners();
        return;
      }

      // Map site names
      final siteNames = <String, String>{};
      if (siteBox != null) {
        for (final site in siteBox.values) {
          siteNames[site.id] = site.name;
        }
      }

      // Attendance records for this month
      final monthRecords = attBox.values.where((a) {
        if (!a.date.startsWith(monthStr)) return false;
        return a.supervisorId == uid ||
            a.contractorId == uid ||
            (cId.isNotEmpty && a.contractorId == cId);
      }).toList();

      // Group attendance by labourId
      final attByLabour = <String, List<Attendance>>{};
      for (final a in monthRecords) {
        attByLabour.putIfAbsent(a.labourId, () => []).add(a);
      }

      // Payments for this month
      final relevantLabourIds = relevantLabours.map((l) => l.id).toSet();
      final monthPayments = payBox?.values.where((p) {
        return p.date.year == year &&
            p.date.month == month &&
            (relevantLabourIds.contains(p.labourId) || p.supervisorId == uid);
      }).toList() ?? [];

      final payByLabour = <String, List<Payment>>{};
      for (final p in monthPayments) {
        payByLabour.putIfAbsent(p.labourId, () => []).add(p);
      }

      // Material purchases and expenses
      double totalMaterials = 0;
      double totalExpenses  = 0;
      final siteMaterials   = <String, double>{};
      final siteExpenses    = <String, double>{};

      if (matBox != null) {
        for (final m in matBox.values) {
          if (m.purchaseDate.startsWith(monthStr)) {
            totalMaterials += m.totalAmount;
            final sId = m.siteId.isNotEmpty ? m.siteId : 'no_site';
            siteMaterials[sId] = (siteMaterials[sId] ?? 0) + m.totalAmount;
          }
        }
      }

      if (expBox != null) {
        for (final e in expBox.values) {
          if (e.date.startsWith(monthStr)) {
            totalExpenses += e.amount;
            final sId = e.siteId.isNotEmpty ? e.siteId : 'no_site';
            siteExpenses[sId] = (siteExpenses[sId] ?? 0) + e.amount;
          }
        }
      }

      final results = <LabourMonthlyReport>[];

      for (final labour in relevantLabours) {
        final labourAtt = attByLabour[labour.id] ?? [];
        final labourPay = payByLabour[labour.id] ?? [];

        final byDate = <String, List<Map<String, dynamic>>>{};
        final siteBreakdown = <String, SiteReport>{};

        double totalShiftDays  = 0;
        double totalWage       = 0;
        double totalOTPay      = 0;

        for (final a in labourAtt) {
          final factor = a.effectiveShiftFactor;
          final wage = a.wageAtTime > 0 ? a.wageAtTime : labour.dailyWage;
          final ot = a.overtimeHours;
          final otRate = labour.overtimeWagePerHour;
          final siteId = a.siteId.isNotEmpty ? a.siteId : 'no_site';
          final siteName = siteNames[siteId] ?? a.siteName ?? siteId;

          final recordMap = <String, dynamic>{
            'date': a.date,
            'status': a.status.firestoreValue,
            'shiftFactor': factor,
            'dailyWageSnapshot': wage,
            'wageAtTime': wage,
            'overtimeHours': ot,
            'otRateSnapshot': otRate,
            'siteId': siteId,
            'siteName': siteName,
            'notes': a.notes,
          };

          byDate.putIfAbsent(a.date, () => []).add(recordMap);

          totalShiftDays += factor.clamp(0.0, 1.0);
          totalWage      += factor * wage;
          totalOTPay     += ot * otRate;

          siteBreakdown.putIfAbsent(siteId, () => SiteReport(siteId: siteId, siteName: siteName));
          siteBreakdown[siteId]!.addRecord(
            factor: factor,
            wage: wage * factor,
            status: a.status.firestoreValue,
          );
        }

        final totalAdvances = labourPay
            .where((p) => p.type == PaymentType.advance)
            .fold<double>(0.0, (sum, p) => sum + p.amount);

        final grossSalary = totalWage + totalOTPay;
        final netPayable  = grossSalary - totalAdvances;

        if (grossSalary == 0 && totalAdvances == 0 && labourAtt.isEmpty) {
          continue; // Skip workers with no activity in this month
        }

        results.add(LabourMonthlyReport(
          labourId: labour.id,
          labourName: labour.name,
          phone: labour.phone,
          dailyWage: labour.dailyWage,
          isTemp: labour.isTemporary,
          totalDays: totalShiftDays,
          totalWage: totalWage,
          totalOTPay: totalOTPay,
          grossSalary: grossSalary,
          totalAdvances: totalAdvances,
          netPayable: netPayable,
          siteBreakdown: siteBreakdown.values.toList(),
          attendanceByDate: byDate,
        ));
      }

      results.sort((a, b) {
        if (a.isTemp != b.isTemp) return a.isTemp ? 1 : -1;
        return a.labourName.compareTo(b.labourName);
      });

      reports = results;
      summary = ReportSummary(
        month: month,
        year: year,
        totalLabours: results.where((r) => !r.isTemp).length,
        tempLabours: results.where((r) => r.isTemp).length,
        totalGross: results.fold(0.0, (s, r) => s + r.grossSalary),
        totalAdvances: results.fold(0.0, (s, r) => s + r.totalAdvances),
        totalNet: results.fold(0.0, (s, r) => s + r.netPayable),
        totalDaysWorked: results.fold(0.0, (s, r) => s + r.totalDays),
        totalMaterials: totalMaterials,
        totalExpenses: totalExpenses,
        siteMaterials: siteMaterials,
        siteExpenses: siteExpenses,
      );

      // If we found cached records, render without showing a spinner!
      if (reports.isNotEmpty) {
        isLoading = false;
        error = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ReportsProvider] Local cache build error: $e');
    }
  }

  /// Fetches fresh data from Firestore safely without throwing unhandled exceptions.
  Future<void> _fetchRemoteAndBuild() async {
    if (_isFetchingRemote) return;
    _isFetchingRemote = true;

    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final nextMonthStr = month == 12 ? '${year + 1}-01' : '$year-${(month + 1).toString().padLeft(2, '0')}';
    final cId = _contractorId;

    if (reports.isEmpty) {
      isLoading = true;
      notifyListeners();
    }

    try {
      // 1. Fetch Labours (both supervisor & contractor scoped so both account types work)
      final labourQueries = [
        _safeGet(_db.collection('labours').where('supervisorId', isEqualTo: uid)),
        _safeGet(_db.collection('labours').where('contractorId', isEqualTo: uid)),
        if (cId.isNotEmpty && cId != uid)
          _safeGet(_db.collection('labours').where('contractorId', isEqualTo: cId)),
      ];

      final labourSnapshots = await Future.wait(labourQueries);

      final labourDocs = <String, QueryDocumentSnapshot>{};
      for (final s in labourSnapshots) {
        if (s == null) continue;
        for (final doc in s.docs) {
          labourDocs[doc.id] = doc;
          if (Hive.isBoxOpen(Labour.boxName)) {
            try {
              Hive.box<Labour>(Labour.boxName).put(doc.id, Labour.fromFirestore(doc));
            } catch (_) {}
          }
        }
      }

      // 2. Fetch Attendance (Flat collection with date range)
      final attQueries = [
        _safeGet(_db.collection('attendance')
            .where('supervisorId', isEqualTo: uid)
            .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
            .where('date', isLessThan: '$nextMonthStr-01')),
        _safeGet(_db.collection('attendance')
            .where('contractorId', isEqualTo: uid)
            .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
            .where('date', isLessThan: '$nextMonthStr-01')),
        if (cId.isNotEmpty && cId != uid)
          _safeGet(_db.collection('attendance')
              .where('contractorId', isEqualTo: cId)
              .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
              .where('date', isLessThan: '$nextMonthStr-01')),
      ];

      final attSnapshots = await Future.wait(attQueries);

      final fetchedRecords = <Map<String, dynamic>>[];
      for (final s in attSnapshots) {
        if (s == null) continue;
        for (final doc in s.docs) {
          final data = doc.data();
          fetchedRecords.add(data);
          if (Hive.isBoxOpen(Attendance.boxName)) {
            try {
              final att = Attendance.fromFirestore(doc);
              Hive.box<Attendance>(Attendance.boxName).put(att.id, att);
            } catch (_) {}
          }
        }
      }

      // 3. Fast nested attendance check:
      final groupSnap = await _safeGet(
        _db.collectionGroup('records')
            .where('contractorId', isEqualTo: cId)
            .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
            .where('date', isLessThan: '$nextMonthStr-01'),
        timeout: const Duration(seconds: 4),
      );

      if (groupSnap != null) {
        for (final doc in groupSnap.docs) {
          fetchedRecords.add(doc.data());
        }
      } else if (cId.isNotEmpty) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final maxDayToCheck = (year == DateTime.now().year && month == DateTime.now().month)
            ? DateTime.now().day
            : daysInMonth;

        final dateQueries = List.generate(maxDayToCheck, (i) {
          final day = i + 1;
          final dateKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          return _safeGet(
            _db.collection('attendance')
                .doc(cId)
                .collection('dates')
                .doc(dateKey)
                .collection('records'),
            timeout: const Duration(seconds: 3),
          );
        });

        final dateSnaps = await Future.wait(dateQueries);
        for (final snap in dateSnaps) {
          if (snap == null) continue;
          for (final doc in snap.docs) {
            fetchedRecords.add(doc.data());
          }
        }
      }

      // 4. Batch fetch sites to resolve names
      final siteNames = <String, String>{};
      final sitesSnaps = await Future.wait([
        _safeGet(_db.collection('sites').where('contractorId', isEqualTo: cId)),
        if (cId != uid)
          _safeGet(_db.collection('sites').where('contractorId', isEqualTo: uid)),
      ]);
      for (final snap in sitesSnaps) {
        if (snap == null) continue;
        for (final doc in snap.docs) {
          final d = doc.data();
          siteNames[doc.id] = d['name'] as String? ?? doc.id;
          if (d['id'] != null) {
            siteNames[d['id']] = d['name'] as String? ?? d['id'];
          }
        }
      }

      // 5. Batch fetch payments
      final startTs = Timestamp.fromDate(DateTime(year, month, 1));
      final endTs   = Timestamp.fromDate(DateTime(year, month + 1, 0, 23, 59, 59));
      final paymentDocs = <Map<String, dynamic>>[];

      final paySnaps = await Future.wait([
        _safeGet(_db.collection('payments').where('supervisorId', isEqualTo: uid)),
        _safeGet(_db.collection('payments').where('contractorId', isEqualTo: uid)),
        if (cId.isNotEmpty && cId != uid)
          _safeGet(_db.collection('payments').where('contractorId', isEqualTo: cId)),
      ]);

      for (final snap in paySnaps) {
        if (snap == null) continue;
        for (final doc in snap.docs) {
          final d = doc.data();
          final ts = d['date'] as Timestamp?;
          if (ts != null && ts.compareTo(startTs) >= 0 && ts.compareTo(endTs) <= 0) {
            paymentDocs.add(d);
          }
        }
      }

      // 6. Material purchases and expenses (non-blocking)
      double totalMaterials = 0;
      double totalExpenses = 0;
      final siteMaterials = <String, double>{};
      final siteExpenses = <String, double>{};

      final matSnap = await _safeGet(
        _db.collection('materialPurchases')
            .doc(cId).collection('purchases')
            .where('purchaseDate', isGreaterThanOrEqualTo: '$monthStr-01')
            .where('purchaseDate', isLessThan: '$nextMonthStr-01'),
        timeout: const Duration(seconds: 4),
      );
      if (matSnap != null) {
        for (final doc in matSnap.docs) {
          final amt = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
          totalMaterials += amt;
          final sId = doc.data()['siteId'] as String? ?? 'no_site';
          siteMaterials[sId] = (siteMaterials[sId] ?? 0) + amt;
        }
      }

      final expSnap = await _safeGet(
        _db.collection('siteExpenses')
            .doc(cId).collection('expenses')
            .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
            .where('date', isLessThan: '$nextMonthStr-01'),
        timeout: const Duration(seconds: 4),
      );
      if (expSnap != null) {
        for (final doc in expSnap.docs) {
          final amt = (doc.data()['amount'] as num?)?.toDouble() ?? 0;
          totalExpenses += amt;
          final sId = doc.data()['siteId'] as String? ?? 'no_site';
          siteExpenses[sId] = (siteExpenses[sId] ?? 0) + amt;
        }
      }

      // Deduplicate fetchedRecords
      final uniqueRecords = <String, Map<String, dynamic>>{};
      for (final doc in fetchedRecords) {
        final dDate = doc['date'] as String? ?? '';
        final lId = doc['labourId'] as String? ?? '';
        final sId = doc['siteId'] as String? ?? 'no_site';
        if (dDate.isEmpty || lId.isEmpty) continue;

        final key = '${dDate}_${lId}_$sId';
        if (!uniqueRecords.containsKey(key)) {
          uniqueRecords[key] = doc;
        } else {
          final existing = uniqueRecords[key]!;
          if (doc.containsKey('shiftFactor') && !existing.containsKey('shiftFactor')) {
            uniqueRecords[key] = doc;
          }
        }
      }
      final deduplicatedRecords = uniqueRecords.values.toList();

      // Group attendance & payments by labourId
      final attByLabour = <String, List<Map<String, dynamic>>>{};
      for (final d in deduplicatedRecords) {
        final lId = d['labourId'] as String?;
        if (lId != null) {
          attByLabour.putIfAbsent(lId, () => []).add(d);
        }
      }

      final payByLabour = <String, List<Map<String, dynamic>>>{};
      for (final d in paymentDocs) {
        final lId = d['labourId'] as String?;
        if (lId != null) {
          payByLabour.putIfAbsent(lId, () => []).add(d);
        }
      }

      final results = <LabourMonthlyReport>[];

      for (final labourDoc in labourDocs.values) {
        final labData  = labourDoc.data() as Map<String, dynamic>;
        final labourId = labourDoc.id;

        final byDate = <String, List<Map<String, dynamic>>>{};
        final labourAtt = attByLabour[labourId] ?? [];
        for (final d in labourAtt) {
          final date = d['date'] as String? ?? '';
          if (date.startsWith(monthStr)) {
            byDate.putIfAbsent(date, () => []).add(d);
          }
        }

        double totalShiftDays  = 0;
        double totalWage       = 0;
        double totalOTPay      = 0;
        final siteBreakdown    = <String, SiteReport>{};

        byDate.forEach((date, records) {
          double dayFactor = 0;
          double dayWage   = 0;

          for (final rec in records) {
            final factor = (rec['shiftFactor'] as num?)?.toDouble()
                ?? _statusToFactor(rec['status'] as String? ?? '');
            final wage = (rec['dailyWageSnapshot'] as num?)?.toDouble()
                ?? (rec['wageAtTime'] as num?)?.toDouble()
                ?? (labData['dailyWage'] as num?)?.toDouble() ?? 0;
            final ot     = (rec['overtimeHours'] as num?)?.toDouble() ?? 0;
            final otRate = (rec['otRateSnapshot'] as num?)?.toDouble()
                ?? (labData['overtimeWagePerHour'] as num?)?.toDouble() ?? 0;
            final siteId   = rec['siteId']   as String? ?? 'no_site';
            final rawName = rec['siteName'] as String?;
            final siteName = siteNames[siteId] ?? rawName ?? siteId;
            rec['siteName'] = siteName;

            dayFactor += factor;
            dayWage   += factor * wage;
            totalOTPay += ot * otRate;

            siteBreakdown.putIfAbsent(siteId, () => SiteReport(siteId: siteId, siteName: siteName));
            siteBreakdown[siteId]!.addRecord(
              factor: factor,
              wage: wage * factor,
              status: rec['status'] as String?,
            );
          }

          totalShiftDays  += dayFactor.clamp(0.0, 1.0);
          totalWage       += dayWage;
        });

        final isTemp  = labData['type'] == 'temporary';
        final dailyWage = (labData['dailyWage'] as num?)?.toDouble() ?? 0;

        final labourPay = payByLabour[labourId] ?? [];
        final totalAdvances = labourPay
            .where((d) {
               if (d['type'] != 'advance') return false;
               final dateTs = d['date'] as Timestamp?;
               if (dateTs == null) return false;
               return dateTs.compareTo(startTs) >= 0 && dateTs.compareTo(endTs) <= 0;
            })
            .fold(0.0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));

        final grossSalary = totalWage + totalOTPay;
        final netPayable  = grossSalary - totalAdvances;

        if (grossSalary == 0 && totalAdvances == 0 && byDate.isEmpty) {
          continue;
        }

        results.add(LabourMonthlyReport(
          labourId:      labourId,
          labourName:    labData['name']  as String? ?? '',
          phone:         labData['phone'] as String? ?? '',
          dailyWage:     dailyWage,
          isTemp:        isTemp,
          totalDays:     totalShiftDays,
          totalWage:     totalWage,
          totalOTPay:    totalOTPay,
          grossSalary:   grossSalary,
          totalAdvances: totalAdvances,
          netPayable:    netPayable,
          siteBreakdown: siteBreakdown.values.toList(),
          attendanceByDate: byDate,
        ));
      }

      results.sort((a, b) {
        if (a.isTemp != b.isTemp) return a.isTemp ? 1 : -1;
        return a.labourName.compareTo(b.labourName);
      });

      reports = results;
      summary = ReportSummary(
        month:           month,
        year:            year,
        totalLabours:    results.where((r) => !r.isTemp).length,
        tempLabours:     results.where((r) =>  r.isTemp).length,
        totalGross:      results.fold(0, (s, r) => s + r.grossSalary),
        totalAdvances:   results.fold(0, (s, r) => s + r.totalAdvances),
        totalNet:        results.fold(0, (s, r) => s + r.netPayable),
        totalDaysWorked: results.fold(0.0, (s, r) => s + r.totalDays),
        totalMaterials:  totalMaterials,
        totalExpenses:   totalExpenses,
        siteMaterials:   siteMaterials,
        siteExpenses:    siteExpenses,
      );

      isLoading = false;
      error     = null;
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[ReportsProvider] Remote fetch error: $e');
      debugPrint(stack.toString());

      // If we already have local cache or partial data, show it cleanly
      if (reports.isNotEmpty) {
        error = null;
      } else {
        // Fallback: build from local cache once more
        _buildFromLocalCache();
        if (reports.isNotEmpty) {
          error = null;
        } else {
          // If no records exist, show an empty state rather than a crash screen
          summary = ReportSummary(
            month: month,
            year: year,
            totalLabours: 0,
            tempLabours: 0,
            totalGross: 0,
            totalAdvances: 0,
            totalNet: 0,
            totalDaysWorked: 0,
            totalMaterials: 0,
            totalExpenses: 0,
          );
          reports = [];
          error = null;
        }
      }
      isLoading = false;
      notifyListeners();
    } finally {
      _isFetchingRemote = false;
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  double _statusToFactor(String s) {
    if (s == 'present') return 1.0;
    if (s == 'three_quarter') return 0.75;
    if (s == 'half')    return 0.5;
    if (s == 'quarter') return 0.25;
    return 0.0;
  }

  void previousMonth() {
    if (month == 1) { month = 12; year--; }
    else {
      month--;
    }
    loadReport();
  }

  void nextMonth() {
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      if (month == 12) { month = 1; year++; }
      else {
        month++;
      }
      loadReport();
    }
  }

  void _cancelSubs() {
    for (var s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() { 
    _debounce?.cancel();
    _cancelSubs(); 
    super.dispose(); 
  }
}

// ── Data models ──────────────────────────────────────────────

class LabourMonthlyReport {
  const LabourMonthlyReport({
    required this.labourId,
    required this.labourName,
    required this.phone,
    required this.dailyWage,
    required this.isTemp,
    required this.totalDays,
    required this.totalWage,
    required this.totalOTPay,
    required this.grossSalary,
    required this.totalAdvances,
    required this.netPayable,
    required this.siteBreakdown,
    required this.attendanceByDate,
  });

  final String labourId, labourName, phone;
  final double dailyWage;
  final bool   isTemp;
  final double totalDays, totalWage, totalOTPay;
  final double grossSalary, totalAdvances, netPayable;
  final List<SiteReport>                      siteBreakdown;
  final Map<String, List<Map<String, dynamic>>> attendanceByDate;
}

class SiteReport {
  SiteReport({required this.siteId, required this.siteName});
  final String siteId, siteName;
  double totalFactor = 0;
  double totalWage   = 0;
  int    daysCount   = 0;

  int presentCount = 0;
  int threeQuarterCount = 0;
  int halfCount = 0;
  int quarterCount = 0;

  void addRecord({required double factor, required double wage, String? status}) {
    totalFactor += factor;
    totalWage   += wage;
    if (factor > 0) daysCount++;
    
    if (status == 'present') presentCount++;
    else if (status == 'three_quarter') threeQuarterCount++;
    else if (status == 'half') halfCount++;
    else if (status == 'quarter') quarterCount++;
  }
}

class ReportSummary {
  const ReportSummary({
    required this.month,
    required this.year,
    required this.totalLabours,
    required this.tempLabours,
    required this.totalGross,
    required this.totalAdvances,
    required this.totalNet,
    required this.totalDaysWorked,
    required this.totalMaterials,
    required this.totalExpenses,
    this.siteMaterials = const {},
    this.siteExpenses = const {},
  });
  final int    month, year, totalLabours, tempLabours;
  final double totalGross, totalAdvances, totalNet, totalDaysWorked;
  final double totalMaterials, totalExpenses;
  final Map<String, double> siteMaterials;
  final Map<String, double> siteExpenses;
  String get monthName {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[month]} $year';
  }
}
