import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 34)
class DailyClosingReport extends HiveObject {
  DailyClosingReport({
    required this.id,
    required this.contractorId,
    required this.siteId,
    required this.siteName,
    required this.date,
    this.presentCount = 0,
    this.absentCount = 0,
    this.halfDayCount = 0,
    this.threeQuarterCount = 0,
    this.quarterCount = 0,
    this.totalLabourCost = 0,
    this.totalAdvance = 0,
    this.totalAllowances = 0,
    this.totalExpense = 0,
    this.totalLabourCount = 0,
    this.newLabourCount = 0,
    this.supervisorName = '',
    this.supervisorRemarks = '',
    this.generatedAt = '',
    this.insights = const [],
    this.isSynced = false,
    this.firestoreId,
    this.isRainHoliday = false,
    this.siteBreakdownJson = '[]',
    this.totalMaterialCost = 0.0,
    this.totalMachineryCost = 0.0,
    this.totalTransportCost = 0.0,
    this.totalOtherCost = 0.0,
  });

  static const String boxName = 'v2_closing_reports';

  @HiveField(0)
  String id;

  @HiveField(1)
  String contractorId;

  @HiveField(2)
  String siteId;

  @HiveField(3)
  String siteName;

  @HiveField(4)
  String date; // yyyy-MM-dd

  // Attendance
  @HiveField(5)
  int presentCount;

  @HiveField(6)
  int absentCount;

  @HiveField(7)
  int halfDayCount;

  @HiveField(21)
  int threeQuarterCount;

  @HiveField(22)
  int quarterCount;

  // Expenses
  @HiveField(8)
  double totalLabourCost;

  @HiveField(9)
  double totalAdvance;

  @HiveField(10)
  double totalAllowances;

  @HiveField(11)
  double totalExpense;

  @HiveField(23)
  String siteBreakdownJson;

  @HiveField(24)
  double totalMaterialCost;

  @HiveField(25)
  double totalMachineryCost;

  @HiveField(26)
  double totalTransportCost;

  @HiveField(27)
  double totalOtherCost;

  // Labour
  @HiveField(12)
  int totalLabourCount;

  @HiveField(13)
  int newLabourCount;

  // Meta
  @HiveField(14)
  String supervisorName;

  @HiveField(15)
  String supervisorRemarks;

  @HiveField(16)
  String generatedAt; // ISO datetime string

  @HiveField(17)
  List<String> insights;

  // Sync
  @HiveField(18)
  bool isSynced;

  @HiveField(19)
  String? firestoreId;

  @HiveField(20)
  bool isRainHoliday;

  /// Total marked attendance count
  int get totalMarked => presentCount + absentCount + halfDayCount + threeQuarterCount + quarterCount;

  /// Attendance percentage (present + half*0.5) / total
  double get attendancePercentage {
    if (totalLabourCount == 0) return 0;
    return ((presentCount + halfDayCount * 0.5 + threeQuarterCount * 0.75 + quarterCount * 0.25) / totalLabourCount) * 100;
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'contractorId': contractorId,
        'siteId': siteId,
        'siteName': siteName,
        'date': date,
        'presentCount': presentCount,
        'absentCount': absentCount,
        'halfDayCount': halfDayCount,
        'threeQuarterCount': threeQuarterCount,
        'quarterCount': quarterCount,
        'totalLabourCost': totalLabourCost,
        'totalAdvance': totalAdvance,
        'totalAllowances': totalAllowances,
        'totalExpense': totalExpense,
        'totalLabourCount': totalLabourCount,
        'newLabourCount': newLabourCount,
        'supervisorName': supervisorName,
        'supervisorRemarks': supervisorRemarks,
        'generatedAt': generatedAt,
        'insights': insights,
        'isRainHoliday': isRainHoliday,
        'siteBreakdownJson': siteBreakdownJson,
        'totalMaterialCost': totalMaterialCost,
        'totalMachineryCost': totalMachineryCost,
        'totalTransportCost': totalTransportCost,
        'totalOtherCost': totalOtherCost,
        'syncedAt': FieldValue.serverTimestamp(),
      };

