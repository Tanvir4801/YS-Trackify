import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_session_model.dart';
import 'session_service.dart';

/// Sessions are stored at:
///   attendance/{contractorId}/sessions/{sessionId}
///
/// This path is already covered by the existing Firestore wildcard rule:
///   match /attendance/{contractorId}/{rest=**} { allow write: canManageTenant }
/// so NO new Firestore rules are needed.
class AttendanceSessionService {
  AttendanceSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  String get _contractorId {
    final c = SessionService.instance.contractorId;
    return (c != null && c.isNotEmpty) ? c : _uid;
  }

  String _todayString() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Sessions subcollection for the current contractor.
  CollectionReference<Map<String, dynamic>> _sessionsCol(String contractorId) =>
      _db.collection('attendance').doc(contractorId).collection('sessions');

  CollectionReference<Map<String, dynamic>> get _col =>
      _sessionsCol(_contractorId);

  /// Document reference given a sessionId (uses current contractorId).
  DocumentReference<Map<String, dynamic>> _docRef(String sessionId) =>
      _col.doc(sessionId);

  // ── Start a session ──────────────────────────────────────────────────────────
  Future<AttendanceSession> startSession({
    required String siteId,
    required String siteName,
    String supervisorName = '',
  }) async {
    final uid = _uid;
    if (uid.isEmpty) throw Exception('Not logged in');
    final contractorId = _contractorId;
    final today = _todayString();
    final col = _sessionsCol(contractorId);

    // Check for existing active session for THIS supervisor
    final myActive = await col
        .where('supervisorId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (myActive.docs.isNotEmpty) {
      return AttendanceSession.fromFirestore(myActive.docs.first);
    }

    // Check for active session for this site today (by anyone in same tenant)
    final siteActive = await col
        .where('siteId', isEqualTo: siteId)
        .where('date', isEqualTo: today)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (siteActive.docs.isNotEmpty) {
      throw SessionConflictException(
        AttendanceSession.fromFirestore(siteActive.docs.first),
      );
    }

    final docRef = col.doc();
    final session = AttendanceSession(
      id:             docRef.id,
      supervisorId:   uid,
      supervisorName: supervisorName,
      siteId:         siteId,
      siteName:       siteName,
      date:           today,
      contractorId:   contractorId,
      startedAt:      DateTime.now(),
      status:         SessionStatus.active,
    );
    await docRef.set(session.toFirestore());
    debugPrint('✅ Session started: ${docRef.id} → $siteName');
    return session;
  }

  // ── End a session ────────────────────────────────────────────────────────────
  Future<void> endSession(String sessionId, {int totalPresent = 0}) async {
    await _docRef(sessionId).update({
      'status':       'completed',
      'endedAt':      FieldValue.serverTimestamp(),
      'totalPresent': totalPresent,
    });
    debugPrint('✅ Session ended: $sessionId');
  }

  // ── Increment marked count atomically ────────────────────────────────────────
  Future<void> incrementMarkedCount(String sessionId) async {
    await _docRef(sessionId).update({
      'markedCount':  FieldValue.increment(1),
      'totalPresent': FieldValue.increment(1),
    });
  }

  // ── Get active session for current supervisor ────────────────────────────────
  Future<AttendanceSession?> getMyActiveSession() async {
    final uid = _uid;
    if (uid.isEmpty) return null;
    try {
      final snap = await _col
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

  // ── Stream active session for current supervisor ─────────────────────────────
  Stream<AttendanceSession?> streamMyActiveSession() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(null);
    return _col
        .where('supervisorId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : AttendanceSession.fromFirestore(snap.docs.first));
  }

  // ── Stream all sessions for today (for dashboard site cards) ─────────────────
  Stream<List<AttendanceSession>> streamSessionsForToday() {
    final today = _todayString();
    return _col
        .where('date', isEqualTo: today)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AttendanceSession.fromFirestore(d)).toList());
  }

  // ── Stream a single session by ID ────────────────────────────────────────────
  Stream<AttendanceSession?> streamSession(String sessionId) {
    return _docRef(sessionId).snapshots().map(
        (doc) => doc.exists ? AttendanceSession.fromFirestore(doc) : null);
  }

  // ── Abandon orphaned sessions on app start ───────────────────────────────────
  Future<void> abandonOldSessions() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final today = _todayString();
    try {
      final snap = await _col
          .where('supervisorId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = data['date'] as String? ?? '';
        if (date != today) {
          await doc.reference.update({'status': 'abandoned'});
          debugPrint('Abandoned stale session ${doc.id} from $date');
        }
      }
    } catch (e) {
      debugPrint('abandonOldSessions error: $e');
    }
  }
}

class SessionConflictException implements Exception {
  const SessionConflictException(this.existingSession);
  final AttendanceSession existingSession;
}
