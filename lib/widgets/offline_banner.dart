import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_provider.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);

    return connectivityState.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (results) {
        final offline = results.contains(ConnectivityResult.none);
        if (!offline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: Colors.amber.shade700,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: const SafeArea(
            bottom: false,
            child: Text(
              'Offline mode: changes will sync when internet is available',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
