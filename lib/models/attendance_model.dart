import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 21)
enum AttendanceStatus {
  @HiveField(0)
  present,
  @HiveField(1)
  absent,
  @HiveField(2)
  half,
}

extension AttendanceStatusX on AttendanceStatus {
  double get wageFactor {
    switch (this) {
      case AttendanceStatus.present:
        return 1.0;
      case AttendanceStatus.absent:
        return 0.0;
      case AttendanceStatus.half:
        return 0.5;
    }
  }

  String get firestoreValue {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.half:
        return 'half';
    }
  }

  static AttendanceStatus fromFirestoreValue(String? value) {
    switch (value) {
      case 'present':
        return AttendanceStatus.present;
      case 'half':
        return AttendanceStatus.half;
      case 'absent':
      default:
        return AttendanceStatus.absent;
    }
  }
}

@HiveType(typeId: 22)
class Attendance extends HiveObject {
  Attendance({
    required this.id,
    required this.labourId,
    required this.supervisorId,
    this.contractorId = '',
    required this.date,
    required this.status,
    this.overtimeHours = 0,
    this.notes = '',
    this.syncedAt,
    this.isSynced = false,
    this.firestoreId,
    this.lastSyncedAt,
  });

  static const String boxName = 'v2_attendance';

  @HiveField(0)
  String id;

  @HiveField(1)
  String labourId;

  @HiveField(2)
  String supervisorId;

  @HiveField(3)
  String contractorId;

  @HiveField(4)
  String date;

  @HiveField(5)
  AttendanceStatus status;

  @HiveField(6)
  double overtimeHours;

  @HiveField(7)
  String notes;

  @HiveField(8)
  DateTime? syncedAt;

  @HiveField(9)
  bool isSynced;

  @HiveField(10)
  String? firestoreId;

  @HiveField(11)
  DateTime? lastSyncedAt;

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'labourId': labourId,
        'supervisorId': supervisorId,
        'contractorId': contractorId,
        'date': date,
        'status': status.firestoreValue,
        'overtimeHours': overtimeHours,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      };

  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return Attendance(
      id: (d['id'] as String?) ?? doc.id,
      labourId: (d['labourId'] as String?) ?? '',
      supervisorId: (d['supervisorId'] as String?) ?? '',
      contractorId:
          (d['contractorId'] as String?) ?? (d['supervisorId'] as String?) ?? '',
      date: _readDateValue(d['date']),
      status: AttendanceStatusX.fromFirestoreValue(d['status'] as String?),
      overtimeHours: (d['overtimeHours'] as num?)?.toDouble() ?? 0,
      notes: (d['notes'] as String?) ?? '',
      syncedAt: _readTimestamp(d['syncedAt']),
      isSynced: (d['isSynced'] as bool?) ?? true,
    )
      ..firestoreId = doc.id
      ..isSynced = true
      ..lastSyncedAt = _readTimestamp(d['syncedAt']);
  }

  Attendance copyWith({
    String? id,
    String? labourId,
    String? supervisorId,
    String? contractorId,
    String? date,
    AttendanceStatus? status,
    double? overtimeHours,
    String? notes,
    DateTime? syncedAt,
    bool? isSynced,
    String? firestoreId,
    DateTime? lastSyncedAt,
  }) {
    return Attendance(
      id: id ?? this.id,
      labourId: labourId ?? this.labourId,
      supervisorId: supervisorId ?? this.supervisorId,
      contractorId: contractorId ?? this.contractorId,
      date: date ?? this.date,
      status: status ?? this.status,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      notes: notes ?? this.notes,
      syncedAt: syncedAt ?? this.syncedAt,
      isSynced: isSynced ?? this.isSynced,
      firestoreId: firestoreId ?? this.firestoreId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  static String _readDateValue(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    if (value is Timestamp) {
      return formatDate(value.toDate());
    }
    if (value is DateTime) {
      return formatDate(value);
    }
    return '';
  }

  static DateTime? _readTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static Future<Box<Attendance>> openBoxSafely() async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<Attendance>(boxName);
      }
      return await Hive.openBox<Attendance>(boxName);
    } on HiveError catch (error) {
      debugPrint('Attendance box migration reset: $error');
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<Attendance>(boxName).close();
      }
      if (await Hive.boxExists(boxName)) {
        await Hive.deleteBoxFromDisk(boxName);
      }
      return Hive.openBox<Attendance>(boxName);
    }
  }
}

class AttendanceStatusAdapter extends TypeAdapter<AttendanceStatus> {
  @override
  final int typeId = 21;

  @override
  AttendanceStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttendanceStatus.present;
      case 1:
        return AttendanceStatus.absent;
      case 2:
        return AttendanceStatus.half;
      default:
        return AttendanceStatus.absent;
    }
  }

  @override
  void write(BinaryWriter writer, AttendanceStatus obj) {
    switch (obj) {
      case AttendanceStatus.present:
        writer.writeByte(0);
        break;
      case AttendanceStatus.absent:
        writer.writeByte(1);
        break;
      case AttendanceStatus.half:
        writer.writeByte(2);
        break;
    }
  }
}

class AttendanceAdapter extends TypeAdapter<Attendance> {
  @override
  final int typeId = 22;

  @override
  Attendance read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    final hasContractorIdField = fields.containsKey(11);

    if (!hasContractorIdField) {
      return Attendance(
        id: fields[0] as String,
        labourId: fields[1] as String,
        supervisorId: fields[2] as String,
        contractorId: '',
        date: fields[3] as String? ?? '',
        status: fields[4] as AttendanceStatus? ?? AttendanceStatus.absent,
        overtimeHours: (fields[5] as num?)?.toDouble() ?? 0,
        notes: fields[6] as String? ?? '',
        syncedAt: fields[7] as DateTime?,
        isSynced: fields[8] as bool? ?? false,
        firestoreId: fields[9] as String?,
        lastSyncedAt: fields[10] as DateTime?,
      );
    }

    return Attendance(
      id: fields[0] as String,
      labourId: fields[1] as String,
      supervisorId: fields[2] as String,
      contractorId: fields[3] as String? ?? '',
      date: fields[4] as String? ?? '',
      status: fields[5] as AttendanceStatus? ?? AttendanceStatus.absent,
      overtimeHours: (fields[6] as num?)?.toDouble() ?? 0,
      notes: fields[7] as String? ?? '',
      syncedAt: fields[8] as DateTime?,
      isSynced: fields[9] as bool? ?? false,
      firestoreId: fields[10] as String?,
      lastSyncedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Attendance obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.labourId)
      ..writeByte(2)
      ..write(obj.supervisorId)
      ..writeByte(3)
      ..write(obj.contractorId)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.overtimeHours)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.syncedAt)
      ..writeByte(9)
      ..write(obj.isSynced)
      ..writeByte(10)
      ..write(obj.firestoreId)
      ..writeByte(11)
      ..write(obj.lastSyncedAt);
  }
}
