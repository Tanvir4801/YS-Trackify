import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/attendance_session.dart';
import '../services/sessions_service.dart';

class SessionsProvider extends ChangeNotifier {
  SessionsProvider({SessionsService? service})
      : _service = service ?? SessionsService();

  final SessionsService _service;

  List<AttendanceSession> _sessions = [];
  StreamSubscription<List<AttendanceSession>>? _sub;
  bool isLoading = false;
  String? error;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _uid    => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<AttendanceSession> get sessions => _sessions;

  AttendanceSession? get myActiveSession {
    return _sessions.where(
      (s) => s.isActive && s.supervisorId == _uid,
    ).firstOrNull;
  }

  AttendanceSession? sessionForSite(String siteId) {
    // Return the most recent session for this site today (active first)
    final matches = _sessions.where((s) => s.siteId == siteId).toList()
      ..sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        return b.startedAt.compareTo(a.startedAt);
      });
    return matches.firstOrNull;
  }

  void startListening() {
    _sub?.cancel();
    isLoading = true;
    notifyListeners();

    _sub = _service.sessionsForDate(_today).listen(
      (list) {
        _sessions = list;
        isLoading = false;
        error = null;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<AttendanceSession> startSession({
    required String siteId,
    required String siteName,
  }) async {
    final session = await _service.startSession(
      siteId:   siteId,
      siteName: siteName,
    );
    // Optimistically add to local list
    _sessions = [..._sessions, session];
    notifyListeners();
    return session;
  }

  Future<void> endSession(
    String sessionId, {
    required int totalPresent,
    required int totalAbsent,
    required int totalHalf,
    required bool allowancesApplied,
  }) async {
    await _service.endSession(
      sessionId,
      totalPresent:      totalPresent,
      totalAbsent:       totalAbsent,
      totalHalf:         totalHalf,
      allowancesApplied: allowancesApplied,
    );
  }

  Future<void> abandonSession(String sessionId) async {
    await _service.abandonSession(sessionId);
  }

  Future<void> checkForOrphanedSession() async {
    final active = await _service.getMyActiveSession();
    if (active != null && !_sessions.any((s) => s.id == active.id)) {
      _sessions = [..._sessions, active];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
