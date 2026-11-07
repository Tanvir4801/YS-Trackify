import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/house_plan_model.dart';
import '../services/house_plans_service.dart';
import '../services/notification_service.dart';
import '../services/session_service.dart';

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
  int get totalDrawingsCount => _allPlans.fold(0, (acc, o) => acc + o.totalPlansCount);
  int get pendingDrawingsCount => _allPlans.fold(0, (acc, o) => acc + o.inProgressDrawings.length);
  int get completedDrawingsCount => _allPlans.fold(0, (acc, o) => acc + o.completedDrawings.length);

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

        // Check and trigger reminder alert for the engineer
        if (planPendingCount > 0 || pendingDrawingsCount > 0 || visitDueCount > 0) {
          NotificationService.instance.checkAndTriggerPlansReminder(
            pendingPlansCount: planPendingCount,
            pendingDrawingsCount: pendingDrawingsCount,
            visitDueCount: visitDueCount,
          );
        }
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
    String? userRole,
    String? userName,
    String? userUid,
  }) async {
    final role = userRole ?? SessionService.instance.role ?? 'contractor';
    final name = userName ?? SessionService.instance.name ?? 'Supervisor';
    final uid = userUid ?? SessionService.instance.uid ?? '';

    // Optimistic in-memory update for 0ms instantaneous UI response
    final ownerIdx = _allPlans.indexWhere((o) => o.id == ownerId);
    if (ownerIdx != -1) {
      final owner = _allPlans[ownerIdx];
      final isSupervisor = role == 'supervisor';
      final updatedPlans = owner.plansList.map((p) {
        if (p.id == planId || p.name == planId) {
          return p.copyWith(
            status: newStatus,
            completedDate: newStatus == 'completed' ? DateTime.now().toIso8601String().split('T')[0] : null,
            verificationStatus: isSupervisor ? 'pending_admin_verification' : 'verified',
            modifiedByRole: role,
            modifiedByName: name,
            modifiedByUid: uid,
            modifiedAt: DateTime.now().toIso8601String(),
          );
        }
        return p;
      }).toList();

      _allPlans[ownerIdx] = owner.copyWith(plansList: updatedPlans);
      notifyListeners();
    }

    try {
      await _service.updateDrawingStatus(
        ownerId: ownerId,
        planId: planId,
        newStatus: newStatus,
        userRole: role,
        userName: name,
        userUid: uid,
      );
    } catch (e) {
      debugPrint('[HousePlansProvider] updateDrawingStatus error: $e');
    }
  }

  Future<void> addSiteVisit({
    required String ownerId,
    required HouseSiteVisit visit,
    String? userRole,
    String? userName,
    String? userUid,
  }) async {
    final role = userRole ?? SessionService.instance.role ?? 'contractor';
    final name = userName ?? SessionService.instance.name ?? 'Supervisor';
    final uid = userUid ?? SessionService.instance.uid ?? '';

    await _service.addSiteVisit(
      ownerId: ownerId,
      visit: visit,
      userRole: role,
      userName: name,
      userUid: uid,
    );
  }

  Future<void> deleteSiteVisit({
    required String ownerId,
    required String visitId,
  }) async {
    // Optimistic deletion
    final ownerIdx = _allPlans.indexWhere((o) => o.id == ownerId);
    if (ownerIdx != -1) {
      final owner = _allPlans[ownerIdx];
      final updatedVisits = owner.siteVisits.where((v) => v.id != visitId).toList();
      _allPlans[ownerIdx] = owner.copyWith(siteVisits: updatedVisits);
      notifyListeners();
    }

    await _service.deleteSiteVisit(
      ownerId: ownerId,
      visitId: visitId,
    );
  }

  /// Admin 2-Factor Verification: Approve a specific drawing changed by supervisor.
  Future<void> verifyDrawingChange({
    required String ownerId,
    required String planId,
  }) async {
    final uid = SessionService.instance.uid ?? '';
    final name = SessionService.instance.name ?? 'Admin';

    // Optimistic approval
    final ownerIdx = _allPlans.indexWhere((o) => o.id == ownerId);
    if (ownerIdx != -1) {
      final owner = _allPlans[ownerIdx];
      final updatedPlans = owner.plansList.map((p) {
        if (p.id == planId || p.name == planId) {
          return p.copyWith(verificationStatus: 'verified');
        }
        return p;
      }).toList();
      _allPlans[ownerIdx] = owner.copyWith(plansList: updatedPlans);
      notifyListeners();
    }

    await _service.verifyDrawingChange(
      ownerId: ownerId,
      planId: planId,
      adminUid: uid,
      adminName: name,
    );
  }

  /// Admin 2-Factor Verification: Approve a site visit logged by supervisor.
  Future<void> verifySiteVisit({
    required String ownerId,
    required String visitId,
  }) async {
    final uid = SessionService.instance.uid ?? '';
    final name = SessionService.instance.name ?? 'Admin';

    // Optimistic approval
    final ownerIdx = _allPlans.indexWhere((o) => o.id == ownerId);
    if (ownerIdx != -1) {
      final owner = _allPlans[ownerIdx];
      final updatedVisits = owner.siteVisits.map((v) {
        if (v.id == visitId) {
          return v.copyWith(verificationStatus: 'verified');
        }
        return v;
      }).toList();
      _allPlans[ownerIdx] = owner.copyWith(siteVisits: updatedVisits);
      notifyListeners();
    }

    await _service.verifySiteVisit(
      ownerId: ownerId,
      visitId: visitId,
      adminUid: uid,
      adminName: name,
    );
  }

  /// Admin 2-Factor Verification: Approve ALL pending changes for an owner.
  Future<void> verifyAllPendingChanges({
    required String ownerId,
  }) async {
    final uid = SessionService.instance.uid ?? '';
    final name = SessionService.instance.name ?? 'Admin';
    await _service.verifyAllPendingChanges(
      ownerId: ownerId,
      adminUid: uid,
      adminName: name,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

