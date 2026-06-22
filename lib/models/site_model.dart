import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 30)
class SiteModel extends HiveObject {
  SiteModel({
    required this.id,
    required this.name,
    required this.contractorId,
    this.description = '',
    this.isActive = true,
    this.createdAt,
    this.firestoreId,
    this.defaultPetrol = 0,
    this.defaultLunch = 0,
    this.defaultBreakfast = 0,
    this.defaultTea = 0,
  });

  static const String boxName = 'v2_sites';

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String contractorId;

  @HiveField(3)
  String description;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  DateTime? createdAt;

  @HiveField(6)
  String? firestoreId;

  @HiveField(7)
  double defaultPetrol;

  @HiveField(8)
  double defaultLunch;

  @HiveField(9)
  double defaultBreakfast;

  @HiveField(10)
  double defaultTea;

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'contractorId': contractorId,
        'description': description,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'defaultAllowances': {
          'petrol': defaultPetrol,
          'lunch': defaultLunch,
          'breakfast': defaultBreakfast,
          'tea': defaultTea,
        },
      };

  factory SiteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final da = (d['defaultAllowances'] as Map<String, dynamic>?) ?? {};
    return SiteModel(
      id: (d['id'] as String?) ?? doc.id,
      name: (d['name'] as String?) ?? '',
      contractorId: (d['contractorId'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      firestoreId: doc.id,
      defaultPetrol:    (da['petrol']    as num?)?.toDouble() ?? 0,
      defaultLunch:     (da['lunch']     as num?)?.toDouble() ?? 0,
      defaultBreakfast: (da['breakfast'] as num?)?.toDouble() ?? 0,
      defaultTea:       (da['tea']       as num?)?.toDouble() ?? 0,
    );
  }

  SiteModel copyWith({
    String? id,
    String? name,
    String? contractorId,
    String? description,
    bool? isActive,
    double? defaultPetrol,
    double? defaultLunch,
    double? defaultBreakfast,
    double? defaultTea,
  }) =>
      SiteModel(
        id: id ?? this.id,
        name: name ?? this.name,
        contractorId: contractorId ?? this.contractorId,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        firestoreId: firestoreId,
        defaultPetrol:    defaultPetrol    ?? this.defaultPetrol,
        defaultLunch:     defaultLunch     ?? this.defaultLunch,
        defaultBreakfast: defaultBreakfast ?? this.defaultBreakfast,
        defaultTea:       defaultTea       ?? this.defaultTea,
      );
}

class SiteModelAdapter extends TypeAdapter<SiteModel> {
  @override
  final int typeId = 30;

  @override
  SiteModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SiteModel(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      contractorId: fields[2] as String? ?? '',
      description: fields[3] as String? ?? '',
      isActive: fields[4] as bool? ?? true,
      createdAt: fields[5] as DateTime?,
      firestoreId: fields[6] as String?,
      defaultPetrol:    (fields[7]  as num?)?.toDouble() ?? 0,
      defaultLunch:     (fields[8]  as num?)?.toDouble() ?? 0,
      defaultBreakfast: (fields[9]  as num?)?.toDouble() ?? 0,
      defaultTea:       (fields[10] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, SiteModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.contractorId)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.firestoreId)
      ..writeByte(7)
      ..write(obj.defaultPetrol)
      ..writeByte(8)
      ..write(obj.defaultLunch)
      ..writeByte(9)
      ..write(obj.defaultBreakfast)
      ..writeByte(10)
      ..write(obj.defaultTea);
  }
}
