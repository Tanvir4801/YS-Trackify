import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 33)
class SiteExpenseModel extends HiveObject {
  SiteExpenseModel({
    required this.id,
    required this.siteId,
    required this.contractorId,
    required this.expenseType,
    required this.amount,
    required this.date,
    this.description = '',
    this.billUrl = '',
    this.createdAt,
  });

  static const String boxName = 'v2_site_expenses';

  @HiveField(0)
  String id;

  @HiveField(1)
  String siteId;

  @HiveField(2)
  String contractorId;

  @HiveField(3)
  String expenseType; // machinery, transport, misc

  @HiveField(4)
  double amount;

  @HiveField(5)
  String date; // format: yyyy-MM-dd

  @HiveField(6)
  String description;

  @HiveField(7)
  String billUrl;

  @HiveField(8)
  DateTime? createdAt;

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'siteId': siteId,
        'contractorId': contractorId,
        'expenseType': expenseType,
        'amount': amount,
        'date': date,
        'description': description,
        'billUrl': billUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory SiteExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SiteExpenseModel(
      id: (d['id'] as String?) ?? doc.id,
      siteId: (d['siteId'] as String?) ?? '',
      contractorId: (d['contractorId'] as String?) ?? '',
      expenseType: (d['expenseType'] as String?) ?? 'misc',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      date: (d['date'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      billUrl: (d['billUrl'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SiteExpenseModelAdapter extends TypeAdapter<SiteExpenseModel> {
  @override
  final int typeId = 33;

  @override
  SiteExpenseModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SiteExpenseModel(
      id: fields[0] as String,
      siteId: fields[1] as String,
      contractorId: fields[2] as String,
      expenseType: fields[3] as String,
      amount: (fields[4] as num).toDouble(),
      date: fields[5] as String,
      description: fields[6] as String,
      billUrl: fields[7] as String,
      createdAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SiteExpenseModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.siteId)
      ..writeByte(2)
      ..write(obj.contractorId)
      ..writeByte(3)
      ..write(obj.expenseType)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.billUrl)
      ..writeByte(8)
      ..write(obj.createdAt);
  }
}
