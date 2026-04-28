import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'supervisorId': supervisorId,
      'name': name,
      'phone': phone,
      'dailyWage': dailyWage,
      'joiningDate': Timestamp.fromDate(joiningDate),
      'isActive': isActive,
      'isSynced': true,
      'syncedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Labour.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Labour(
      id: (data['id'] as String?) ?? doc.id,
      supervisorId: (data['supervisorId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      dailyWage: ((data['dailyWage'] as num?) ?? 0).toDouble(),
      joiningDate: (data['joiningDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: (data['isActive'] as bool?) ?? true,
    )
      ..firestoreId = doc.id
      ..isSynced = true
      ..lastSyncedAt = (data['syncedAt'] as Timestamp?)?.toDate()
      ..syncedAt = (data['syncedAt'] as Timestamp?)?.toDate();
  }

  Labour copyWith({
    String? id,
    String? supervisorId,
    String? name,
    String? phone,
    double? dailyWage,
    DateTime? joiningDate,
    bool? isActive,
    DateTime? syncedAt,
    bool? isSynced,
    String? firestoreId,
    DateTime? lastSyncedAt,
  }) {
    return Labour(
      id: id ?? this.id,
      supervisorId: supervisorId ?? this.supervisorId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      dailyWage: dailyWage ?? this.dailyWage,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      syncedAt: syncedAt ?? this.syncedAt,
      isSynced: isSynced ?? this.isSynced,
      firestoreId: firestoreId ?? this.firestoreId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    );
  }

  @override
  void write(BinaryWriter writer, Labour obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.lastSyncedAt);
  }
}
