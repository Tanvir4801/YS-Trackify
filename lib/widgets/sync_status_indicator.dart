import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_provider.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    switch (status) {
      case SyncStatus.synced:
        return const Tooltip(
          message: 'Synced',
          child: Icon(Icons.cloud_done, color: Colors.green),
        );
      case SyncStatus.pending:
        return const Tooltip(
          message: 'Pending sync',
          child: Icon(Icons.cloud_queue, color: Colors.orange),
        );
      case SyncStatus.syncing:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.error:
        return const Tooltip(
          message: 'Sync error',
          child: Icon(Icons.cloud_off, color: Colors.red),
        );
    }
  }
}
