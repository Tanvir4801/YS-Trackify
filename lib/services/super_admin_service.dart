import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class SuperAdminStats {
  final int totalContractors;
  final int premiumUsers;
  final int totalLabour;
  final double monthlyRevenue;
  final String storageUsage;
  final String activeContractorName;
  final int todayAttendance;

  SuperAdminStats({
    this.totalContractors = 0,
    this.premiumUsers = 0,
    this.totalLabour = 0,
    this.monthlyRevenue = 0,
    this.storageUsage = '0 GB',
    this.activeContractorName = 'N/A',
    this.todayAttendance = 0,
  });
}

class SuperAdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  Future<SuperAdminStats> fetchDashboardStats() async {
    try {
      // 1. Fetch Total Contractors (count of users with role == contractor or simply count of contractors col)
      final contractorsSnap = await _firestore.collection('users').where('role', isEqualTo: 'contractor').count().get().timeout(const Duration(seconds: 10));
      final totalContractors = contractorsSnap.count ?? 0;

      // 2. Premium Users
      final premiumSnap = await _firestore.collection('users').where('isPremium', isEqualTo: true).count().get().timeout(const Duration(seconds: 10));
      int premiumUsers = premiumSnap.count ?? 0;

      // 3. Total Labour
      final labourSnap = await _firestore.collection('labours').count().get().timeout(const Duration(seconds: 10));
      final totalLabour = labourSnap.count ?? 0;

      // 4. Monthly Revenue
      // Estimate based on premium users
      final monthlyRevenue = premiumUsers * 3181.81;

      // 5. Storage Usage
      const storageUsage = '35 GB';

      // 6. Today's Attendance from RTDB
      int todayAttendance = 0;
      String activeContractorId = '';
      int maxAttendance = 0;

      final rtdbSnap = await _rtdb.ref('liveDashboard').get().timeout(const Duration(seconds: 10));
      if (rtdbSnap.exists && rtdbSnap.value != null) {
        final data = rtdbSnap.value as Map<dynamic, dynamic>;
        data.forEach((cId, sitesMap) {
          int contractorTotal = 0;
          if (sitesMap is Map<dynamic, dynamic>) {
            sitesMap.forEach((sId, stats) {
              if (stats is Map<dynamic, dynamic>) {
                final present = (stats['present'] as num?)?.toInt() ?? 0;
                contractorTotal += present;
                todayAttendance += present;
              }
            });
          }
          if (contractorTotal > maxAttendance) {
            maxAttendance = contractorTotal;
            activeContractorId = cId.toString();
          }
        });
      }

      // 7. Active Contractor Name
      String activeContractorName = 'YS Construction';
      if (activeContractorId.isNotEmpty) {
        final doc = await _firestore.collection('users').doc(activeContractorId).get().timeout(const Duration(seconds: 10));
        if (doc.exists) {
          activeContractorName = doc.data()?['name'] ?? 'YS Construction';
        }
      }

      return SuperAdminStats(
        totalContractors: totalContractors,
        premiumUsers: premiumUsers,
        totalLabour: totalLabour,
        monthlyRevenue: monthlyRevenue,
        storageUsage: storageUsage,
        activeContractorName: activeContractorName,
        todayAttendance: todayAttendance,
      );
    } catch (e) {
      debugPrint('[SuperAdminService] Failed to fetch stats: $e');
      return SuperAdminStats();
    }
  }
}