  factory DailyClosingReport.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return DailyClosingReport(
      id: (d['id'] as String?) ?? doc.id,
      contractorId: (d['contractorId'] as String?) ?? '',
      siteId: (d['siteId'] as String?) ?? '',
      siteName: (d['siteName'] as String?) ?? '',
      date: (d['date'] as String?) ?? '',
      presentCount: (d['presentCount'] as num?)?.toInt() ?? 0,
      absentCount: (d['absentCount'] as num?)?.toInt() ?? 0,
      halfDayCount: (d['halfDayCount'] as num?)?.toInt() ?? 0,
      threeQuarterCount: (d['threeQuarterCount'] as num?)?.toInt() ?? 0,
      quarterCount: (d['quarterCount'] as num?)?.toInt() ?? 0,
      totalLabourCost: (d['totalLabourCost'] as num?)?.toDouble() ?? 0,
      totalAdvance: (d['totalAdvance'] as num?)?.toDouble() ?? 0,
      totalAllowances: (d['totalAllowances'] as num?)?.toDouble() ?? 0,
      totalExpense: (d['totalExpense'] as num?)?.toDouble() ?? 0,
      totalLabourCount: (d['totalLabourCount'] as num?)?.toInt() ?? 0,
      newLabourCount: (d['newLabourCount'] as num?)?.toInt() ?? 0,
      supervisorName: (d['supervisorName'] as String?) ?? '',
      supervisorRemarks: (d['supervisorRemarks'] as String?) ?? '',
      generatedAt: (d['generatedAt'] as String?) ?? '',
      insights: List<String>.from(d['insights'] ?? []),
      isRainHoliday: (d['isRainHoliday'] as bool?) ?? false,
      siteBreakdownJson: (d['siteBreakdownJson'] as String?) ?? '[]',
      totalMaterialCost: (d['totalMaterialCost'] as num?)?.toDouble() ?? 0,
      totalMachineryCost: (d['totalMachineryCost'] as num?)?.toDouble() ?? 0,
      totalTransportCost: (d['totalTransportCost'] as num?)?.toDouble() ?? 0,
      totalOtherCost: (d['totalOtherCost'] as num?)?.toDouble() ?? 0,
      isSynced: true,
      firestoreId: doc.id,
    );
  }

  DailyClosingReport copyWith({
    String? id,
    String? contractorId,
    String? siteId,
    String? siteName,
    String? date,
    int? presentCount,
    int? absentCount,
    int? halfDayCount,
    double? totalLabourCost,
    double? totalAdvance,
    double? totalAllowances,
    double? totalExpense,
    int? totalLabourCount,
    int? newLabourCount,
    String? supervisorName,
    String? supervisorRemarks,
    String? generatedAt,
    List<String>? insights,
    bool? isSynced,
    String? firestoreId,
    bool? isRainHoliday,
    String? siteBreakdownJson,
    double? totalMaterialCost,
    double? totalMachineryCost,
    double? totalTransportCost,
    double? totalOtherCost,
  }) {
    return DailyClosingReport(
      id: id ?? this.id,
      contractorId: contractorId ?? this.contractorId,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      date: date ?? this.date,
      presentCount: presentCount ?? this.presentCount,
      absentCount: absentCount ?? this.absentCount,
      halfDayCount: halfDayCount ?? this.halfDayCount,
      totalLabourCost: totalLabourCost ?? this.totalLabourCost,
      totalAdvance: totalAdvance ?? this.totalAdvance,
      totalAllowances: totalAllowances ?? this.totalAllowances,
      totalExpense: totalExpense ?? this.totalExpense,
      totalLabourCount: totalLabourCount ?? this.totalLabourCount,
      newLabourCount: newLabourCount ?? this.newLabourCount,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorRemarks: supervisorRemarks ?? this.supervisorRemarks,
      generatedAt: generatedAt ?? this.generatedAt,
      insights: insights ?? this.insights,
      isSynced: isSynced ?? this.isSynced,
      firestoreId: firestoreId ?? this.firestoreId,
      isRainHoliday: isRainHoliday ?? this.isRainHoliday,
      siteBreakdownJson: siteBreakdownJson ?? this.siteBreakdownJson,
      totalMaterialCost: totalMaterialCost ?? this.totalMaterialCost,
      totalMachineryCost: totalMachineryCost ?? this.totalMachineryCost,
      totalTransportCost: totalTransportCost ?? this.totalTransportCost,
      totalOtherCost: totalOtherCost ?? this.totalOtherCost,
    );
  }
}

