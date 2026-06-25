import 'dart:async';
import 'dart:math' as math;

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

class _QRScreenState extends State<QRScreen> with SingleTickerProviderStateMixin {
  final QRService _qrService = QRService();
  Timer? _ticker;
  late AnimationController _pulseController;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
      if (mounted) setState(() => _isLoading = false);
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
    if (_resolvedLabourName.isEmpty) _resolvedLabourName = session?.name ?? 'Labour';
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
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) _refreshPayload();
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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0F766E), strokeWidth: 3),
            SizedBox(height: 16),
            Text('Loading QR Code…', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      );
    }

    final body = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        children: [
          // ── Name & Status ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _missingReason != null
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _missingReason != null
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      size: 14,
                      color: _missingReason != null
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _missingReason != null ? 'Not Configured' : 'Ready for Scan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _missingReason != null
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Main QR Card ─────────────────────────────────────────
          if (_missingReason != null)
            _MissingCard(reason: _missingReason!)
          else
            _QRCard(
              qrPayload: _qrPayload,
              secondsLeft: _secondsLeft,
              labourName: _resolvedLabourName,
              onRefresh: _refreshPayload,
            ),
          const SizedBox(height: 20),

          // ── Safety Note ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Security Notice', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E40AF), fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        'Show this QR to your supervisor for attendance. Only supervisors can scan. Never share your QR code with others.',
                        style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.showAppBar) return SafeArea(child: body);

    return Scaffold(
      appBar: AppBar(title: const Text('My QR Code'), centerTitle: true),
      body: body,
    );
  }
}

class _QRCard extends StatelessWidget {
  const _QRCard({
    required this.qrPayload,
    required this.secondsLeft,
    required this.labourName,
    required this.onRefresh,
  });

  final String qrPayload;
  final int secondsLeft;
  final String labourName;
  final VoidCallback onRefresh;

  static const _total = 60;

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft / _total;
    final isUrgent = secondsLeft <= 10;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    labourName.isNotEmpty ? labourName[0].toUpperCase() : 'L',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labourName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        'Attendance QR Code',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRefresh,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          // QR + Ring
          Padding(
            padding: const EdgeInsets.all(24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Countdown ring
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUrgent ? const Color(0xFFEF4444) : const Color(0xFF0F766E),
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // QR Code
                Container(
                  width: 240,
                  height: 240,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 212,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F172A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Countdown text
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUrgent
                          ? 'Refreshing in $secondsLeft seconds…'
                          : 'Refreshes in $secondsLeft seconds',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUrgent ? const Color(0xFFEF4444) : const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingCard extends StatelessWidget {
  const _MissingCard({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.crop_free_rounded, color: Color(0xFFEF4444), size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'QR Not Available',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF7F1D1D)),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_outlined, color: Color(0xFFEF4444), size: 16),
                SizedBox(width: 8),
                Text('Contact your Supervisor', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
