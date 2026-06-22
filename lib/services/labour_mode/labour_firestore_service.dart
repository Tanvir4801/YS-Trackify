import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/date_utils.dart';
import '../../models/attendance_model.dart';
import '../../models/labour_model.dart';
import '../../models/payment_model.dart';
import '../../models/notification_model.dart';
import '../../models/notice_model.dart';

class LabourDashboardSummary {
  LabourDashboardSummary({
    required this.totalDaysWorked,
    required this.dailyWage,
    required this.basePay,
    required this.extraHours,
    required this.overtimeRate,
    required this.overtimePay,
    required this.totalEarned,
    required this.advanceTaken,
    required this.finalPay,
  });

  final double totalDaysWorked;
  final double dailyWage;
  final double basePay;
  final double extraHours;
  final double overtimeRate;
  final double overtimePay;
  final double totalEarned;
  final double advanceTaken;
  final double finalPay;
}

class LabourFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream all attendance records for a specific labourer across all dates.
  /// Uses a Collection Group query on 'records'.
  Stream<List<Attendance>> streamAttendance(String labourId) {
    return _db
        .collectionGroup('records')
        .where('labourId', isEqualTo: labourId)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        
        // Handle potential schema variations between legacy and new
        final date = data['date'] as String?;
        final statusStr = data['status'] as String?;
        
        return Attendance(
          id: doc.id,
          labourId: labourId,
          supervisorId: data['supervisorId'] as String? ?? '',
          contractorId: data['contractorId'] as String? ?? '',
          date: date ?? '',
          status: AttendanceStatusX.fromFirestoreValue(statusStr),
          overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0.0,
          notes: data['notes'] as String? ?? '',
          remark: data['remark'] as String? ?? '',
          wageAtTime: (data['wageAtTime'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    }).handleError((e) {
      debugPrint('🔥 Error streaming attendance for labour: $e');
      return <Attendance>[];
    });
  }

  /// Stream all payments for a specific labourer.
  Stream<List<Payment>> streamPayments(String labourId) {
    return _db
        .collection('payments')
        .where('labourId', isEqualTo: labourId)
        .snapshots()
        .map((snapshot) {
      final payments = snapshot.docs.map((doc) {
        final data = doc.data();
        return Payment(
          id: doc.id,
          labourId: labourId,
          supervisorId: data['supervisorId'] as String? ?? '',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          type: PaymentTypeX.fromFirestoreValue(data['type'] as String?),
          notes: data['notes'] as String? ?? '',
        );
      }).toList();

      payments.sort((a, b) => b.date.compareTo(a.date));
      return payments;
    }).handleError((e) {
      debugPrint('🔥 Error streaming payments for labour: $e');
      return <Payment>[];
    });
  }

  /// Stream notifications for a specific labourer
  Stream<List<NotificationModel>> streamNotifications(String labourId) {
    return _db
        .collection('labours')
        .doc(labourId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
    }).handleError((e) {
      debugPrint('🔥 Error streaming notifications: $e');
      return <NotificationModel>[];
    });
  }

  /// Build a real-time summary from the streamed attendance and payment lists.
  LabourDashboardSummary buildDashboardSummary(
    Labour labour,
    List<Attendance> records,
    List<Payment> payments,
  ) {
    var daysWorked = 0.0;
    var extraHours = 0.0;

    for (final record in records) {
      daysWorked += record.status.wageFactor;
      extraHours += record.overtimeHours;
    }

    // Formulas:
    final basePay = labour.dailyWage * daysWorked;
    final overtimePay = extraHours * (labour.overtimeWagePerHour > 0 ? labour.overtimeWagePerHour : 0);
    final totalEarned = basePay + overtimePay;

    // Advances
    double advanceTaken = 0.0;
    for (final payment in payments) {
      if (payment.type == PaymentType.advance) {
        advanceTaken += payment.amount;
      }
    }

    final finalPay = totalEarned - advanceTaken;

    return LabourDashboardSummary(
      totalDaysWorked: daysWorked,
      dailyWage: labour.dailyWage,
      basePay: basePay,
      extraHours: extraHours,
      overtimeRate: labour.overtimeWagePerHour,
      overtimePay: overtimePay,
      totalEarned: totalEarned,
      advanceTaken: advanceTaken,
      finalPay: finalPay,
    );
  }

  String formatDate(String dateKey) {
    try {
      final date = AppDateUtils.fromDateKey(dateKey);
      return AppDateUtils.toDisplay(date);
    } catch (_) {
      return dateKey;
    }
  }

  /// Submit a support request from the labour app
  Future<void> submitSupportRequest(Map<String, dynamic> requestData) async {
    try {
      await _db.collection('support_requests').doc(requestData['requestId']).set(requestData);
    } catch (e) {
      debugPrint('🔥 Error submitting support request: $e');
      rethrow;
    }
  }

  /// Get supervisor details (phone number and active site)
  Future<Map<String, dynamic>?> getSupervisor(String supervisorId) async {
    try {
      var doc = await _db.collection('users').doc(supervisorId).get();
      if (!doc.exists) {
        doc = await _db.collection('contractors').doc(supervisorId).get();
      }
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('🔥 Error fetching supervisor: $e');
      return null;
    }
  }

  Stream<List<Notice>> streamNotices(String supervisorId) {
    return _db
        .collection('notices')
        .where('supervisorId', isEqualTo: supervisorId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          final validNotices = <Notice>[];
          for (final doc in snap.docs) {
            final notice = Notice.fromMap(doc.data(), doc.id);
            if (now.difference(notice.createdAt).inHours <= 24) {
              validNotices.add(notice);
            } else {
              // Automatically delete notices older than 24 hours
              doc.reference.delete();
            }
          }
          return validNotices;
        });
  }

  /// Post a new notice
  Future<void> postNotice(Notice notice) async {
    await _db.collection('notices').doc(notice.id).set(notice.toMap());
  }
}
