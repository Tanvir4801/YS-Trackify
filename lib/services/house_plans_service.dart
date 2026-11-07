import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/house_plan_model.dart';

class HousePlansService {
  final FirebaseFirestore _db;

  HousePlansService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final HousePlansService instance = HousePlansService();

  /// Real-time stream of house plans for the given contractor.
  /// Changes in Admin Web or on mobile reflect instantly across all clients.
  Stream<List<HousePlanOwner>> streamHousePlans(String contractorId) {
    if (contractorId.isEmpty) {
      return Stream.value([]);
    }

    return _db
        .collection('house_plans')
        .where('contractorId', isEqualTo: contractorId)
        .snapshots()
        .map((snapshot) {
      final list = <HousePlanOwner>[];
      for (final doc in snapshot.docs) {
        if (doc.id.startsWith('_catalog_') || (doc.data()['isCatalogDoc'] == true)) {
          continue;
        }
        try {
          list.add(HousePlanOwner.fromFirestore(doc));
        } catch (e) {
          debugPrint('[HousePlansService] Error parsing owner doc ${doc.id}: $e');
        }
      }
      // Sort alphabetically by owner name or by most recently updated
      list.sort((a, b) => a.ownerName.toLowerCase().compareTo(b.ownerName.toLowerCase()));
      return list;
    });
  }

  /// Toggle or update the completion status of a specific drawing.
  /// If invoked by a supervisor, sets verificationStatus to 'pending_admin_verification'
  /// so Admin can review and verify in the two-factor workflow.
  Future<void> updateDrawingStatus({
    required String ownerId,
    required String planId,
    required String newStatus,
    String? userRole,
    String? userName,
    String? userUid,
  }) async {
    final docRef = _db.collection('house_plans').doc(ownerId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final rawPlans = (data['plansList'] as List<dynamic>?) ?? [];
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final isSupervisor = userRole == 'supervisor';
    final nowIso = DateTime.now().toIso8601String();

    String affectedPlanName = '';

    final updatedPlans = rawPlans.map((item) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if (map['id'] == planId || map['name'] == planId) {
          map['status'] = newStatus;
          affectedPlanName = (map['name'] as String?) ?? planId;
          if (newStatus == 'completed') {
            map['completedDate'] = todayStr;
          } else {
            map.remove('completedDate');
          }

          // Two-Factor verification tracking
          if (isSupervisor) {
            map['verificationStatus'] = 'pending_admin_verification';
            map['modifiedByRole'] = 'supervisor';
            map['modifiedByName'] = userName ?? 'Supervisor';
            map['modifiedByUid'] = userUid ?? '';
            map['modifiedAt'] = nowIso;
          } else {
            map['verificationStatus'] = 'verified';
            map['modifiedByRole'] = userRole ?? 'contractor';
            map['modifiedByName'] = userName ?? 'Admin';
            map['modifiedByUid'] = userUid ?? '';
            map['modifiedAt'] = nowIso;
          }
        }
        return map;
      }
      return item;
    }).toList();

    final updatePayload = <String, dynamic>{
      'plansList': updatedPlans,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isSupervisor) {
      updatePayload['hasPendingSupervisorChanges'] = true;
      updatePayload['lastSupervisorAction'] = 'Drawing "$affectedPlanName" set to $newStatus by ${userName ?? 'Supervisor'}';
      updatePayload['lastSupervisorActionAt'] = FieldValue.serverTimestamp();
    }

