import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/material_purchase_model.dart';
import '../models/site_expense_model.dart';
import '../models/supplier_model.dart';
import '../services/cost_management_service.dart';
import '../services/session_service.dart';

class CostManagementProvider extends ChangeNotifier {
  CostManagementProvider() {
    _service = CostManagementService();
  }

  late final CostManagementService _service;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<MaterialPurchaseModel> _materialPurchases = [];
  List<MaterialPurchaseModel> get materialPurchases => _materialPurchases;

  List<SiteExpenseModel> _siteExpenses = [];
  List<SiteExpenseModel> get siteExpenses => _siteExpenses;

  List<SupplierModel> _suppliers = [];
  List<SupplierModel> get suppliers => _suppliers;

  // Cache contractorId
  String get _contractorId {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return SessionService.instance.contractorId ?? uid;
  }

  // ── Data Fetching ──────────────────────────────────────────────────────────

  Future<void> loadDashboardData({String? siteId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cid = _contractorId;
      _materialPurchases = await _service.fetchMaterialPurchases(cid, siteId: siteId);
      _siteExpenses = await _service.fetchSiteExpenses(cid, siteId: siteId);
      _suppliers = await _service.fetchSuppliers(cid);
    } catch (e) {
      _error = 'Failed to load cost data: $e';
      debugPrint('[CostManagementProvider] $_error');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Operations ─────────────────────────────────────────────────────────────

  Future<bool> addMaterialPurchase(MaterialPurchaseModel purchase) async {
    try {
      await _service.saveMaterialPurchase(purchase);
      _materialPurchases.insert(0, purchase);
      
      // Update supplier locally if it matches
      if (purchase.supplierId.isNotEmpty) {
        final idx = _suppliers.indexWhere((s) => s.id == purchase.supplierId);
        if (idx != -1) {
          _suppliers[idx].totalPurchases += purchase.totalAmount;
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save material purchase: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addSiteExpense(SiteExpenseModel expense) async {
    try {
      await _service.saveSiteExpense(expense);
      _siteExpenses.insert(0, expense);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save site expense: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addSupplier(SupplierModel supplier) async {
    try {
      await _service.saveSupplier(supplier);
      _suppliers.add(supplier);
      _suppliers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save supplier: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordSupplierPayment(String supplierId, double amount) async {
    try {
      await _service.recordSupplierPayment(_contractorId, supplierId, amount);
      final idx = _suppliers.indexWhere((s) => s.id == supplierId);
      if (idx != -1) {
        _suppliers[idx].paidAmount += amount;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to record payment: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Aggregation ────────────────────────────────────────────────────────────

  double get totalMaterialCost {
    return _materialPurchases.fold(0, (sum, item) => sum + item.totalAmount);
  }

  double get totalMachineryCost {
    return _siteExpenses
        .where((e) => e.expenseType == 'machinery')
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get totalTransportCost {
    return _siteExpenses
        .where((e) => e.expenseType == 'transport')
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get totalMiscCost {
    return _siteExpenses
        .where((e) => e.expenseType == 'misc')
        .fold(0, (sum, item) => sum + item.amount);
  }
}
