import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreAudit {
  static Future<void> runAudit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final db = FirebaseFirestore.instance;

    debugPrint('');
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 FIRESTORE AUDIT START');
    debugPrint('═══════════════════════════════════════');
    debugPrint('Current UID: $uid');
    debugPrint('');

    // 1. Users collection
    try {
      final userDoc = await db.collection('users').doc(uid).get();
      debugPrint('👤 USER DOC: ${userDoc.exists ? "EXISTS" : "MISSING"}');
      if (userDoc.exists) {
        final d = userDoc.data()!;
        debugPrint('   role:         ${d['role']}');
        debugPrint('   contractorId: ${d['contractorId']}');
        debugPrint('   name:         ${d['name']}');
      }
    } catch (e) {
      debugPrint('👤 USER DOC ERROR: $e');
    }

    debugPrint('');

    // 2. Labours by supervisorId
    try {
      final s1 = await db
          .collection('labours')
          .where('supervisorId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();
      debugPrint('👷 LABOURS (supervisorId): ${s1.docs.length} found');
      for (var d in s1.docs) {
        debugPrint(
            '   - ${d.data()['name']} | wage: ${d.data()['dailyWage']} | id: ${d.id}');
      }
    } catch (e) {
      debugPrint('👷 LABOURS supervisorId ERROR: $e');
    }

    debugPrint('');

    // 3. Labours by contractorId
    try {
      final s2 = await db
          .collection('labours')
          .where('contractorId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();
      debugPrint('👷 LABOURS (contractorId): ${s2.docs.length} found');
    } catch (e) {
      debugPrint('👷 LABOURS contractorId ERROR: $e');
    }

    debugPrint('');

    // 4. Today attendance
    final today = _dateStr(DateTime.now());
    try {
      final a1 = await db
          .collection('attendance')
          .where('supervisorId', isEqualTo: uid)
          .where('date', isEqualTo: today)
          .get();
      debugPrint('📅 TODAY ATTENDANCE ($today): ${a1.docs.length} records');
      for (var d in a1.docs) {
        debugPrint(
            '   - labourId: ${d.data()['labourId']} | status: ${d.data()['status']} | site: ${d.data()['siteId'] ?? 'NO SITE'}');
      }
    } catch (e) {
      debugPrint('📅 TODAY ATTENDANCE ERROR: $e');
    }

    debugPrint('');

    // 5. Last 7 days attendance
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    try {
      final a2 = await db
          .collection('attendance')
          .where('supervisorId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: _dateStr(sevenDaysAgo))
          .get();
      debugPrint('📊 LAST 7 DAYS ATTENDANCE: ${a2.docs.length} records');
      final byDate = <String, int>{};
      for (var d in a2.docs) {
        final date = d.data()['date'] as String? ?? '';
        byDate[date] = (byDate[date] ?? 0) + 1;
      }
      byDate.forEach((date, count) {
        debugPrint('   $date: $count records');
      });
    } catch (e) {
      debugPrint('📊 LAST 7 DAYS ERROR: $e');
    }

    debugPrint('');

    // 6. Sites
    try {
      final sites1 = await db
          .collection('sites')
          .where('supervisorId', isEqualTo: uid)
          .get();
      final sites2 = await db
          .collection('sites')
          .where('contractorId', isEqualTo: uid)
          .get();
      debugPrint('🏗️ SITES (supervisorId): ${sites1.docs.length}');
      debugPrint('🏗️ SITES (contractorId): ${sites2.docs.length}');
      for (var d in [...sites1.docs, ...sites2.docs]) {
        debugPrint('   - ${d.data()['name']} | id: ${d.id}');
      }
    } catch (e) {
      debugPrint('🏗️ SITES ERROR: $e');
    }

    debugPrint('');

    // 7. Payments / advances
    try {
      final p = await db
          .collection('payments')
          .where('supervisorId', isEqualTo: uid)
          .get();
      debugPrint('💰 PAYMENTS: ${p.docs.length} records');
    } catch (e) {
      debugPrint('💰 PAYMENTS ERROR: $e');
    }

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 FIRESTORE AUDIT END');
    debugPrint('═══════════════════════════════════════');
    debugPrint('');
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

