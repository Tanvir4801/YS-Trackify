import 'package:cloud_firestore/cloud_firestore.dart';

class TempLabourEntry {
  final String id;
  final String contractorId;
  final String supervisorId;
  final String siteId;
  final String date;
  final String name;
  final double wage;
  final double attendanceUnit;
  final String remarks;
  final double totalWage;
  final double paidAmount;
  final double remainingAmount;
  final String paymentStatus;
  final String? paymentDate;
  final String paymentRemark;
  final String paymentMethod;
  final String paymentTime;
  final String paidBy;
  final String phone;
  final String village;
  final DateTime createdAt;

  TempLabourEntry({
    required this.id,
    required this.contractorId,
    required this.supervisorId,
    required this.siteId,
    required this.date,
    required this.name,
    required this.wage,
    required this.attendanceUnit,
    this.remarks = '',
    this.totalWage = 0.0,
    this.paidAmount = 0.0,
    this.remainingAmount = 0.0,
    this.paymentStatus = 'unpaid',
    this.paymentDate,
    this.paymentRemark = '',
    this.paymentMethod = '',
    this.paymentTime = '',
    this.paidBy = '',
    this.phone = '',
    this.village = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TempLabourEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TempLabourEntry(
      id: doc.id,
      contractorId: data['contractorId'] ?? '',
      supervisorId: data['supervisorId'] ?? '',
      siteId: data['siteId'] ?? '',
      date: data['date'] ?? '',
      name: data['name'] ?? '',
      wage: (data['wage'] as num?)?.toDouble() ?? 0.0,
      attendanceUnit: (data['attendanceUnit'] as num?)?.toDouble() ?? 1.0,
      remarks: data['remarks'] ?? '',
      totalWage: (data['totalWage'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (data['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: data['paymentStatus'] ?? 'unpaid',
      paymentDate: data['paymentDate'],
      paymentRemark: data['paymentRemark'] ?? '',
      paymentMethod: data['paymentMethod'] ?? '',
      paymentTime: data['paymentTime'] ?? '',
      paidBy: data['paidBy'] ?? '',
      phone: data['phone'] ?? '',
      village: data['village'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'contractorId': contractorId,
      'supervisorId': supervisorId,
      'siteId': siteId,
      'date': date,
      'name': name,
      'wage': wage,
      'attendanceUnit': attendanceUnit,
      'remarks': remarks,
      'totalWage': totalWage,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'paymentStatus': paymentStatus,
      'paymentDate': paymentDate,
      'paymentRemark': paymentRemark,
      'paymentMethod': paymentMethod,
      'paymentTime': paymentTime,
      'paidBy': paidBy,
      'phone': phone,
      'village': village,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TempLabourEntry copyWith({
    String? name,
    String? siteId,
    double? wage,
    double? attendanceUnit,
    String? remarks,
    double? totalWage,
    double? paidAmount,
    double? remainingAmount,
    String? paymentStatus,
    String? paymentDate,
    String? paymentRemark,
    String? paymentMethod,
    String? paymentTime,
    String? paidBy,
    String? phone,
    String? village,
  }) {
    return TempLabourEntry(
      id: id,
      contractorId: contractorId,
      supervisorId: supervisorId,
      siteId: siteId ?? this.siteId,
      date: date,
      name: name ?? this.name,
      wage: wage ?? this.wage,
      attendanceUnit: attendanceUnit ?? this.attendanceUnit,
      remarks: remarks ?? this.remarks,
      totalWage: totalWage ?? this.totalWage,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentRemark: paymentRemark ?? this.paymentRemark,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentTime: paymentTime ?? this.paymentTime,
      paidBy: paidBy ?? this.paidBy,
      phone: phone ?? this.phone,
      village: village ?? this.village,
      createdAt: createdAt,
    );
  }
}
