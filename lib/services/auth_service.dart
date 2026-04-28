import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'firestore_paths.dart';
import 'session_service.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<void> sendOTP({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    final normalizedPhone = _normalizeIndianPhone(phone);
    if (normalizedPhone == null) {
      onError('Enter valid 10 digit mobile number');
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$normalizedPhone',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          onAutoVerify(credential);
        },
        verificationFailed: (e) {
          debugPrint('OTP Error: ${e.code} - ${e.message}');
          String message;
          switch (e.code) {
            case 'invalid-phone-number':
              message = 'Invalid phone number format';
              break;
            case 'too-many-requests':
              message = 'Too many attempts. Try after some time.';
              break;
            case 'quota-exceeded':
              message = 'SMS quota exceeded. Try later.';
              break;
            default:
              message = e.message ?? 'Failed to send OTP';
          }
          onError(message);
        },
        codeSent: (verificationId, resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          debugPrint('OTP timeout: $verificationId');
        },
      );
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? 'Failed to send OTP');
    } catch (_) {
      onError('Failed to send OTP');
    }
  }

  Future<AuthResult> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Login failed. Try again.');
      }
      return _fetchUserRole(user.uid, user.phoneNumber ?? '');
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-verification-code':
          return AuthResult.error('Wrong OTP. Please check and retry.');
        case 'session-expired':
          return AuthResult.error('OTP expired. Request a new one.');
        default:
          return AuthResult.error(e.message ?? 'Verification failed');
      }
    } catch (_) {
      return AuthResult.error('Verification failed');
    }
  }

  Future<AuthResult> signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Login failed');
      }
      return _fetchUserRole(user.uid, user.phoneNumber ?? '');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(e.message ?? 'Auto verification failed');
    } catch (_) {
      return AuthResult.error('Auto verification failed');
    }
  }

  Future<AuthResult> _fetchUserRole(String uid, String phone) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final role = (data['role'] as String? ?? '').trim();
        final isActive = data['isActive'] as bool? ?? true;
        final name = (data['name'] as String? ?? '').trim();
        final phoneClean = _phoneDigits((data['phone'] as String?) ?? phone);

        if (!isActive) {
          await _auth.signOut();
          return AuthResult.error('Your account is disabled.');
        }

        if (role.isEmpty) {
          await _auth.signOut();
          return AuthResult.error('Unknown role. Contact admin.');
        }

        if (role == 'labour' && ((data['labourId'] as String?) ?? '').trim().isEmpty) {
          final labourSnap = await _db
              .collection('labours')
              .where('phone', isEqualTo: phoneClean)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

          if (labourSnap.docs.isNotEmpty) {
            final labourDoc = labourSnap.docs.first;
            final labourData = labourDoc.data();
            final supId = (labourData['supervisorId'] as String? ?? '').trim();
            final contractorIdFromLabour =
                (labourData['contractorId'] as String? ?? '').trim();
            await _db.collection('users').doc(uid).set({
              'labourId': labourDoc.id,
              'supervisorId': supId,
              if (contractorIdFromLabour.isNotEmpty)
                'contractorId': contractorIdFromLabour,
              'phone': phoneClean,
              'uid': uid,
            }, SetOptions(merge: true));
          }
        }

        final refreshed = await _db.collection('users').doc(uid).get();
        final freshData = refreshed.data() ?? data;
        final appUser = await _buildAppUser(uid, freshData, phoneClean);
        SessionService.instance.set(appUser);

        await _cacheUserData(uid, role, name, phoneClean,
            contractorId: appUser.contractorId);
        return AuthResult.success(
          uid: uid,
          role: role,
          name: name,
          appUser: appUser,
        );
      }

      final phoneClean = _phoneDigits(phone);
      final phoneSnap = await _db
          .collection('users')
          .where('phone', isEqualTo: phoneClean)
          .limit(1)
          .get();

      if (phoneSnap.docs.isNotEmpty) {
        final doc = phoneSnap.docs.first;
        final data = doc.data();
        final role = (data['role'] as String? ?? '').trim();
        final name = (data['name'] as String? ?? '').trim();
        final isActive = data['isActive'] as bool? ?? true;

        if (!isActive) {
          await _auth.signOut();
          return AuthResult.error('Your account is disabled.');
        }

        await _db.collection('users').doc(uid).set({
          ...data,
          'uid': uid,
          'phone': phoneClean,
        }, SetOptions(merge: true));

        if (doc.id != uid) {
          await doc.reference.delete();
        }

        final refreshed = await _db.collection('users').doc(uid).get();
        final freshData = refreshed.data() ?? data;
        final appUser = await _buildAppUser(uid, freshData, phoneClean);
        SessionService.instance.set(appUser);

        await _cacheUserData(uid, role, name, phoneClean,
            contractorId: appUser.contractorId);
        return AuthResult.success(
          uid: uid,
          role: role,
          name: name,
          appUser: appUser,
        );
      }

      final labourSnap = await _db
          .collection('labours')
          .where('phone', isEqualTo: phoneClean)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (labourSnap.docs.isNotEmpty) {
        final labourData = labourSnap.docs.first.data();
        final name = (labourData['name'] as String? ?? 'Labour').trim();
        final supId = (labourData['supervisorId'] as String? ?? '').trim();
        final contractorIdFromLabour =
            (labourData['contractorId'] as String? ?? '').trim();

        await _db.collection('users').doc(uid).set({
          'uid': uid,
          'phone': phoneClean,
          'name': name,
          'role': 'labour',
          'isActive': true,
          'supervisorId': supId,
          if (contractorIdFromLabour.isNotEmpty)
            'contractorId': contractorIdFromLabour,
          'labourId': labourSnap.docs.first.id,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final refreshed = await _db.collection('users').doc(uid).get();
        final freshData = refreshed.data() ?? <String, dynamic>{};
        final appUser = await _buildAppUser(uid, freshData, phoneClean);
        SessionService.instance.set(appUser);

        await _cacheUserData(uid, 'labour', name, phoneClean,
            contractorId: appUser.contractorId);
        return AuthResult.success(
          uid: uid,
          role: 'labour',
          name: name,
          appUser: appUser,
        );
      }

      await _auth.signOut();
      return AuthResult.error('Mobile number not registered.\nContact your supervisor.');
    } catch (e) {
      debugPrint('fetchUserRole error: $e');
      final cached = await _getCachedRole();
      if (cached != null) {
        return AuthResult.success(
          uid: uid,
          role: cached['role']!,
          name: cached['name']!,
          fromCache: true,
        );
      }
      return AuthResult.error('Network error. Check internet connection.');
    }
  }

  /// Build an AppUser by resolving contractorId with priority:
  /// user.contractorId → labour.contractorId → user.supervisorId → uid.
  Future<AppUser> _buildAppUser(
    String uid,
    Map<String, dynamic> userData,
    String phoneClean,
  ) async {
    final role = (userData['role'] as String? ?? '').trim();
    final name = (userData['name'] as String? ?? '').trim();
    final labourId = (userData['labourId'] as String? ?? '').trim();
    final supervisorId = (userData['supervisorId'] as String? ?? '').trim();
    final isActive = userData['isActive'] as bool? ?? true;

    var contractorId = (userData['contractorId'] as String? ?? '').trim();

    if (contractorId.isEmpty && labourId.isNotEmpty) {
      try {
        final labourDoc = await _db.collection('labours').doc(labourId).get();
        final ld = labourDoc.data();
        if (ld != null) {
          contractorId = (ld['contractorId'] as String? ?? '').trim();
        }
      } catch (_) {/* fall through to next fallback */}
    }

    if (contractorId.isEmpty && supervisorId.isNotEmpty) {
      contractorId = supervisorId;
    }
    if (contractorId.isEmpty) {
      // Final fallback: supervisors who pre-date contractor concept act as
      // their own contractor (so new nested attendance writes keep working).
      contractorId = uid;
    }

    final supervisorRefId = supervisorId.isNotEmpty ? supervisorId : uid;
    return AppUser(
      uid: uid,
      role: role,
      contractorId: contractorId,
      supervisorId: supervisorId,
      supervisorRef: FirestorePaths.userRef(supervisorRefId),
      labourId: labourId,
      name: name,
      phone: phoneClean,
      isActive: isActive,
    );
  }

  Future<AuthResult?> checkCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    return _fetchUserRole(user.uid, user.phoneNumber ?? '');
  }

  Future<void> logout() async {
    await _auth.signOut();
    SessionService.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('User logged out and cache cleared');
  }

  Future<void> _cacheUserData(
    String uid,
    String role,
    String name,
    String phone, {
    String contractorId = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', uid);
    await prefs.setString('role', role);
    await prefs.setString('name', name);
    await prefs.setString('phone', phone);
    if (contractorId.isNotEmpty) {
      await prefs.setString('contractorId', contractorId);
    }
  }

  Future<Map<String, String>?> _getCachedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final name = prefs.getString('name');
    if (role == null || role.isEmpty) {
      return null;
    }
    return {'role': role, 'name': name ?? ''};
  }

  String? _normalizeIndianPhone(String phone) {
    final digits = _phoneDigits(phone);
    if (digits.length != 10) {
      return null;
    }
    return digits;
  }

  String _phoneDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }
}

class AuthResult {
  AuthResult._({
    required this.success,
    this.uid,
    this.role,
    this.name,
    this.errorMessage,
    this.fromCache = false,
    this.appUser,
  });

  final bool success;
  final String? uid;
  final String? role;
  final String? name;
  final String? errorMessage;
  final bool fromCache;
  final AppUser? appUser;

  factory AuthResult.success({
    required String uid,
    required String role,
    required String name,
    bool fromCache = false,
    AppUser? appUser,
  }) {
    return AuthResult._(
      success: true,
      uid: uid,
      role: role,
      name: name,
      fromCache: fromCache,
      appUser: appUser,
    );
  }

  factory AuthResult.error(String message) {
    return AuthResult._(
      success: false,
      errorMessage: message,
    );
  }
}
