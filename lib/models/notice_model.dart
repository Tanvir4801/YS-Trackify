import 'package:cloud_firestore/cloud_firestore.dart';

class Notice {
  final String id;
  final String contractorId;
  final String supervisorId;
  final String message;
  final bool isActive;
  final DateTime createdAt;

  Notice({
    required this.id,
    required this.contractorId,
    required this.supervisorId,
    required this.message,
    required this.isActive,
    required this.createdAt,
  });

  factory Notice.fromMap(Map<String, dynamic> data, String docId) {
    return Notice(
      id: docId,
      contractorId: data['contractorId'] ?? '',
      supervisorId: data['supervisorId'] ?? '',
      message: data['message'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contractorId': contractorId,
      'supervisorId': supervisorId,
      'message': message,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
