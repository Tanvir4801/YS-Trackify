import 'package:hive/hive.dart';

class AdvanceTransaction {
  AdvanceTransaction({
    required this.id,
    required this.labourId,
    required this.amount,
    required this.date,
  });

  final String id;
  final String labourId;
  final double amount;
  final String date; // format: yyyy-MM-dd

  AdvanceTransaction copyWith({
    String? id,
    String? labourId,
    double? amount,
    String? date,
  }) {
    return AdvanceTransaction(
      id: id ?? this.id,
      labourId: labourId ?? this.labourId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }
}

class AdvanceTransactionAdapter extends TypeAdapter<AdvanceTransaction> {
  @override
  final int typeId = 3;

  @override
  AdvanceTransaction read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return AdvanceTransaction(
      id: _asString(fields[0]),
      labourId: _asString(fields[1]),
      amount: _asDouble(fields[2]),
      date: _asString(fields[3]),
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
  void write(BinaryWriter writer, AdvanceTransaction obj) {
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
}
