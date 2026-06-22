import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late StreamSubscription<List<ConnectivityResult>> _sub;
  bool _isOffline = false;
  bool _justReconnected = false;
  final int _pendingCount = 0; // To be integrated with SyncEngine if needed

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      
      if (isOffline && !_isOffline) {
        setState(() {
          _isOffline = true;
          _justReconnected = false;
        });
      } else if (!isOffline && _isOffline) {
        setState(() {
          _isOffline = false;
          _justReconnected = true;
        });
        // Auto-dismiss synced state after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _justReconnected = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Widget _buildBanner() {
    if (_isOffline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFFEF2F2),
          border: Border(bottom: BorderSide(color: Color(0xFFFECACA), width: 1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No internet connection',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            if (_pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_pendingCount pending sync',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
    } else if (_justReconnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFF0FDF4),
          border: Border(bottom: BorderSide(color: Color(0xFFBBF7D0), width: 1)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF22C55E)),
            SizedBox(width: 8),
            Text(
              'All synced. Back online!',
              style: TextStyle(color: Color(0xFF166534), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBanner(),
        Expanded(child: widget.child),
      ],
    );
  }
}
