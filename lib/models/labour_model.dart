import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum LabourType { regular, temporary }

@HiveType(typeId: 20)
class Labour extends HiveObject {
  Labour({
    required this.id,
    required this.supervisorId,
    required this.name,
    required this.phone,
    required this.dailyWage,
    required this.joiningDate,
    this.isActive = true,
    this.syncedAt,
    this.firestoreId,
    this.isSynced = false,
    this.lastSyncedAt,
    this.overtimeWagePerHour = 0,
    this.defaultOvertimeHours = 0,
    this.contractorId = '',
    this.type = LabourType.regular,
    this.siteId = '',
  });

  static const String boxName = 'v2_labours';

  @HiveField(0)
  String id;

  @HiveField(1)
  String supervisorId;

  @HiveField(2)
  String name;

  @HiveField(3)
  String phone;

  @HiveField(4)
  double dailyWage;

  @HiveField(5)
  DateTime joiningDate;

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  DateTime? syncedAt;

  @HiveField(8)
  bool isSynced;

  @HiveField(9)
  String? firestoreId;

  @HiveField(10)
  DateTime? lastSyncedAt;

  @HiveField(11)
  double overtimeWagePerHour;

  @HiveField(12)
  double defaultOvertimeHours;

  @HiveField(13)
  String contractorId;

  @HiveField(14)
  LabourType type;

  @HiveField(15)
  String siteId;

  bool get isTemporary => type == LabourType.temporary;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'supervisorId': supervisorId,
      'contractorId': contractorId,
      'name': name,
      'phone': phone,
      'dailyWage': dailyWage,
      'overtimeWagePerHour': overtimeWagePerHour,
      'defaultOvertimeHours': defaultOvertimeHours,
      'joiningDate': Timestamp.fromDate(joiningDate),
      'isActive': isActive,
      'type': type == LabourType.temporary ? 'temporary' : 'regular',
      'siteId': siteId,
      'isSynced': true,
      'syncedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Labour.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final typeStr = (data['type'] as String?) ?? 'regular';
    return Labour(
      id: (data['id'] as String?) ?? doc.id,
      supervisorId: (data['supervisorId'] as String?) ?? '',
      contractorId: (data['contractorId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      dailyWage: ((data['dailyWage'] as num?) ?? 0).toDouble(),
      overtimeWagePerHour:
          ((data['overtimeWagePerHour'] as num?) ?? 0).toDouble(),
      defaultOvertimeHours:
          ((data['defaultOvertimeHours'] as num?) ?? 0).toDouble(),
      joiningDate: (data['joiningDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: (data['isActive'] as bool?) ?? true,
      type: typeStr == 'temporary' ? LabourType.temporary : LabourType.regular,
      siteId: (data['siteId'] as String?) ?? '',
    )
      ..firestoreId = doc.id
      ..contractorId = (data['contractorId'] as String?) ?? ''
      ..isSynced = true
      ..lastSyncedAt = (data['syncedAt'] as Timestamp?)?.toDate()
      ..syncedAt = (data['syncedAt'] as Timestamp?)?.toDate();
  }

  Labour copyWith({
    String? id,
    String? supervisorId,
    String? contractorId,
    String? name,
    String? phone,
    double? dailyWage,
    DateTime? joiningDate,
    bool? isActive,
    DateTime? syncedAt,
    bool? isSynced,
    String? firestoreId,
    DateTime? lastSyncedAt,
    double? overtimeWagePerHour,
    double? defaultOvertimeHours,
    LabourType? type,
    String? siteId,
  }) {
    return Labour(
      id: id ?? this.id,
      supervisorId: supervisorId ?? this.supervisorId,
      contractorId: contractorId ?? this.contractorId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      dailyWage: dailyWage ?? this.dailyWage,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      syncedAt: syncedAt ?? this.syncedAt,
      isSynced: isSynced ?? this.isSynced,
      firestoreId: firestoreId ?? this.firestoreId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      overtimeWagePerHour: overtimeWagePerHour ?? this.overtimeWagePerHour,
      defaultOvertimeHours: defaultOvertimeHours ?? this.defaultOvertimeHours,
      type: type ?? this.type,
      siteId: siteId ?? this.siteId,
    );
  }
}

class LabourAdapter extends TypeAdapter<Labour> {
  @override
  final int typeId = 20;

  @override
  Labour read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    final typeStr = fields[14] as String? ?? 'regular';

    return Labour(
      id: fields[0] as String,
      supervisorId: fields[1] as String,
      name: fields[2] as String,
      phone: fields[3] as String,
      dailyWage: (fields[4] as num).toDouble(),
      joiningDate: fields[5] as DateTime,
      isActive: fields[6] as bool? ?? true,
      syncedAt: fields[7] as DateTime?,
      isSynced: fields[8] as bool? ?? false,
      firestoreId: fields[9] as String?,
      lastSyncedAt: fields[10] as DateTime?,
      overtimeWagePerHour: (fields[11] as num?)?.toDouble() ?? 0,
      defaultOvertimeHours: (fields[12] as num?)?.toDouble() ?? 0,
      contractorId: fields[13] as String? ?? '',
      type: typeStr == 'temporary' ? LabourType.temporary : LabourType.regular,
      siteId: fields[15] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Labour obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.supervisorId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.dailyWage)
      ..writeByte(5)
      ..write(obj.joiningDate)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.syncedAt)
      ..writeByte(8)
      ..write(obj.isSynced)
      ..writeByte(9)
      ..write(obj.firestoreId)
      ..writeByte(10)
      ..write(obj.lastSyncedAt)
      ..writeByte(11)
      ..write(obj.overtimeWagePerHour)
      ..writeByte(12)
      ..write(obj.defaultOvertimeHours)
      ..writeByte(13)
      ..write(obj.contractorId)
      ..writeByte(14)
      ..write(obj.type == LabourType.temporary ? 'temporary' : 'regular')
      ..writeByte(15)
      ..write(obj.siteId);
  }
}
