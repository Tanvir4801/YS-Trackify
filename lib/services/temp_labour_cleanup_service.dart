import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TempLabourCleanupService {
  static Future<void> runCleanup() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = _dateStr(DateTime.now());
    debugPrint('TempLabourCleanup: running for date $today');

    try {
      final db = FirebaseFirestore.instance;

      // Find all temp labours whose autoDeleteAfter < today
      final snap = await db
          .collection('labours')
          .where('supervisorId', isEqualTo: uid)
          .where('type',         isEqualTo: 'temporary')
          .where('isActive',     isEqualTo: true)
          .get();

      final batch = db.batch();
      int count   = 0;

      for (var doc in snap.docs) {
        final autoDeleteAfter =
            doc.data()['autoDeleteAfter'] as String? ?? '';

        // If autoDeleteAfter is set and is before today → deactivate
        if (autoDeleteAfter.isNotEmpty && autoDeleteAfter.compareTo(today) < 0) {
          batch.update(doc.reference, {
            'isActive':       false,
            'deactivatedAt':  FieldValue.serverTimestamp(),
            'deactivatedReason': 'temp_labour_auto_cleanup',
          });
          count++;
          debugPrint(
            'TempLabourCleanup: deactivating ${doc.data()['name']} '
            '(added $autoDeleteAfter, today $today)');
        }
      }

      if (count > 0) {
        await batch.commit();
        debugPrint('TempLabourCleanup: deactivated $count temp labours');
      } else {
        debugPrint('TempLabourCleanup: no temp labours to deactivate');
      }
    } catch (e) {
      debugPrint('TempLabourCleanup error: $e');
    }
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
