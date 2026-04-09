import 'package:hive/hive.dart';

enum AttendanceStatus {
  present,
  absent,
  halfDay,
}

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half-Day';
    }
  }

  double get factor {
    switch (this) {
      case AttendanceStatus.present:
        return 1;
      case AttendanceStatus.absent:
        return 0;
      case AttendanceStatus.halfDay:
        return 0.5;
    }
  }
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.labourId,
    required this.dateKey,
    required this.status,
  });

  final String id;
  final String labourId;
  final String dateKey;
  final AttendanceStatus status;

  AttendanceRecord copyWith({
    String? id,
    String? labourId,
    String? dateKey,
    AttendanceStatus? status,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      labourId: labourId ?? this.labourId,
      dateKey: dateKey ?? this.dateKey,
      status: status ?? this.status,
    );
  }
}

class AttendanceStatusAdapter extends TypeAdapter<AttendanceStatus> {
  @override
  final int typeId = 1;

  @override
  AttendanceStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttendanceStatus.present;
      case 1:
        return AttendanceStatus.absent;
      case 2:
        return AttendanceStatus.halfDay;
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
      case AttendanceStatus.halfDay:
        writer.writeByte(2);
        break;
    }
  }
}

class AttendanceRecordAdapter extends TypeAdapter<AttendanceRecord> {
  @override
  final int typeId = 2;

  @override
  AttendanceRecord read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return AttendanceRecord(
      id: fields[0] as String,
      labourId: fields[1] as String,
      dateKey: fields[2] as String,
      status: fields[3] as AttendanceStatus,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.labourId)
      ..writeByte(2)
      ..write(obj.dateKey)
      ..writeByte(3)
      ..write(obj.status);
  }
}