    await docRef.update(updatePayload);
  }

  /// Log a new consultation or site inspection visit.
  Future<void> addSiteVisit({
    required String ownerId,
    required HouseSiteVisit visit,
    String? userRole,
    String? userName,
    String? userUid,
  }) async {
    final docRef = _db.collection('house_plans').doc(ownerId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final rawVisits = (data['siteVisits'] as List<dynamic>?) ?? [];
    final isSupervisor = userRole == 'supervisor';

    final visitMap = visit.toMap();
    if (isSupervisor) {
      visitMap['verificationStatus'] = 'pending_admin_verification';
      visitMap['recordedByRole'] = 'supervisor';
      visitMap['recordedByName'] = userName ?? 'Supervisor';
      visitMap['recordedByUid'] = userUid ?? '';
    } else {
      visitMap['verificationStatus'] = 'verified';
      visitMap['recordedByRole'] = userRole ?? 'contractor';
      visitMap['recordedByName'] = userName ?? 'Admin';
      visitMap['recordedByUid'] = userUid ?? '';
    }

    final updatedVisits = List<dynamic>.from(rawVisits)..add(visitMap);

    // Calculate new total visits amount
    double newVisitsSum = 0;
    for (final v in updatedVisits) {
      if (v is Map) {
        final amt = v['amount'];
        if (amt is num) newVisitsSum += amt.toDouble();
      }
    }

    final houseAmount = (data['houseAmount'] is num) ? (data['houseAmount'] as num).toDouble() : 0.0;
    final totalBillable = houseAmount + newVisitsSum;

    final payments = (data['payments'] as List<dynamic>?) ?? [];
    double paymentsSum = 0;
    for (final p in payments) {
      if (p is Map) {
        final amt = p['amount'];
        if (amt is num) paymentsSum += amt.toDouble();
      }
    }
    final rawPaid = (data['totalPaid'] is num) ? (data['totalPaid'] as num).toDouble() : 0.0;
    final totalPaid = paymentsSum > 0 ? paymentsSum : rawPaid;
    final pendingBalance = (totalBillable - totalPaid).clamp(0.0, double.infinity);

    final planFeePaid = (totalPaid > houseAmount ? houseAmount : totalPaid);
    final planFeePending = (houseAmount - planFeePaid).clamp(0.0, double.infinity);
    final visitsPaid = (totalPaid - houseAmount).clamp(0.0, double.infinity);
    final visitsPending = (newVisitsSum - visitsPaid).clamp(0.0, double.infinity);
    final isVisitsCleared = newVisitsSum > 0 ? visitsPending <= 0 : true;
    final isFullyCleared = totalBillable > 0 && pendingBalance <= 0;

    final updatePayload = <String, dynamic>{
      'siteVisits': updatedVisits,
      'totalVisitsAmount': newVisitsSum,
      'totalBillableAmount': totalBillable,
      'totalPaid': totalPaid,
      'pendingBalance': pendingBalance,
      'planFeePaid': planFeePaid,
      'planFeePending': planFeePending,
      'visitsPaid': visitsPaid,
      'visitsPending': visitsPending,
      'isVisitsCleared': isVisitsCleared,
      'isFullyCleared': isFullyCleared,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isSupervisor) {
      updatePayload['hasPendingSupervisorChanges'] = true;
      updatePayload['lastSupervisorAction'] = 'Site visit ₹${visit.amount} logged by ${userName ?? 'Supervisor'}';
      updatePayload['lastSupervisorActionAt'] = FieldValue.serverTimestamp();
    }

    await docRef.update(updatePayload);
  }

  /// Admin 2-Factor Verification: Approve a specific drawing changed by supervisor.
  Future<void> verifyDrawingChange({
    required String ownerId,
    required String planId,
    required String adminUid,
    required String adminName,
  }) async {
    final docRef = _db.collection('house_plans').doc(ownerId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final rawPlans = (data['plansList'] as List<dynamic>?) ?? [];
    final nowIso = DateTime.now().toIso8601String();

    final updatedPlans = rawPlans.map((item) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if (map['id'] == planId || map['name'] == planId) {
          map['verificationStatus'] = 'verified';
          map['verifiedBy'] = adminName;
          map['verifiedByUid'] = adminUid;
          map['verifiedAt'] = nowIso;
        }
        return map;
      }
      return item;
    }).toList();

    // Check if any other items still pending verification
    bool stillHasPending = updatedPlans.any((p) => p is Map && p['verificationStatus'] == 'pending_admin_verification');
    final rawVisits = (data['siteVisits'] as List<dynamic>?) ?? [];
    if (!stillHasPending) {
      stillHasPending = rawVisits.any((v) => v is Map && v['verificationStatus'] == 'pending_admin_verification');
    }

    await docRef.update({
      'plansList': updatedPlans,
      'hasPendingSupervisorChanges': stillHasPending,
      if (!stillHasPending) 'lastSupervisorAction': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin 2-Factor Verification: Approve a site visit logged by supervisor.
  Future<void> verifySiteVisit({
    required String ownerId,
    required String visitId,
    required String adminUid,
    required String adminName,
  }) async {
    final docRef = _db.collection('house_plans').doc(ownerId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final rawVisits = (data['siteVisits'] as List<dynamic>?) ?? [];
    final nowIso = DateTime.now().toIso8601String();

    final updatedVisits = rawVisits.map((item) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if (map['id'] == visitId) {
          map['verificationStatus'] = 'verified';
          map['verifiedBy'] = adminName;
          map['verifiedByUid'] = adminUid;
          map['verifiedAt'] = nowIso;
        }
        return map;
      }
      return item;
    }).toList();

    final rawPlans = (data['plansList'] as List<dynamic>?) ?? [];
    bool stillHasPending = updatedVisits.any((v) => v is Map && v['verificationStatus'] == 'pending_admin_verification');
    if (!stillHasPending) {
      stillHasPending = rawPlans.any((p) => p is Map && p['verificationStatus'] == 'pending_admin_verification');
    }

    await docRef.update({
      'siteVisits': updatedVisits,
      'hasPendingSupervisorChanges': stillHasPending,
      if (!stillHasPending) 'lastSupervisorAction': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin 2-Factor Verification: Approve ALL pending supervisor changes for this owner.
  Future<void> verifyAllPendingChanges({
    required String ownerId,
    required String adminUid,
    required String adminName,
  }) async {
    final docRef = _db.collection('house_plans').doc(ownerId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final nowIso = DateTime.now().toIso8601String();

    final rawPlans = (data['plansList'] as List<dynamic>?) ?? [];
    final updatedPlans = rawPlans.map((item) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if (map['verificationStatus'] == 'pending_admin_verification') {
          map['verificationStatus'] = 'verified';
          map['verifiedBy'] = adminName;
          map['verifiedByUid'] = adminUid;
          map['verifiedAt'] = nowIso;
        }
        return map;
      }
      return item;
    }).toList();

    final rawVisits = (data['siteVisits'] as List<dynamic>?) ?? [];
    final updatedVisits = rawVisits.map((item) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if (map['verificationStatus'] == 'pending_admin_verification') {
          map['verificationStatus'] = 'verified';
          map['verifiedBy'] = adminName;
          map['verifiedByUid'] = adminUid;
          map['verifiedAt'] = nowIso;
        }
        return map;
      }
      return item;
    }).toList();

    await docRef.update({
      'plansList': updatedPlans,
      'siteVisits': updatedVisits,
      'hasPendingSupervisorChanges': false,
      'lastSupervisorAction': null,
      'lastAdminVerifiedAt': FieldValue.serverTimestamp(),
      'lastAdminVerifiedBy': adminName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a logged site visit.
  Future<void> deleteSiteVisit({
    required String ownerId,
    required String visitId,
  }) async {
    final docRef = _db.collection('house_plans').doc(ownerId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final rawVisits = (data['siteVisits'] as List<dynamic>?) ?? [];
    final updatedVisits = rawVisits.where((v) {
      if (v is Map) {
        return v['id'] != visitId;
      }
      return true;
    }).toList();

    double newVisitsSum = 0;
    for (final v in updatedVisits) {
      if (v is Map) {
        final amt = v['amount'];
        if (amt is num) newVisitsSum += amt.toDouble();
      }
    }

    final houseAmount = (data['houseAmount'] is num) ? (data['houseAmount'] as num).toDouble() : 0.0;
    final totalBillable = houseAmount + newVisitsSum;

    final payments = (data['payments'] as List<dynamic>?) ?? [];
    double paymentsSum = 0;
    for (final p in payments) {
      if (p is Map) {
        final amt = p['amount'];
        if (amt is num) paymentsSum += amt.toDouble();
      }
    }
    final rawPaid = (data['totalPaid'] is num) ? (data['totalPaid'] as num).toDouble() : 0.0;
    final totalPaid = paymentsSum > 0 ? paymentsSum : rawPaid;
    final pendingBalance = (totalBillable - totalPaid).clamp(0.0, double.infinity);

    final planFeePaid = (totalPaid > houseAmount ? houseAmount : totalPaid);
    final planFeePending = (houseAmount - planFeePaid).clamp(0.0, double.infinity);
    final visitsPaid = (totalPaid - houseAmount).clamp(0.0, double.infinity);
    final visitsPending = (newVisitsSum - visitsPaid).clamp(0.0, double.infinity);
    final isVisitsCleared = newVisitsSum > 0 ? visitsPending <= 0 : true;
    final isFullyCleared = totalBillable > 0 && pendingBalance <= 0;

    await docRef.update({
      'siteVisits': updatedVisits,
      'totalVisitsAmount': newVisitsSum,
      'totalBillableAmount': totalBillable,
      'totalPaid': totalPaid,
      'pendingBalance': pendingBalance,
      'planFeePaid': planFeePaid,
      'planFeePending': planFeePending,
      'visitsPaid': visitsPaid,
      'visitsPending': visitsPending,
      'isVisitsCleared': isVisitsCleared,
      'isFullyCleared': isFullyCleared,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

