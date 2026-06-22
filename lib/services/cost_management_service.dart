import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/material_purchase_model.dart';
import '../models/site_expense_model.dart';
import '../models/supplier_model.dart';

class CostManagementService {
  CostManagementService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Material Purchases ─────────────────────────────────────────────────────

  Future<void> saveMaterialPurchase(MaterialPurchaseModel purchase) async {
    final box = Hive.box<MaterialPurchaseModel>(MaterialPurchaseModel.boxName);
    await box.put(purchase.id, purchase);

    try {
      await _db
          .collection('materialPurchases')
          .doc(purchase.contractorId)
          .collection('purchases')
          .doc(purchase.id)
          .set(purchase.toFirestore());

      // Update supplier total purchases
      if (purchase.supplierId.isNotEmpty) {
        await updateSupplierTotal(purchase.contractorId, purchase.supplierId, purchase.totalAmount);
      }
    } catch (e) {
      debugPrint('[CostManagementService] Material purchase sync failed: $e');
    }
  }

  Future<List<MaterialPurchaseModel>> fetchMaterialPurchases(String contractorId, {String? siteId}) async {
    final box = Hive.box<MaterialPurchaseModel>(MaterialPurchaseModel.boxName);
    var local = box.values.where((e) => e.contractorId == contractorId).toList();

    if (siteId != null && siteId.isNotEmpty) {
      local = local.where((e) => e.siteId == siteId).toList();
    }

    try {
      Query query = _db.collection('materialPurchases').doc(contractorId).collection('purchases');
      if (siteId != null && siteId.isNotEmpty) {
        query = query.where('siteId', isEqualTo: siteId);
      }
      final snap = await query.get();
      final remoteIds = snap.docs.map((doc) => doc.id).toSet();

      final scopedLocal = box.values.where((e) =>
          e.contractorId == contractorId &&
          (siteId == null || siteId.isEmpty || e.siteId == siteId)).toList();

      for (final item in scopedLocal) {
        if (!remoteIds.contains(item.id)) {
          await box.delete(item.id);
        }
      }

      local = box.values.where((e) =>
          e.contractorId == contractorId &&
          (siteId == null || siteId.isEmpty || e.siteId == siteId)).toList();

      for (final doc in snap.docs) {
        final m = MaterialPurchaseModel.fromFirestore(doc);
        await box.put(m.id, m);
        final idx = local.indexWhere((e) => e.id == m.id);
        if (idx == -1) {
          local.add(m);
        } else {
          local[idx] = m;
        }
      }
    } catch (e) {
      debugPrint('[CostManagementService] Fetch material purchases failed: $e');
    }

    local.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return local;
  }

  // ── Site Expenses ──────────────────────────────────────────────────────────

