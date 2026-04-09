import 'package:shared_preferences/shared_preferences.dart';

import '../../models/labour.dart';
import '../hive_service.dart';

class LabourAuthService {
  LabourAuthService({required HiveService hiveService})
      : _hiveService = hiveService;

  static const String labourSessionKey = 'labour_session_id';

  final HiveService _hiveService;

  Future<Labour?> loginWithMobile(String inputMobile) async {
    final labour = _hiveService.getLabourByPhoneNumber(inputMobile);
    if (labour == null) {
      return null;
    }

    await saveSessionLabourId(labour.id);
    return labour;
  }

  Future<void> saveSessionLabourId(String labourId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(labourSessionKey, labourId);
  }

  Future<String?> getSessionLabourId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(labourSessionKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(labourSessionKey);
  }

  Future<Labour?> getSessionLabour() async {
    final labourId = await getSessionLabourId();
    if (labourId == null || labourId.isEmpty) {
      return null;
    }

    return _hiveService.getLabourById(labourId);
  }

  bool isValidMobile(String input) {
    final digits = normalizeMobile(input);
    return digits.length == 10;
  }

  String normalizeMobile(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }

    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }

    return digits;
  }
}