import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/house_plan_model.dart';
import '../services/house_plans_service.dart';

class HousePlansProvider extends ChangeNotifier {
  final HousePlansService _service;

  HousePlansProvider({HousePlansService? service})
      : _service = service ?? HousePlansService.instance;

  StreamSubscription<List<HousePlanOwner>>? _sub;

  List<HousePlanOwner> _allPlans = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'visit_due', 'plan_pending', 'cleared'
  String? _lastContractorId;

  List<HousePlanOwner> get allPlans => _allPlans;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;

  int get totalClientsCount => _allPlans.length;
  int get visitDueCount => _allPlans.where((o) => o.siteVisits.isNotEmpty && !o.isVisitsCleared).length;
  int get planPendingCount => _allPlans.where((o) => !o.isPlanFeeCleared).length;
  int get clearedCount => _allPlans.where((o) => o.isFullyCleared).length;

  List<HousePlanOwner> get filteredPlans {
    var list = _allPlans;

    // Apply Filter Tab
    if (_selectedFilter == 'visit_due') {
      list = list.where((o) => o.siteVisits.isNotEmpty && !o.isVisitsCleared).toList();
    } else if (_selectedFilter == 'plan_pending') {
      list = list.where((o) => !o.isPlanFeeCleared).toList();
    } else if (_selectedFilter == 'cleared') {
      list = list.where((o) => o.isFullyCleared).toList();
    }

    // Apply Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((o) {
        return o.ownerName.toLowerCase().contains(q) ||
            o.villageCity.toLowerCase().contains(q) ||
            o.ownerPhone.contains(q) ||
            o.planNo.toLowerCase().contains(q) ||
            o.serial3D.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  void startListening(String contractorId) {
    if (contractorId.isEmpty) {
      _isLoading = false;
      _allPlans = [];
      notifyListeners();
      return;
    }

    if (_lastContractorId == contractorId && _sub != null) {
      return; // Already streaming
    }

    _lastContractorId = contractorId;
    _isLoading = true;
    notifyListeners();

    _sub?.cancel();
    _sub = _service.streamHousePlans(contractorId).listen(
      (plans) {
        _allPlans = plans;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('[HousePlansProvider] Stream error: $err');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> toggleDrawingStatus({
    required String ownerId,
    required String planId,
    required String newStatus,
  }) async {
    await _service.updateDrawingStatus(
      ownerId: ownerId,
      planId: planId,
      newStatus: newStatus,
    );
  }

  Future<void> addSiteVisit({
    required String ownerId,
    required HouseSiteVisit visit,
  }) async {
    await _service.addSiteVisit(
      ownerId: ownerId,
      visit: visit,
    );
  }

  Future<void> deleteSiteVisit({
    required String ownerId,
    required String visitId,
  }) async {
    await _service.deleteSiteVisit(
      ownerId: ownerId,
      visitId: visitId,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

