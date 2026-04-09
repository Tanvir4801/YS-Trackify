import 'package:shared_preferences/shared_preferences.dart';

class SupervisorAuthService {
  static const String _pinKey = 'supervisor_pin';
  static const String defaultPin = '1234';

  Future<void> ensureDefaultPin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_pinKey)) {
      await prefs.setString(_pinKey, defaultPin);
    }
  }

  Future<bool> validatePin(String inputPin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_pinKey) ?? defaultPin;
    return inputPin == savedPin;
  }

  Future<void> setPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, newPin);
  }
}
