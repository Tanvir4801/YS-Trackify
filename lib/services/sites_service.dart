import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../models/site_model.dart';
import 'session_service.dart';

class SitesService {
  SitesService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Box<SiteModel>? box,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _box = box ?? Hive.box<SiteModel>(SiteModel.boxName);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Box<SiteModel> _box;

  String _contractorId() {
    final id = SessionService.instance.contractorId ?? _auth.currentUser?.uid ?? '';
    return id;
  }

  CollectionReference<Map<String, dynamic>> _col(String contractorId) =>
      _db.collection('sites');

  Future<List<SiteModel>> fetchSites() async {
    final contractorId = _contractorId();
    if (contractorId.isEmpty) return _localSites();

    try {
      // Avoid orderBy so no composite index is required — sort client-side.
      final snap = await _col(contractorId)
          .where('contractorId', isEqualTo: contractorId)
          .get();

      final sites = snap.docs
          .map(SiteModel.fromFirestore)
          .where((s) => s.isActive)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      for (final s in sites) {
        await _box.put(s.id, s);
      }
      return sites;
    } catch (e) {
      debugPrint('fetchSites error (falling back to local): $e');
      return _localSites();
    }
  }

  List<SiteModel> _localSites() =>
      _box.values.where((s) => s.isActive).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<SiteModel> addSite(String name, {String description = ''}) async {
    final contractorId = _contractorId();
    const uuid = Uuid();
    final id = uuid.v4();
    final site = SiteModel(
      id: id,
      name: name.trim(),
      contractorId: contractorId,
      description: description.trim(),
      isActive: true,
      createdAt: DateTime.now(),
    );

    final docRef = await _col(contractorId).add({...site.toFirestore(), 'id': ''});
    final firestoreId = docRef.id;
    await docRef.update({'id': firestoreId});
    final saved = SiteModel(
      id: firestoreId,
      name: site.name,
      contractorId: contractorId,
      description: site.description,
      isActive: true,
      createdAt: site.createdAt,
      firestoreId: firestoreId,
    );
    await _box.put(firestoreId, saved);
    return saved;
  }

  Future<void> updateSite(String siteId, {String? name, String? description}) async {
    final contractorId = _contractorId();
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (description != null) updates['description'] = description.trim();
    if (updates.isEmpty) return;

    await _col(contractorId).doc(siteId).update(updates);

    final local = _box.get(siteId);
    if (local != null) {
      final updated = SiteModel(
        id: local.id,
        name: name ?? local.name,
        contractorId: local.contractorId,
        description: description ?? local.description,
        isActive: local.isActive,
        createdAt: local.createdAt,
        firestoreId: local.firestoreId,
      );
      await _box.put(siteId, updated);
    }
  }

  Future<void> deleteSite(String siteId) async {
    final contractorId = _contractorId();
    await _col(contractorId).doc(siteId).update({'isActive': false});
    final local = _box.get(siteId);
    if (local != null) {
      final updated = SiteModel(
        id: local.id,
        name: local.name,
        contractorId: local.contractorId,
        description: local.description,
        isActive: false,
        createdAt: local.createdAt,
        firestoreId: local.firestoreId,
      );
      await _box.put(siteId, updated);
    }
  }

  Stream<List<SiteModel>> sitesStream() {
    final contractorId = _contractorId();
    if (contractorId.isEmpty) return Stream.value(_localSites());

    // No orderBy — avoids composite index requirement; sort client-side.
    return _col(contractorId)
        .where('contractorId', isEqualTo: contractorId)
        .snapshots()
        .map((snap) => snap.docs
            .map(SiteModel.fromFirestore)
            .where((s) => s.isActive)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  }
}
