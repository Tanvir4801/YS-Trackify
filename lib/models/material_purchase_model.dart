import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 31)
class MaterialPurchaseModel extends HiveObject {
  MaterialPurchaseModel({
    required this.id,
    required this.siteId,
    required this.contractorId,
    required this.materialName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.supplierId,
    required this.supplierName,
    this.invoiceNumber = '',
    required this.purchaseDate,
    this.billUrl = '',
    this.remarks = '',
    this.createdAt,
  });

  static const String boxName = 'v2_material_purchases';

  @HiveField(0)
  String id;

  @HiveField(1)
  String siteId;

  @HiveField(2)
  String contractorId;

  @HiveField(3)
  String materialName;

  @HiveField(4)
  String category;

  @HiveField(5)
  double quantity;

  @HiveField(6)
  String unit;

  @HiveField(7)
  double pricePerUnit;

  @HiveField(8)
  double totalAmount;

  @HiveField(9)
  String supplierId;

  @HiveField(10)
  String supplierName;

  @HiveField(11)
  String invoiceNumber;

  @HiveField(12)
  String purchaseDate; // format: yyyy-MM-dd

  @HiveField(13)
  String billUrl;

  @HiveField(14)
  String remarks;

  @HiveField(15)
  DateTime? createdAt;

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'siteId': siteId,
        'contractorId': contractorId,
        'materialName': materialName,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalAmount': totalAmount,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'invoiceNumber': invoiceNumber,
        'purchaseDate': purchaseDate,
        'billUrl': billUrl,
        'remarks': remarks,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory MaterialPurchaseModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MaterialPurchaseModel(
      id: (d['id'] as String?) ?? doc.id,
      siteId: (d['siteId'] as String?) ?? '',
      contractorId: (d['contractorId'] as String?) ?? '',
      materialName: (d['materialName'] as String?) ?? '',
      category: (d['category'] as String?) ?? '',
      quantity: (d['quantity'] as num?)?.toDouble() ?? 0,
      unit: (d['unit'] as String?) ?? '',
      pricePerUnit: (d['pricePerUnit'] as num?)?.toDouble() ?? 0,
      totalAmount: (d['totalAmount'] as num?)?.toDouble() ?? 0,
      supplierId: (d['supplierId'] as String?) ?? '',
      supplierName: (d['supplierName'] as String?) ?? '',
      invoiceNumber: (d['invoiceNumber'] as String?) ?? '',
      purchaseDate: (d['purchaseDate'] as String?) ?? '',
      billUrl: (d['billUrl'] as String?) ?? '',
      remarks: (d['remarks'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class MaterialPurchaseModelAdapter extends TypeAdapter<MaterialPurchaseModel> {
  @override
  final int typeId = 31;

  @override
  MaterialPurchaseModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return MaterialPurchaseModel(
      id: fields[0] as String,
      siteId: fields[1] as String,
      contractorId: fields[2] as String,
      materialName: fields[3] as String,
      category: fields[4] as String,
      quantity: (fields[5] as num).toDouble(),
      unit: fields[6] as String,
      pricePerUnit: (fields[7] as num).toDouble(),
      totalAmount: (fields[8] as num).toDouble(),
      supplierId: fields[9] as String,
      supplierName: fields[10] as String,
      invoiceNumber: fields[11] as String,
      purchaseDate: fields[12] as String,
      billUrl: fields[13] as String,
      remarks: fields[14] as String,
      createdAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MaterialPurchaseModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.siteId)
      ..writeByte(2)
      ..write(obj.contractorId)
      ..writeByte(3)
      ..write(obj.materialName)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.unit)
      ..writeByte(7)
      ..write(obj.pricePerUnit)
      ..writeByte(8)
      ..write(obj.totalAmount)
      ..writeByte(9)
      ..write(obj.supplierId)
      ..writeByte(10)
      ..write(obj.supplierName)
      ..writeByte(11)
      ..write(obj.invoiceNumber)
      ..writeByte(12)
      ..write(obj.purchaseDate)
      ..writeByte(13)
      ..write(obj.billUrl)
      ..writeByte(14)
      ..write(obj.remarks)
      ..writeByte(15)
      ..write(obj.createdAt);
  }
}
