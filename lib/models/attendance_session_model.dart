import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { active, completed, abandoned }

extension SessionStatusX on SessionStatus {
  String get value {
    switch (this) {
      case SessionStatus.active:    return 'active';
      case SessionStatus.completed: return 'completed';
      case SessionStatus.abandoned: return 'abandoned';
    }
  }

  static SessionStatus fromString(String? v) {
    switch (v) {
      case 'completed': return SessionStatus.completed;
      case 'abandoned': return SessionStatus.abandoned;
      default:          return SessionStatus.active;
    }
  }
}

class AttendanceSession {
  AttendanceSession({
    required this.id,
    required this.supervisorId,
    required this.supervisorName,
    required this.siteId,
    required this.siteName,
    required this.date,
    required this.contractorId,
    required this.startedAt,
    this.endedAt,
    this.status = SessionStatus.active,
    this.markedCount = 0,
    this.totalPresent = 0,
    this.allowancesApplied = false,
  });

  final String id;
  final String supervisorId;
  final String supervisorName;
  final String siteId;
  final String siteName;
  final String date;
  final String contractorId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SessionStatus status;
  final int markedCount;
  final int totalPresent;
  final bool allowancesApplied;

  bool get isActive    => status == SessionStatus.active;
  bool get isCompleted => status == SessionStatus.completed;

  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime startedAt = DateTime.now();
    if (d['startedAt'] is Timestamp) {
      startedAt = (d['startedAt'] as Timestamp).toDate();
    }
    DateTime? endedAt;
    if (d['endedAt'] is Timestamp) {
      endedAt = (d['endedAt'] as Timestamp).toDate();
    }
    return AttendanceSession(
      id:                 doc.id,
      supervisorId:       (d['supervisorId']   as String?) ?? '',
      supervisorName:     (d['supervisorName'] as String?) ?? '',
      siteId:             (d['siteId']         as String?) ?? '',
      siteName:           (d['siteName']       as String?) ?? '',
      date:               (d['date']           as String?) ?? '',
      contractorId:       (d['contractorId']   as String?) ?? '',
      startedAt:          startedAt,
      endedAt:            endedAt,
      status:             SessionStatusX.fromString(d['status'] as String?),
      markedCount:        (d['markedCount']        as num?)?.toInt() ?? 0,
      totalPresent:       (d['totalPresent']       as num?)?.toInt() ?? 0,
      allowancesApplied:  (d['allowancesApplied']  as bool?) ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'supervisorId':      supervisorId,
    'supervisorName':    supervisorName,
    'siteId':            siteId,
    'siteName':          siteName,
    'date':              date,
    'contractorId':      contractorId,
    'startedAt':         FieldValue.serverTimestamp(),
    'endedAt':           null,
    'status':            status.value,
    'markedCount':       markedCount,
    'totalPresent':      totalPresent,
    'allowancesApplied': allowancesApplied,
  };
}
