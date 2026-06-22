import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import '../services/sync_engine.dart';

enum SyncStatus { synced, pending, syncing, error }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  final engine = SyncEngine(connectivityService: connectivityService);
  return engine;
});
