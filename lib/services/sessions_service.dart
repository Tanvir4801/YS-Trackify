import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_session.dart';
import 'session_service.dart';

class SessionsService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  String get uid          => _auth.currentUser?.uid ?? '';
  String get _contractorId {
    final c = SessionService.instance.contractorId;
    return (c != null && c.isNotEmpty) ? c : uid;
  }
String get _supervisorName =>
    _auth.currentUser?.displayName ?? uid;
  String _today() {
    final n = DateTime.now();
    return '${n.year}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // ── Real-time stream of all sessions for today ─────────────────────────────

  Stream<List<AttendanceSession>> sessionsForDate(String date) {
    return _db
        .collection('attendanceSessions')
        .where('contractorId', isEqualTo: _contractorId)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((s) => s.docs.map(AttendanceSession.fromFirestore).toList())
        .handleError((e) {
          debugPrint('sessionsForDate stream error: $e');
          return <AttendanceSession>[];
        });
  }

  // ── Check for orphaned active session for THIS supervisor ──────────────────

  Future<AttendanceSession?> getMyActiveSession() async {
    try {
      final snap = await _db
          .collection('attendanceSessions')
          .where('supervisorId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return AttendanceSession.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('getMyActiveSession error: $e');
      return null;
    }
  }

  // ── Start a session ────────────────────────────────────────────────────────

  Future<AttendanceSession> startSession({
    required String siteId,
    required String siteName,
  }) async {
    final today        = _today();
    final contractorId = _contractorId;

    // Guard: one active session per site per day
    final existing = await _db
        .collection('attendanceSessions')
        .where('siteId',       isEqualTo: siteId)
        .where('date',         isEqualTo: today)
        .where('status',       isEqualTo: 'active')
        .get();

    if (existing.docs.isNotEmpty) {
      throw SessionAlreadyActiveException(
          AttendanceSession.fromFirestore(existing.docs.first));
    }

    final now = DateTime.now();
    final ref = await _db.collection('attendanceSessions').add({
      'supervisorId':      uid,
      'supervisorName':    _supervisorName,
      'siteId':            siteId,
      'siteName':          siteName,
      'contractorId':      contractorId,
      'date':              today,
      'startedAt':         Timestamp.fromDate(now),
      'endedAt':           null,
      'status':            'active',
      'markedCount':       0,
      'totalPresent':      0,
      'totalAbsent':       0,
      'totalHalf':         0,
      'allowancesApplied': false,
    });
    final doc = await ref.get();
    return AttendanceSession.fromFirestore(doc);
  }

  // ── Increment scan counter ─────────────────────────────────────────────────

  Future<void> incrementMarkedCount(String sessionId) async {
    try {
      await _db.collection('attendanceSessions').doc(sessionId).update({
        'markedCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('incrementMarkedCount error: $e');
    }
  }

  // ── End (complete) a session ───────────────────────────────────────────────

  Future<void> endSession(
    String sessionId, {
    required int totalPresent,
    required int totalAbsent,
    required int totalHalf,
    required bool allowancesApplied,
  }) async {
    await _db.collection('attendanceSessions').doc(sessionId).update({
      'status':            'completed',
      'endedAt':           FieldValue.serverTimestamp(),
      'totalPresent':      totalPresent,
      'totalAbsent':       totalAbsent,
      'totalHalf':         totalHalf,
      'allowancesApplied': allowancesApplied,
    });
  }

  // ── Abandon a session ──────────────────────────────────────────────────────

  Future<void> abandonSession(String sessionId) async {
    await _db.collection('attendanceSessions').doc(sessionId).update({
      'status':  'abandoned',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Get session by id ──────────────────────────────────────────────────────

  Future<AttendanceSession?> getSession(String sessionId) async {
    try {
      final doc = await _db
          .collection('attendanceSessions')
          .doc(sessionId)
          .get();
      if (!doc.exists) return null;
      return AttendanceSession.fromFirestore(doc);
    } catch (e) {
      debugPrint('getSession error: $e');
      return null;
    }
  }
}

class SessionAlreadyActiveException implements Exception {
  final AttendanceSession session;
  SessionAlreadyActiveException(this.session);
  @override
  String toString() => 'Active session already exists for ${session.siteName}';
}
