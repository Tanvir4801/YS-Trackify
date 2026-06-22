import '../models/app_user.dart';

/// Process-wide cache of the currently authenticated [AppUser].
///
/// Populated by [AuthService] on successful login / role fetch and cleared on
/// logout. Services that need synchronous access to `contractorId` /
/// `supervisorRef` (e.g. AttendanceService, LabourService, ScannerService) can
/// read it directly from here instead of round-tripping to Firestore.
class SessionService {
  SessionService._internal();
  static final SessionService instance = SessionService._internal();

  AppUser? _current;

  AppUser? get current => _current;

  String? get contractorId => _current?.contractorId;
  String? get supervisorId => _current?.supervisorId;
  String? get role => _current?.role;
  String? get labourId => _current?.labourId;
  String? get name => _current?.name;
  String? get uid => _current?.uid;

  bool get isLoggedIn => _current != null && (_current!.uid.isNotEmpty);

  void set(AppUser user) {
    _current = user;
    debugLog('SessionService updated: ${user.uid} / ${user.contractorId} / ${user.role}');
  }

  /// Convenience method to update session fields directly without an AppUser object.
  void setSession({
    required String uid,
    required String contractorId,
    required String role,
    required String name,
  }) {
    // If we already have an AppUser, update it; otherwise build a minimal one.
    if (_current != null) {
      _current = _current!.copyWith(
        uid: uid,
        contractorId: contractorId,
        role: role,
        name: name,
      );
    } else {
      _current = AppUser(
        uid: uid,
        role: role,
        contractorId: contractorId,
        name: name,
      );
    }
    debugLog('SessionService.setSession: uid=$uid contractorId=$contractorId role=$role');
  }

  void clear() {
    _current = null;
  }

  void debugLog(String msg) {
    // ignore: avoid_print
    print('[SessionService] $msg');
  }
}
