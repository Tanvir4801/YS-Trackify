import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/qr_service.dart';
import '../../services/session_service.dart';

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

  static const Duration _qrLifetime = Duration(seconds: 60);

  String _qrPayload = '';
  int _secondsLeft = _qrLifetime.inSeconds;
  Map<String, dynamic>? _labourProfile;
  String _resolvedLabourId = '';
  String _resolvedContractorId = '';
  String _resolvedLabourName = 'Labour';
  String? _missingReason;

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
      _resolveLabourFields();
      _refreshPayload();
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

  void _resolveLabourFields() {
    final session = SessionService.instance.current;
    final p = _labourProfile ?? const <String, dynamic>{};

    _resolvedLabourId = ((p['labourId'] as String?) ?? '').trim();
    if (_resolvedLabourId.isEmpty && session != null) {
      _resolvedLabourId = session.labourId;
    }

    _resolvedContractorId = ((p['contractorId'] as String?) ?? '').trim();
    if (_resolvedContractorId.isEmpty && session != null) {
      _resolvedContractorId = session.contractorId;
    }

    _resolvedLabourName = ((p['name'] as String?) ?? '').trim();
    if (_resolvedLabourName.isEmpty) {
      _resolvedLabourName = session?.name ?? 'Labour';
    }
    if (_resolvedLabourName.isEmpty) _resolvedLabourName = 'Labour';

    if (_resolvedLabourId.isEmpty) {
      _missingReason = 'Labour profile not linked. Contact your supervisor.';
    } else if (_resolvedContractorId.isEmpty) {
      _missingReason = 'Contractor not assigned yet. Contact your supervisor.';
    } else {
      _missingReason = null;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft -= 1;
      });
      if (_secondsLeft <= 0) {
        _refreshPayload();
      }
    });
  }

  void _refreshPayload() {
    if (_missingReason != null) return;
    setState(() {
      _qrPayload = _qrService.generateJsonQrPayload(
        labourId: _resolvedLabourId,
        contractorId: _resolvedContractorId,
        labourName: _resolvedLabourName,
        lifetime: _qrLifetime,
      );
      _secondsLeft = _qrLifetime.inSeconds;
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

    final phone = (_labourProfile?['phone'] as String?) ?? '';

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.14),
            child: Text(
              _resolvedLabourName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _resolvedLabourName,
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
          if (_missingReason != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _missingReason!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.absent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
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
                data: _qrPayload,
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
                value: _secondsLeft / _qrLifetime.inSeconds,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _secondsLeft <= 5 ? AppColors.absent : AppColors.present,
                ),
              ),
            ),
          ],
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
