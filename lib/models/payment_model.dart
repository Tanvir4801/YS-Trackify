import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@HiveType(typeId: 23)
enum PaymentType {
  @HiveField(0)
  salary,
  @HiveField(1)
  advance,
  @HiveField(2)
  overtimeBonus,
}

extension PaymentTypeX on PaymentType {
  String get firestoreValue {
    switch (this) {
      case PaymentType.salary:
        return 'salary';
      case PaymentType.advance:
        return 'advance';
      case PaymentType.overtimeBonus:
        return 'overtime_bonus';
    }
  }

  static PaymentType fromFirestoreValue(String? value) {
    switch (value) {
      case 'salary':
        return PaymentType.salary;
      case 'overtime_bonus':
        return PaymentType.overtimeBonus;
      case 'advance':
      default:
        return PaymentType.advance;
    }
  }
}

@HiveType(typeId: 24)
class Payment extends HiveObject {
  Payment({
    required this.id,
    required this.labourId,
    required this.supervisorId,
    required this.type,
    required this.amount,
    required this.date,
    this.notes = '',
    this.isSynced = false,
    this.syncedAt,
    this.firestoreId,
    this.lastSyncedAt,
  });

  static const String boxName = 'v2_payments';

  @HiveField(0)
  String id;

  @HiveField(1)
  String labourId;

  @HiveField(2)
  String supervisorId;

  @HiveField(3)
  PaymentType type;

  @HiveField(4)
  double amount;

  @HiveField(5)
  DateTime date;

  @HiveField(6)
  String notes;

  @HiveField(7)
  bool isSynced;

  @HiveField(8)
  DateTime? syncedAt;

  @HiveField(9)
  String? firestoreId;

  @HiveField(10)
  DateTime? lastSyncedAt;

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'labourId': labourId,
        'supervisorId': supervisorId,
        'type': type.firestoreValue,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'notes': notes,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      };

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Payment(
      id: (d['id'] as String?) ?? doc.id,
      labourId: (d['labourId'] as String?) ?? '',
      supervisorId: (d['supervisorId'] as String?) ?? '',
      type: PaymentTypeX.fromFirestoreValue(d['type'] as String?),
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: (d['notes'] as String?) ?? '',
      isSynced: (d['isSynced'] as bool?) ?? true,
      syncedAt: (d['syncedAt'] as Timestamp?)?.toDate(),
      firestoreId: doc.id,
      lastSyncedAt: (d['syncedAt'] as Timestamp?)?.toDate(),
    );
  }

  Payment copyWith({
    String? id,
    String? labourId,
    String? supervisorId,
    PaymentType? type,
    double? amount,
    DateTime? date,
    String? notes,
    bool? isSynced,
    DateTime? syncedAt,
    String? firestoreId,
    DateTime? lastSyncedAt,
  }) {
    return Payment(
      id: id ?? this.id,
      labourId: labourId ?? this.labourId,
      supervisorId: supervisorId ?? this.supervisorId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      firestoreId: firestoreId ?? this.firestoreId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class PaymentTypeAdapter extends TypeAdapter<PaymentType> {
  @override
  final int typeId = 23;

  @override
  PaymentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentType.salary;
      case 1:
        return PaymentType.advance;
      case 2:
        return PaymentType.overtimeBonus;
      default:
        return PaymentType.advance;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentType obj) {
    switch (obj) {
      case PaymentType.salary:
        writer.writeByte(0);
        break;
      case PaymentType.advance:
        writer.writeByte(1);
        break;
      case PaymentType.overtimeBonus:
        writer.writeByte(2);
        break;
    }
  }
}

class PaymentAdapter extends TypeAdapter<Payment> {
  @override
  final int typeId = 24;

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
      supervisorId: fields[2] as String,
      type: fields[3] as PaymentType,
      amount: (fields[4] as num).toDouble(),
      date: fields[5] as DateTime,
      notes: fields[6] as String? ?? '',
      isSynced: fields[7] as bool? ?? false,
      syncedAt: fields[8] as DateTime?,
      firestoreId: fields[9] as String?,
      lastSyncedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Payment obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.labourId)
      ..writeByte(2)
      ..write(obj.supervisorId)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.syncedAt)
      ..writeByte(9)
      ..write(obj.firestoreId)
      ..writeByte(10)
      ..write(obj.lastSyncedAt);
  }
}
