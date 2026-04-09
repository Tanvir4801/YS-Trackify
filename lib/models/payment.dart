import 'package:hive/hive.dart';

class Payment {
  Payment({
    required this.id,
    required this.labourId,
    required this.amount,
    required this.date,
  });

  final String id;
  final String labourId;
  final double amount;
  final String date; // Format: yyyy-MM-dd

  Payment copyWith({
    String? id,
    String? labourId,
    double? amount,
    String? date,
  }) {
    return Payment(
      id: id ?? this.id,
      labourId: labourId ?? this.labourId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }
}

class PaymentAdapter extends TypeAdapter<Payment> {
  @override
  final int typeId = 4;

  @override
  Payment read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return Payment(
      id: fields[0] as String,
      labourId: fields[1] as String,
      amount: _asDouble(fields[2]),
      date: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Payment obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.labourId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date);
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
}
