import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Firestore path helpers for the layered data model.
///
/// New attendance structure (preferred for all writes):
///   attendance/{contractorId}/dates/{dateKey}/records/{labourId}
///
/// Legacy flat structure (kept for backward compatibility):
///   attendance/{autoId}  with fields supervisorId, labourId, date, status
class FirestorePaths {
  FirestorePaths._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String todayKey() => dateKey(DateTime.now());

  static DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _db.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> attendanceContractorRoot() =>
      _db.collection('attendance');

  static DocumentReference<Map<String, dynamic>> attendanceContractorDoc(
    String contractorId,
  ) =>
      _db.collection('attendance').doc(contractorId);

  static DocumentReference<Map<String, dynamic>> attendanceDateDoc(
    String contractorId,
    String dateKey,
  ) =>
      attendanceContractorDoc(contractorId).collection('dates').doc(dateKey);

  static CollectionReference<Map<String, dynamic>> attendanceRecordsCol(
    String contractorId,
    String dateKey,
  ) =>
      attendanceDateDoc(contractorId, dateKey).collection('records');

  static DocumentReference<Map<String, dynamic>> attendanceRecordRef(
    String contractorId,
    String dateKey,
    String labourId,
  ) =>
      attendanceRecordsCol(contractorId, dateKey).doc(labourId);
}
