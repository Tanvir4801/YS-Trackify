import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static final AppLockService _instance = AppLockService._();
  AppLockService._();
  static AppLockService get instance => _instance;

  static const _prefKey = 'app_lock_enabled';

  Future<bool> isLockEnabled() async {
    if (kIsWeb) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setLockEnabled(bool enabled) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  Future<bool> authenticate() async {
    if (kIsWeb) return true;
    debugPrint('[AppLockService] Biometric authentication not available on this platform.');
    return true;
  }

  bool get isBiometricSupported => !kIsWeb;
}