  Future<void> saveSiteExpense(SiteExpenseModel expense) async {
    final box = Hive.box<SiteExpenseModel>(SiteExpenseModel.boxName);
    await box.put(expense.id, expense);

    try {
      await _db
          .collection('siteExpenses')
          .doc(expense.contractorId)
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toFirestore());
    } catch (e) {
      debugPrint('[CostManagementService] Site expense sync failed: $e');
    }
  }

  Future<List<SiteExpenseModel>> fetchSiteExpenses(String contractorId, {String? siteId}) async {
    final box = Hive.box<SiteExpenseModel>(SiteExpenseModel.boxName);
    var local = box.values.where((e) => e.contractorId == contractorId).toList();

    if (siteId != null && siteId.isNotEmpty) {
      local = local.where((e) => e.siteId == siteId).toList();
    }

    try {
      Query query = _db.collection('siteExpenses').doc(contractorId).collection('expenses');
      if (siteId != null && siteId.isNotEmpty) {
        query = query.where('siteId', isEqualTo: siteId);
      }
      final snap = await query.get();
      final remoteIds = snap.docs.map((doc) => doc.id).toSet();

      final scopedLocal = box.values.where((e) =>
          e.contractorId == contractorId &&
          (siteId == null || siteId.isEmpty || e.siteId == siteId)).toList();

      for (final item in scopedLocal) {
        if (!remoteIds.contains(item.id)) {
          await box.delete(item.id);
        }
      }

      local = box.values.where((e) =>
          e.contractorId == contractorId &&
          (siteId == null || siteId.isEmpty || e.siteId == siteId)).toList();

      for (final doc in snap.docs) {
        final m = SiteExpenseModel.fromFirestore(doc);
        await box.put(m.id, m);
        final idx = local.indexWhere((e) => e.id == m.id);
        if (idx == -1) {
          local.add(m);
        } else {
          local[idx] = m;
        }
      }
    } catch (e) {
      debugPrint('[CostManagementService] Fetch site expenses failed: $e');
    }

    local.sort((a, b) => b.date.compareTo(a.date));
    return local;
  }

  // ── Suppliers ──────────────────────────────────────────────────────────────

  Future<void> saveSupplier(SupplierModel supplier) async {
    final box = Hive.box<SupplierModel>(SupplierModel.boxName);
    await box.put(supplier.id, supplier);

    try {
      await _db
          .collection('suppliers')
          .doc(supplier.contractorId)
          .collection('records')
          .doc(supplier.id)
          .set(supplier.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[CostManagementService] Supplier sync failed: $e');
    }
  }

  Future<List<SupplierModel>> fetchSuppliers(String contractorId) async {
    final box = Hive.box<SupplierModel>(SupplierModel.boxName);
    var local = box.values.where((e) => e.contractorId == contractorId).toList();

    try {
      final snap = await _db
          .collection('suppliers')
          .doc(contractorId)
          .collection('records')
          .get();
      final remoteIds = snap.docs.map((doc) => doc.id).toSet();

      final scopedLocal = box.values.where((e) => e.contractorId == contractorId).toList();
      for (final item in scopedLocal) {
        if (!remoteIds.contains(item.id)) {
          await box.delete(item.id);
        }
      }

      local = box.values.where((e) => e.contractorId == contractorId).toList();

      for (final doc in snap.docs) {
        final s = SupplierModel.fromFirestore(doc);
        await box.put(s.id, s);
        final idx = local.indexWhere((e) => e.id == s.id);
        if (idx == -1) {
          local.add(s);
        } else {
          local[idx] = s; // update local with remote (in case totals changed)
        }
      }
    } catch (e) {
      debugPrint('[CostManagementService] Fetch suppliers failed: $e');
    }

    local.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return local;
  }

  Future<void> updateSupplierTotal(String contractorId, String supplierId, double addedAmount) async {
    try {
      final docRef = _db
          .collection('suppliers')
          .doc(contractorId)
          .collection('records')
          .doc(supplierId);
      
      await docRef.update({
        'totalPurchases': FieldValue.increment(addedAmount),
      });

      // Also update local Hive box if it exists
      final box = Hive.box<SupplierModel>(SupplierModel.boxName);
      final sup = box.get(supplierId);
      if (sup != null) {
        sup.totalPurchases += addedAmount;
        await sup.save();
      }
    } catch (e) {
      debugPrint('[CostManagementService] Update supplier total failed: $e');
    }
  }

  Future<void> recordSupplierPayment(String contractorId, String supplierId, double paymentAmount) async {
    try {
      final docRef = _db
          .collection('suppliers')
          .doc(contractorId)
          .collection('records')
          .doc(supplierId);
      
      await docRef.update({
        'paidAmount': FieldValue.increment(paymentAmount),
      });

      // Also update local Hive box if it exists
      final box = Hive.box<SupplierModel>(SupplierModel.boxName);
      final sup = box.get(supplierId);
      if (sup != null) {
        sup.paidAmount += paymentAmount;
        await sup.save();
      }
    } catch (e) {
      debugPrint('[CostManagementService] Record supplier payment failed: $e');
    }
  }
}
