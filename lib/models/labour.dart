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

  factory Labour.empty() => Labour(
        id: '',
        name: '',
        role: '',
        dailyWage: 0,
        phoneNumber: '',
      );

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

  bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    return false;
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
    writer.writeByte(9);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.role);
    writer.writeByte(3);
    writer.write(obj.dailyWage);
    writer.writeByte(4);
    writer.write(obj.phoneNumber);
    writer.writeByte(5);
    writer.write(obj.advanceAmount);
    writer.writeByte(6);
    writer.write(obj.extraHours);
    writer.writeByte(7);
    writer.write(obj.overtimeRate);
  }
}
