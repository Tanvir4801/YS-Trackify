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

  void set(AppUser user) {
    _current = user;
  }

  void clear() {
    _current = null;
  }
}
