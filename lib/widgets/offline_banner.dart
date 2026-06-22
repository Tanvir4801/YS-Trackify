import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key, required this.child});
  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;
  StreamSubscription? _sub;
  bool _isOnline = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<double>(begin: -1, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline && mounted) {
        setState(() {
          _isOnline = online;
          _showBanner = true;
        });
        _animCtrl.forward();
        if (online) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _animCtrl.reverse().then((_) {
                if (mounted) setState(() => _showBanner = false);
              });
            }
          });
        }
      }
    });

    Connectivity().checkConnectivity().then((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online && mounted) {
        setState(() {
          _isOnline = false;
          _showBanner = true;
        });
        _animCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showBanner)
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  heightFactor: (_slideAnim.value + 1).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              color: _isOnline
                  ? const Color(0xFF059669)
                  : const Color(0xFFB91C1C),
              padding:
                  const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOnline
                        ? 'Back online — syncing data...'
                        : 'Offline — showing cached data',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
