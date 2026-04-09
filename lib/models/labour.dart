import 'package:hive/hive.dart';

class Labour {
  Labour({
    required this.id,
    required this.name,
    required this.role,
    required this.dailyWage,
    required this.phoneNumber,
    this.advanceAmount = 0,
    this.extraHours = 0,
    this.overtimeRate = 0,
  });

  final String id;
  final String name;
  final String role;
  final double dailyWage;
  final String phoneNumber;
  final double advanceAmount;
  final double extraHours;
  final double overtimeRate;

  double get overtimePay => extraHours * overtimeRate;

  Labour copyWith({
    String? id,
    String? name,
    String? role,
    double? dailyWage,
    String? phoneNumber,
    double? advanceAmount,
    double? extraHours,
    double? overtimeRate,
  }) {
    return Labour(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      dailyWage: dailyWage ?? this.dailyWage,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      extraHours: extraHours ?? this.extraHours,
      overtimeRate: overtimeRate ?? this.overtimeRate,
    );
  }
}

class LabourAdapter extends TypeAdapter<Labour> {
  @override
  final int typeId = 0;

  @override
  Labour read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return Labour(
      id: _asString(fields[0]),
      name: _asString(fields[1]),
      role: _asString(fields[2]),
      dailyWage: _asDouble(fields[3]),
      phoneNumber: _asString(fields[4]),
      advanceAmount: _asDouble(fields[5]),
      extraHours: _asDouble(fields[6]),
      overtimeRate: _asDouble(fields[7]),
    );
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  double _asDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  @override
  void write(BinaryWriter writer, Labour obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.dailyWage)
      ..writeByte(4)
      ..write(obj.phoneNumber)
      ..writeByte(5)
      ..write(obj.advanceAmount)
      ..writeByte(6)
      ..write(obj.extraHours)
      ..writeByte(7)
      ..write(obj.overtimeRate);
  }
}
