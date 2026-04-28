import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/qr_service.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({
    super.key,
    this.showAppBar = false,
  });

  final bool showAppBar;

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final QRService _qrService = QRService();
  Timer? _ticker;

  String _qrToken = '';
  int _secondsLeft = 30;
  int _activeWindow = -1;
  Map<String, dynamic>? _labourProfile;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      _labourProfile = await _qrService.getLabourProfile();
      _refreshTokenIfNeeded(force: true);
      _startTicker();
    } catch (e) {
      _error = 'Unable to load QR code. Please sign in again.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _secondsLeft = _qrService.secondsUntilRefresh();
      });
      _refreshTokenIfNeeded();
    });
  }

  void _refreshTokenIfNeeded({bool force = false}) {
    final currentWindow = _qrService.currentWindow();
    if (!force && currentWindow == _activeWindow) {
      return;
    }

    setState(() {
      _activeWindow = currentWindow;
      _qrToken = _qrService.generateQRToken();
      _secondsLeft = _qrService.secondsUntilRefresh();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final labourName = (_labourProfile?['name'] as String?)?.trim().isNotEmpty == true
        ? (_labourProfile?['name'] as String)
        : 'Labour';
    final phone = (_labourProfile?['phone'] as String?) ?? '';

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.14),
            child: Text(
              labourName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            labourName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              phone,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrToken,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.refresh,
                size: 16,
                color: _secondsLeft <= 5 ? AppColors.absent : AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Refreshes in $_secondsLeft seconds',
                style: TextStyle(
                  color: _secondsLeft <= 5 ? AppColors.absent : AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _secondsLeft / 30,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _secondsLeft <= 5 ? AppColors.absent : AppColors.present,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Show this QR code to your supervisor to mark your attendance. Display only: labour cannot self-mark attendance.',
                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return SafeArea(child: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR Code'),
        centerTitle: true,
      ),
      body: body,
    );
  }
}
