import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 32)
class SupplierModel extends HiveObject {
  SupplierModel({
    required this.id,
    required this.contractorId,
    required this.name,
    this.contactNumber = '',
    this.totalPurchases = 0,
    this.paidAmount = 0,
    this.createdAt,
  });

  static const String boxName = 'v2_suppliers';

  @HiveField(0)
  String id;

  @HiveField(1)
  String contractorId;

  @HiveField(2)
  String name;

  @HiveField(3)
  String contactNumber;

  @HiveField(4)
  double totalPurchases;

  @HiveField(5)
  double paidAmount;

  @HiveField(6)
  DateTime? createdAt;

  double get pendingAmount => totalPurchases - paidAmount;

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'contractorId': contractorId,
        'name': name,
        'contactNumber': contactNumber,
        'totalPurchases': totalPurchases,
        'paidAmount': paidAmount,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SupplierModel(
      id: (d['id'] as String?) ?? doc.id,
      contractorId: (d['contractorId'] as String?) ?? '',
      name: (d['name'] as String?) ?? '',
      contactNumber: (d['contactNumber'] as String?) ?? '',
      totalPurchases: (d['totalPurchases'] as num?)?.toDouble() ?? 0,
      paidAmount: (d['paidAmount'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SupplierModelAdapter extends TypeAdapter<SupplierModel> {
  @override
  final int typeId = 32;

  @override
  SupplierModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SupplierModel(
      id: fields[0] as String,
      contractorId: fields[1] as String,
      name: fields[2] as String,
      contactNumber: fields[3] as String,
      totalPurchases: (fields[4] as num).toDouble(),
      paidAmount: (fields[5] as num).toDouble(),
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.contractorId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.contactNumber)
      ..writeByte(4)
      ..write(obj.totalPurchases)
      ..writeByte(5)
      ..write(obj.paidAmount)
      ..writeByte(6)
      ..write(obj.createdAt);
  }
}