// ── Hive Adapters ─────────────────────────────────────────────────────────────

class DailyClosingReportAdapter extends TypeAdapter<DailyClosingReport> {
  @override
  final int typeId = 34;

  @override
  DailyClosingReport read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DailyClosingReport(
      id: fields[0] as String? ?? '',
      contractorId: fields[1] as String? ?? '',
      siteId: fields[2] as String? ?? '',
      siteName: fields[3] as String? ?? '',
      date: fields[4] as String? ?? '',
      presentCount: (fields[5] as num?)?.toInt() ?? 0,
      absentCount: (fields[6] as num?)?.toInt() ?? 0,
      halfDayCount: (fields[7] as num?)?.toInt() ?? 0,
      totalLabourCost: (fields[8] as num?)?.toDouble() ?? 0,
      totalAdvance: (fields[9] as num?)?.toDouble() ?? 0,
      totalAllowances: (fields[10] as num?)?.toDouble() ?? 0,
      totalExpense: (fields[11] as num?)?.toDouble() ?? 0,
      totalLabourCount: (fields[12] as num?)?.toInt() ?? 0,
      newLabourCount: (fields[13] as num?)?.toInt() ?? 0,
      supervisorName: fields[14] as String? ?? '',
      supervisorRemarks: fields[15] as String? ?? '',
      generatedAt: fields[16] as String? ?? '',
      insights: (fields[17] as List?)?.cast<String>() ?? [],
      isSynced: fields[18] as bool? ?? false,
      firestoreId: fields[19] as String?,
      isRainHoliday: fields[20] as bool? ?? false,
      threeQuarterCount: (fields[21] as num?)?.toInt() ?? 0,
      quarterCount: (fields[22] as num?)?.toInt() ?? 0,
      siteBreakdownJson: fields[23] as String? ?? '[]',
      totalMaterialCost: (fields[24] as num?)?.toDouble() ?? 0,
      totalMachineryCost: (fields[25] as num?)?.toDouble() ?? 0,
      totalTransportCost: (fields[26] as num?)?.toDouble() ?? 0,
      totalOtherCost: (fields[27] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, DailyClosingReport obj) {
    writer
      ..writeByte(28) // field count
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.contractorId)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.siteName)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.presentCount)
      ..writeByte(6)
      ..write(obj.absentCount)
      ..writeByte(7)
      ..write(obj.halfDayCount)
      ..writeByte(8)
      ..write(obj.totalLabourCost)
      ..writeByte(9)
      ..write(obj.totalAdvance)
      ..writeByte(10)
      ..write(obj.totalAllowances)
      ..writeByte(11)
      ..write(obj.totalExpense)
      ..writeByte(12)
      ..write(obj.totalLabourCount)
      ..writeByte(13)
      ..write(obj.newLabourCount)
      ..writeByte(14)
      ..write(obj.supervisorName)
      ..writeByte(15)
      ..write(obj.supervisorRemarks)
      ..writeByte(16)
      ..write(obj.generatedAt)
      ..writeByte(17)
      ..write(obj.insights)
      ..writeByte(18)
      ..write(obj.isSynced)
      ..writeByte(19)
      ..write(obj.firestoreId)
      ..writeByte(20)
      ..write(obj.isRainHoliday)
      ..writeByte(21)
      ..write(obj.threeQuarterCount)
      ..writeByte(22)
      ..write(obj.quarterCount)
      ..writeByte(23)
      ..write(obj.siteBreakdownJson)
      ..writeByte(24)
      ..write(obj.totalMaterialCost)
      ..writeByte(25)
      ..write(obj.totalMachineryCost)
      ..writeByte(26)
      ..write(obj.totalTransportCost)
      ..writeByte(27)
      ..write(obj.totalOtherCost);
  }
}
