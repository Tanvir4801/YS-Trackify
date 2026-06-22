import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/site_model.dart';
import '../services/sites_service.dart';

class SitesProvider extends ChangeNotifier {
  SitesProvider({SitesService? service})
      : _service = service ?? SitesService();

  final SitesService _service;

  List<SiteModel> sites = <SiteModel>[];
  bool isLoading = false;
  String? error;
  StreamSubscription<List<SiteModel>>? _stream;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      sites = await _service.fetchSites();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
    _startStream();
  }

  void _startStream() {
    _stream?.cancel();
    _stream = _service.sitesStream().listen(
      (list) {
        sites = list;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<SiteModel> addSite(String name, {String description = ''}) async {
    final site = await _service.addSite(name, description: description);
    sites = [...sites, site]..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return site;
  }

  Future<void> updateSite(String siteId, {String? name, String? description}) async {
    await _service.updateSite(siteId, name: name, description: description);
    sites = sites.map((s) {
      if (s.id == siteId) {
        return SiteModel(
          id: s.id,
          name: name ?? s.name,
          contractorId: s.contractorId,
          description: description ?? s.description,
          isActive: s.isActive,
          createdAt: s.createdAt,
          firestoreId: s.firestoreId,
        );
      }
      return s;
    }).toList();
    notifyListeners();
  }

  Future<void> deleteSite(String siteId) async {
    await _service.deleteSite(siteId);
    sites = sites.where((s) => s.id != siteId).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _stream?.cancel();
    super.dispose();
  }
}
