import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { active, completed, abandoned }

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.supervisorId,
    this.supervisorName = '',
    required this.siteId,
    required this.siteName,
    required this.date,
    required this.contractorId,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.markedCount = 0,
    this.totalPresent = 0,
    this.totalAbsent = 0,
    this.totalHalf = 0,
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
  final int totalAbsent;
  final int totalHalf;
  final bool allowancesApplied;

  bool get isActive    => status == SessionStatus.active;
  bool get isCompleted => status == SessionStatus.completed;

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceSession(
      id:               doc.id,
      supervisorId:     d['supervisorId']     as String?  ?? '',
      supervisorName:   d['supervisorName']   as String?  ?? '',
      siteId:           d['siteId']           as String?  ?? '',
      siteName:         d['siteName']         as String?  ?? '',
      date:             d['date']             as String?  ?? '',
      contractorId:     d['contractorId']     as String?  ?? '',
      startedAt:        (d['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt:          (d['endedAt']   as Timestamp?)?.toDate(),
      status:           _parseStatus(d['status'] as String?),
      markedCount:      (d['markedCount']      as int?) ?? 0,
      totalPresent:     (d['totalPresent']     as int?) ?? 0,
      totalAbsent:      (d['totalAbsent']      as int?) ?? 0,
      totalHalf:        (d['totalHalf']        as int?) ?? 0,
      allowancesApplied:(d['allowancesApplied'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'supervisorId':      supervisorId,
    'supervisorName':    supervisorName,
    'siteId':            siteId,
    'siteName':          siteName,
    'date':              date,
    'contractorId':      contractorId,
    'startedAt':         Timestamp.fromDate(startedAt),
    'endedAt':           endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    'status':            status.name,
    'markedCount':       markedCount,
    'totalPresent':      totalPresent,
    'totalAbsent':       totalAbsent,
    'totalHalf':         totalHalf,
    'allowancesApplied': allowancesApplied,
  };

  AttendanceSession copyWith({
    SessionStatus? status,
    int? markedCount,
    int? totalPresent,
    int? totalAbsent,
    int? totalHalf,
    bool? allowancesApplied,
    DateTime? endedAt,
  }) => AttendanceSession(
    id:               id,
    supervisorId:     supervisorId,
    supervisorName:   supervisorName,
    siteId:           siteId,
    siteName:         siteName,
    date:             date,
    contractorId:     contractorId,
    startedAt:        startedAt,
    endedAt:          endedAt          ?? this.endedAt,
    status:           status           ?? this.status,
    markedCount:      markedCount      ?? this.markedCount,
    totalPresent:     totalPresent     ?? this.totalPresent,
    totalAbsent:      totalAbsent      ?? this.totalAbsent,
    totalHalf:        totalHalf        ?? this.totalHalf,
    allowancesApplied:allowancesApplied ?? this.allowancesApplied,
  );

  static SessionStatus _parseStatus(String? s) {
    switch (s) {
      case 'completed':  return SessionStatus.completed;
      case 'abandoned':  return SessionStatus.abandoned;
      default:           return SessionStatus.active;
    }
  }
}
