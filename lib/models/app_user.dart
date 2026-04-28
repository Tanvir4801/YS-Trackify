import 'package:cloud_firestore/cloud_firestore.dart';

/// Authenticated app user model with contractor isolation context.
///
/// Resolution priority for contractorId at construction time:
///   1. user doc `contractorId` field (set by web admin panel)
///   2. labour doc `contractorId` field (set by web admin panel)
///   3. user doc `supervisorId` (legacy compat)
///   4. uid (final fallback for old supervisor accounts)
class AppUser {
  AppUser({
    required this.uid,
    required this.role,
    required this.contractorId,
    this.supervisorId = '',
    this.supervisorRef,
    this.labourId = '',
    this.name = '',
    this.phone = '',
    this.isActive = true,
  });

  final String uid;
  final String role;
  final String contractorId;
  final String supervisorId;
  final DocumentReference<Map<String, dynamic>>? supervisorRef;
  final String labourId;
  final String name;
  final String phone;
  final bool isActive;

  bool get isSupervisor => role == 'supervisor' || role == 'admin';
  bool get isLabour => role == 'labour';

  AppUser copyWith({
    String? uid,
    String? role,
    String? contractorId,
    String? supervisorId,
    DocumentReference<Map<String, dynamic>>? supervisorRef,
    String? labourId,
    String? name,
    String? phone,
    bool? isActive,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      contractorId: contractorId ?? this.contractorId,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorRef: supervisorRef ?? this.supervisorRef,
      labourId: labourId ?? this.labourId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
    );
  }
}
