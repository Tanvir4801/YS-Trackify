import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _labourSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _contractorLabourSub;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _nestedSubs = [];
      
  StreamSubscription<DatabaseEvent>? _rtdbSub;

  int presentToday = 0;
  int absentToday = 0;
  int halfToday = 0;
  int totalLabour = 0;
  double totalExpenseToday = 0;

  Map<String, Map<String, int>> weekAttendance = {};

  bool _isListening = false;
  String? _listeningContractorId;

  final Map<String, Map<String, dynamic>> _supervisorAttendanceDocs = {};
  final Map<String, Map<String, dynamic>> _contractorAttendanceDocs = {};

  final Map<String, dynamic> _supervisorLabours = {};
  final Map<String, dynamic> _contractorLabours = {};

  /// Mirrors nested attendance records from:
  /// attendance/{contractorId}/dates/{date}/records
  ///
  /// Keyed by: "labourId|dateStr" so we can reliably count by date
  /// even when nested docs don't always contain a usable date field.
  Map<String, Map<String, dynamic>> _nestedAttendanceDocs = {};





  /// Starts merged supervisorId + contractorId real-time listeners.
  ///
  /// Attendance/labour docs may be scoped by either `supervisorId` (the
  /// creating user) or `contractorId` (the team the user belongs to) — a
  /// team member's own uid often differs from their contractorId, so a
  /// listener that only filters by `supervisorId` silently misses records
  /// created under the shared contractor scope. Both scopes are merged here
  /// so the week strip always matches the counts shown elsewhere on the
  /// dashboard (which already merge both scopes locally).
  void startListening({String? contractorId}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    if (_isListening && _listeningContractorId == contractorId) {
      return;
    }

    debugPrint('\n[DashboardProvider] startListening(uid=$uid, contractorId=$contractorId)');

    _attendanceSub?.cancel();
    _labourSub?.cancel();
    _contractorLabourSub?.cancel();
    for (final sub in _nestedSubs) {
      sub.cancel();
    }
    _nestedSubs.clear();
    _rtdbSub?.cancel();

    _isListening = true;
    _listeningContractorId = contractorId;

    final resolvedContractorId =
        (contractorId != null && contractorId.isNotEmpty) ? contractorId : uid;

    _labourSub = _firestore
        .collection('labours')
        .where('supervisorId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .limit(1000)
        .snapshots()
        .listen((snap) {
      _supervisorLabours.clear();
      for (final doc in snap.docs) {
        _supervisorLabours[doc.id] = doc.data();
      }
      _refreshLabourCount();
    });

    if (resolvedContractorId != uid) {
      _contractorLabourSub = _firestore
          .collection('labours')
          .where('contractorId', isEqualTo: resolvedContractorId)
          .where('isActive', isEqualTo: true)
          .limit(1000)
          .snapshots()
          .listen((snap) {
        _contractorLabours.clear();
        for (final doc in snap.docs) {
          _contractorLabours[doc.id] = doc.data();
        }
        _refreshLabourCount();
      });
    } else {
      _contractorLabours.clear();
    }

    // Removed unbounded flat attendance queries to drastically improve startup time.
    // The dashboard now relies entirely on the optimized per-date nested queries below.

    // Nested attendance listener for week strip.
    // attendance/{contractorId}/dates/{date}/records
    final last7 = _last7Days().toList()..sort();
    debugPrint('[DashboardProvider] nested attendance listener dates(count=${last7.length}): $last7');

    // We attach per-date subscriptions and merge into _nestedAttendanceDocs.
    // To keep this provider simple and avoid leaking listeners, we only
    // keep a single subscription reference by using a broad query if possible.
    // Firestore cannot query across subcollections, so we instead listen
    // to today+last6 by creating a listener per date is required. Here we
    // implement it with one Firestore query per date using collectionGroup
    // only if it exists. Since we cannot assume indexes/schema, we do per-date.

    _nestedAttendanceDocs = {};

    // Subscribe to each of the last 7 dates.
    // We store nested records under a composite key (labourId|dateStr)
    // so recompute can count reliably by date.
    for (final dateStr in last7) {
      final sub = _firestore
          .collection('attendance')
          .doc(resolvedContractorId)
          .collection('dates')
          .doc(dateStr)
          .collection('records')
          .snapshots()
          .listen((snap) {
        debugPrint('[DashboardProvider] nested records updated for $dateStr: ${snap.docs.length}');
        for (final doc in snap.docs) {
          final data = doc.data();
          final labourId = (data['labourId'] as String?) ?? '';
          if (labourId.isEmpty) continue;
          _nestedAttendanceDocs['$labourId|$dateStr'] = <String, dynamic>{
            ...data,
            // ensure recompute can find the date even if doc.data() doesn't include it
            'date': dateStr,
          };
        }
        _recomputeAttendanceTotals();
      }, onError: (e) {
        debugPrint('[DashboardProvider] nested records error for $dateStr: $e');
      });
      _nestedSubs.add(sub);
    }

    // Removed RTDB listener completely. 
    // Live dashboard stats are now computed perfectly in sync from the nested Firestore records below.

  }

  void _refreshLabourCount() {
    final merged = <String, dynamic>{}
      ..addAll(_supervisorLabours)
      ..addAll(_contractorLabours);
    totalLabour = merged.length;
    notifyListeners();
  }

  void _recomputeAttendanceTotals() {
    final merged = <String, Map<String, dynamic>>{}
      ..addAll(_nestedAttendanceDocs);

    final weekMap = <String, Map<String, int>>{};
    final last7 = _last7Days();
    final todayStr = _todayString();

    int seenThisRecompute = 0;
    int weekHits = 0;
    
    int tempPresent = 0;
    int tempAbsent = 0;
    int tempHalf = 0;
    double tempExpense = 0;

    for (final data in merged.values) {
      seenThisRecompute++;

      final status = (data['status'] as String?) ?? '';
      if (status != 'present' && status != 'absent' && status != 'half') {
        continue;
      }

      final dateRaw = data['date'] ?? data['day'] ?? data['dateStr'];
      final date = _extractDate(dateRaw);
      if (date.isEmpty) continue;

      if (last7.contains(date)) {
        weekHits++;
        weekMap.putIfAbsent(date, () => {'present': 0, 'absent': 0, 'half': 0});
        if (status == 'present') {
          weekMap[date]!['present'] = (weekMap[date]!['present']! + 1);
        } else if (status == 'absent') {
          weekMap[date]!['absent'] = (weekMap[date]!['absent']! + 1);
        } else if (status == 'half') {
          weekMap[date]!['half'] = (weekMap[date]!['half']! + 1);
        }
      }
      
      if (date == todayStr) {
        if (status == 'present') tempPresent++;
        if (status == 'absent') tempAbsent++;
        if (status == 'half') tempHalf++;
        
        final wage = (data['wageAtTime'] as num?)?.toDouble() ?? 0.0;
        final advance = (data['advance'] as num?)?.toDouble() ?? 0.0;
        final allowance = (data['totalAllowance'] as num?)?.toDouble() ?? 0.0;
        final grandTotal = wage + allowance - advance;
        if (grandTotal > 0 && status != 'absent') {
          tempExpense += grandTotal;
        }
      }
    }

    presentToday = tempPresent;
    absentToday = tempAbsent;
    halfToday = tempHalf;
    totalExpenseToday = tempExpense;
    weekAttendance = weekMap;
    notifyListeners();
  }


  String _todayString() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  String _extractDate(dynamic raw) {
    if (raw is String) return raw.trim().split('T').first;
    if (raw is Timestamp) return DateFormat('yyyy-MM-dd').format(raw.toDate());
    if (raw is DateTime) return DateFormat('yyyy-MM-dd').format(raw);
    return '';
  }

  Set<String> _last7Days() {
    final today = DateTime.now();
    return Set.from(
      List.generate(7, (i) => DateFormat('yyyy-MM-dd')
          .format(today.subtract(Duration(days: i)))),
    );
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _labourSub?.cancel();
    _contractorLabourSub?.cancel();
    for (final sub in _nestedSubs) {
      sub.cancel();
    }
    _nestedSubs.clear();
    _rtdbSub?.cancel();
    super.dispose();
  }
}

