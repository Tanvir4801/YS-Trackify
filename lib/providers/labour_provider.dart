import 'package:flutter/foundation.dart';

import '../models/labour_model.dart';
import '../services/labour_service.dart';

class LabourProvider extends ChangeNotifier {
  LabourProvider({LabourService? service}) : _service = service ?? LabourService();

  final LabourService _service;

  List<Labour> labours = <Labour>[];
  List<Labour> filteredLabours = <Labour>[];
  bool isLoading = false;
  String searchQuery = '';
  String? error;

  Future<void> initialize() async {
    labours = _service.getLocalLabours();
    filteredLabours = labours;
    notifyListeners();

    await fetchFromFirebase();
  }

  Future<void> fetchFromFirebase() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _service.fetchAndSyncLabours();
      labours = _service.getLocalLabours();
      _applySearch();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLabour(Labour labour) async {
    try {
      await _service.addLabour(labour);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      labours = _service.getLocalLabours();
      _applySearch();
      notifyListeners();
    }
  }

  Future<void> updateLabour(Labour labour) async {
    try {
      await _service.updateLabour(labour);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      labours = _service.getLocalLabours();
      _applySearch();
      notifyListeners();
    }
  }

  Future<void> deleteLabour(Labour labour) async {
    try {
      await _service.deleteLabour(labour);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      labours = _service.getLocalLabours();
      _applySearch();
      notifyListeners();
    }
  }

  void search(String query) {
    searchQuery = query;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    if (searchQuery.isEmpty) {
      filteredLabours = labours;
      return;
    }

    filteredLabours = _service.searchLabours(searchQuery);
  }
}
