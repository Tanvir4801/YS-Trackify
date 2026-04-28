import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  bool _isListening = false;

  void startListening() {
    if (_isListening) {
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    _isListening = true;

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
        .where('date', isEqualTo: _todayString())
        .snapshots()
        .listen((snap) {
      var p = 0;
      var a = 0;
      var h = 0;
      for (final doc in snap.docs) {
        final status = (doc.data()['status'] as String?) ?? '';
        if (status == 'present') {
          p += 1;
        } else if (status == 'absent') {
          a += 1;
        } else if (status == 'half') {
          h += 1;
        }
      }

      presentToday = p;
      absentToday = a;
      halfToday = h;
      notifyListeners();
    });
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _labourSub?.cancel();
    super.dispose();
  }
}
