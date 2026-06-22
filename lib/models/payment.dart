import 'package:cloud_firestore/cloud_firestore.dart';
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
      id: _asString(fields[0]),
      labourId: _asString(fields[1]),
      amount: _asDouble(fields[2]),
      date: _asDateKey(fields[3]),
    );
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  String _asDateKey(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }
    return value.toString();
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
