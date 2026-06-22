import 'package:flutter/foundation.dart';
import '../services/super_admin_service.dart';

class SuperAdminProvider extends ChangeNotifier {
  SuperAdminProvider() {
    _service = SuperAdminService();
  }

  late final SuperAdminService _service;

  SuperAdminStats? _stats;
  SuperAdminStats? get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _service.fetchDashboardStats();
    } catch (e) {
      _error = 'Failed to load stats: $e';
    }

    _isLoading = false;
    notifyListeners();
  }
}
