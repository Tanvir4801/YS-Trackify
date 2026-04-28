import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Secret salt — same must be used in Cloud Function
  static const String _salt = 'TRACKIFY_QR_SECRET_2026';

  String get labourUid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated labour found for QR generation.');
    }
    return user.uid;
  }

  // Token changes every 30 seconds.
  // Format before base64Url encoding: labourId|timestamp_window|hmac_signature
  String generateQRToken() {
    final now = DateTime.now();
    final windowSeconds = now.millisecondsSinceEpoch ~/ 30000;

    final payload = '$labourUid|$windowSeconds';

    final key = utf8.encode(_salt);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    final signature = digest.toString().substring(0, 16);

    final fullToken = '$labourUid|$windowSeconds|$signature';
    return base64Url.encode(utf8.encode(fullToken));
  }

  int currentWindow() {
    return DateTime.now().millisecondsSinceEpoch ~/ 30000;
  }

  // How many seconds until next QR refresh.
  int secondsUntilRefresh() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const windowMs = 30000;
    final msIntoWindow = now % windowMs;
    return ((windowMs - msIntoWindow) / 1000).ceil();
  }

  Future<Map<String, dynamic>?> getLabourProfile() async {
    try {
      final userDoc = await _db.collection('users').doc(labourUid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};

      final labourId = (userData['labourId'] as String?)?.trim();
      if (labourId != null && labourId.isNotEmpty) {
        final labourDoc = await _db.collection('labours').doc(labourId).get();
        if (labourDoc.exists) {
          return {
            ...labourDoc.data() ?? <String, dynamic>{},
            ...userData,
          };
        }
      }

      final phoneRaw = (userData['phone'] as String?) ?? _auth.currentUser?.phoneNumber ?? '';
      final phoneDigits = phoneRaw.replaceAll(RegExp(r'[^0-9]'), '');
      final normalized = phoneDigits.length == 12 && phoneDigits.startsWith('91')
          ? phoneDigits.substring(2)
          : (phoneDigits.length > 10 ? phoneDigits.substring(phoneDigits.length - 10) : phoneDigits);

      if (normalized.length == 10) {
        final labourSnap = await _db
            .collection('labours')
            .where('phone', isEqualTo: normalized)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (labourSnap.docs.isNotEmpty) {
          return {
            ...labourSnap.docs.first.data(),
            ...userData,
            'labourId': labourSnap.docs.first.id,
          };
        }
      }

      return userData.isEmpty ? null : userData;
    } catch (_) {
      return null;
    }
  }
}
