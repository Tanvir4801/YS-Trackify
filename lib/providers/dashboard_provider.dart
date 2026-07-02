import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  int presentToday = 0;
  int absentToday = 0;
  int halfToday = 0;
  int totalLabour = 0;

  Map<String, Map<String, int>> weekAttendance = {};

  bool _isListening = false;
  String? _listeningContractorId;

  Map<String, Map<String, dynamic>> _supervisorAttendanceDocs = {};
  Map<String, Map<String, dynamic>> _contractorAttendanceDocs = {};

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

    _attendanceSub?.cancel();
    _labourSub?.cancel();
    _isListening = true;
    _listeningContractorId = contractorId;

    final resolvedContractorId =
        (contractorId != null && contractorId.isNotEmpty) ? contractorId : uid;

    _labourSub = _firestore
        .collection('labours')
        .where('supervisorId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      totalLabour = snap.docs.length;
      notifyListeners();
    });

    _attendanceSub = _firestore
        .collection('attendance')
        .where('supervisorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      _supervisorAttendanceDocs = {for (final doc in snap.docs) doc.id: doc.data()};
      _recomputeAttendanceTotals();
    });

    if (resolvedContractorId != uid) {
      _firestore
          .collection('attendance')
          .where('contractorId', isEqualTo: resolvedContractorId)
          .snapshots()
          .listen((snap) {
        _contractorAttendanceDocs = {for (final doc in snap.docs) doc.id: doc.data()};
        _recomputeAttendanceTotals();
      });
    }
  }

  void _recomputeAttendanceTotals() {
    final merged = <String, Map<String, dynamic>>{}
      ..addAll(_supervisorAttendanceDocs)
      ..addAll(_contractorAttendanceDocs);

    final today = _todayString();
    var p = 0;
    var a = 0;
    var h = 0;

    final weekMap = <String, Map<String, int>>{};
    final last7 = _last7Days();

    for (final data in merged.values) {
      final status = (data['status'] as String?) ?? '';
      final dateRaw = data['date'];
      final date = _extractDate(dateRaw);

      if (date == today) {
        if (status == 'present') p += 1;
        else if (status == 'absent') a += 1;
        else if (status == 'half') h += 1;
      }

      if (last7.contains(date)) {
        weekMap.putIfAbsent(date, () => {'present': 0, 'absent': 0, 'half': 0});
        if (status == 'present') weekMap[date]!['present'] = (weekMap[date]!['present']! + 1);
        else if (status == 'absent') weekMap[date]!['absent'] = (weekMap[date]!['absent']! + 1);
        else if (status == 'half') weekMap[date]!['half'] = (weekMap[date]!['half']! + 1);
      }
    }

    presentToday = p;
    absentToday = a;
    halfToday = h;
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
    super.dispose();
  }
}
