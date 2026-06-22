import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../models/attendance_model.dart';

class RtdbService {
  RtdbService._privateConstructor();
  static final RtdbService instance = RtdbService._privateConstructor();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Syncs the dashboard statistics for a specific site on a specific date.
  /// It reads from the local Hive Attendance box to compute the totals quickly.
  Future<void> syncDashboardStats({
    required String contractorId,
    required String siteId,
    required String date,
  }) async {
    if (contractorId.isEmpty || siteId.isEmpty || date.isEmpty) return;
    
    // Only sync if the date is today (live dashboard is for today)
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (date != today) return;

    try {
      final box = Hive.box<Attendance>(Attendance.boxName);
      
      int present = 0;
      int absent = 0;
      int halfDay = 0;
      double totalExpense = 0;

      // Compute stats from local cache
      final records = box.values.where((a) {
        if (a.date != date) return false;
        final effSiteId = a.siteId.isNotEmpty ? a.siteId : a.supervisorId;
        return effSiteId == siteId;
      });
      for (final att in records) {
        if (att.status == AttendanceStatus.present) {
          present++;
        } else if (att.status == AttendanceStatus.absent) {
          absent++;
        } else if (att.status == AttendanceStatus.half) {
          halfDay++;
        }

        // Add to total expense
        final grandTotal = (att.wageAtTime) + (att.totalAllowance) - (att.advance);
        if (grandTotal > 0 && att.status != AttendanceStatus.absent) {
           totalExpense += grandTotal;
        }
      }

      final status = present > 0 || halfDay > 0 ? 'Active' : 'Idle';

      // Update RTDB atomically
      final ref = _db.ref('liveDashboard/$contractorId/$siteId');
      await ref.update({
        'present': present,
        'absent': absent,
        'halfDay': halfDay,
        'totalExpense': totalExpense,
        'status': status,
        'lastUpdated': ServerValue.timestamp,
      });

      debugPrint('[RtdbService] Synced live stats for site $siteId: $present P, $absent A, $halfDay H');
    } catch (e) {
      debugPrint('[RtdbService] Error syncing dashboard stats: $e');
    }
  }

  /// Syncs the total labour count for a specific site.
  Future<void> syncLabourCount({
    required String contractorId,
    required String siteId,
    required int count,
  }) async {
    if (contractorId.isEmpty || siteId.isEmpty) return;

    try {
      final ref = _db.ref('liveDashboard/$contractorId/$siteId');
      await ref.update({
        'labourCount': count,
      });
      debugPrint('[RtdbService] Synced labour count for site $siteId: $count');
    } catch (e) {
      debugPrint('[RtdbService] Error syncing labour count: $e');
    }
  }
}
