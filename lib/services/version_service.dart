import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionCheckResult {
  final bool isValid;
  final bool maintenanceMode;
  final bool forceUpdate;
  final String message;

  VersionCheckResult({
    required this.isValid,
    this.maintenanceMode = false,
    this.forceUpdate = false,
    this.message = '',
  });
}

class VersionService {
  VersionService._();
  static final VersionService instance = VersionService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<VersionCheckResult> checkVersion() async {
    try {
      final snap = await _db.collection('app_configuration').doc('settings').get();
      if (!snap.exists) {
        return VersionCheckResult(isValid: true);
      }

      final data = snap.data()!;
      final maintenanceMode = data['maintenanceMode'] as bool? ?? false;
      
      if (maintenanceMode) {
        return VersionCheckResult(
          isValid: false,
          maintenanceMode: true,
          message: data['maintenanceMessage'] ?? 'System is under maintenance. Please try again later.',
        );
      }

      final minimumVersion = data['minimumVersion'] as String?;
      final forceUpdate = data['forceUpdate'] as bool? ?? false;

      if (minimumVersion != null && minimumVersion.isNotEmpty) {
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        
        if (_isUpdateRequired(currentVersion, minimumVersion)) {
          return VersionCheckResult(
            isValid: !forceUpdate, // If force update is true, version is invalid.
            forceUpdate: forceUpdate,
            message: 'A new version ($minimumVersion) is available. Please update the app.',
          );
        }
      }

      return VersionCheckResult(isValid: true);
    } catch (_) {
      return VersionCheckResult(isValid: true); // Fail open if offline
    }
  }

  bool _isUpdateRequired(String current, String minimum) {
    try {
      final v1 = current.split('.');
      final v2 = minimum.split('.');
      for (var i = 0; i < v2.length; i++) {
        if (i >= v1.length) return true;
        final p1 = int.tryParse(v1[i]) ?? 0;
        final p2 = int.tryParse(v2[i]) ?? 0;
        if (p1 < p2) return true;
        if (p1 > p2) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
