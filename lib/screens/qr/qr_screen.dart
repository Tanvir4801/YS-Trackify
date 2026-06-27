import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/qr_service.dart';
import '../../services/session_service.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({super.key, this.showAppBar = false});
  final bool showAppBar;

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen>
    with TickerProviderStateMixin {
  final QRService _qrService = QRService();
  Timer? _ticker;

  // Animations
  late final AnimationController _pulseCtrl;
  late final AnimationController _spinCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  static const int _totalSeconds = 60;

  String _qrPayload = '';
  int _secondsLeft = _totalSeconds;
  String _resolvedLabourId     = '';
  String _resolvedContractorId = '';
  String _resolvedLabourName   = 'Labour';
  String? _missingReason;

  bool _isLoading   = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1,
    );

    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      final profile = await _qrService.getLabourProfile();
      _resolveLabourFields(profile);
      _refreshPayload();
      _startTicker();
    } catch (e) {
      _error = 'Unable to load QR code. Please sign in again.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resolveLabourFields(Map<String, dynamic>? p) {
    final session = SessionService.instance.current;
    final data = p ?? const <String, dynamic>{};

    _resolvedLabourId = ((data['labourId'] as String?) ?? '').trim();
    if (_resolvedLabourId.isEmpty && session != null) {
      _resolvedLabourId = session.labourId;
    }

    _resolvedContractorId = ((data['contractorId'] as String?) ?? '').trim();
    if (_resolvedContractorId.isEmpty && session != null) {
      _resolvedContractorId = session.contractorId;
    }

    _resolvedLabourName = ((data['name'] as String?) ?? '').trim();
    if (_resolvedLabourName.isEmpty) {
      _resolvedLabourName = session?.name ?? 'Labour';
    }

    _missingReason = _resolvedLabourId.isEmpty
        ? 'Labour profile not linked. Contact your supervisor.'
        : _resolvedContractorId.isEmpty
            ? 'Contractor not assigned yet. Contact your supervisor.'
            : null;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) _doRefresh();
    });
  }

  Future<void> _doRefresh() async {
    if (_missingReason != null || _isRefreshing) return;
    setState(() => _isRefreshing = true);

    // Fade out → swap payload → fade in
    await _fadeCtrl.reverse();
    _spinCtrl.forward(from: 0);

    setState(() {
      _qrPayload    = _qrService.generateJsonQrPayload(
        labourId:     _resolvedLabourId,
        contractorId: _resolvedContractorId,
        labourName:   _resolvedLabourName,
        lifetime:     const Duration(seconds: _totalSeconds),
      );
      _secondsLeft  = _totalSeconds;
      _isRefreshing = false;
    });

    await _fadeCtrl.forward();
  }

  void _refreshPayload() {
    if (_missingReason != null) return;
    _qrPayload = _qrService.generateJsonQrPayload(
      labourId:     _resolvedLabourId,
      contractorId: _resolvedContractorId,
      labourName:   _resolvedLabourName,
      lifetime:     const Duration(seconds: _totalSeconds),
    );
    _secondsLeft = _totalSeconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = _buildLoading();
    } else if (_error != null) {
      body = _buildError(_error!);
    } else {
      body = _buildMain();
    }

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('My QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: body,
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return Container(
      color: AppColors.navy,
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 52, height: 52,
            child: CircularProgressIndicator(
              color: AppColors.gold, strokeWidth: 3)),
          SizedBox(height: 20),
          Text('Loading QR Code…',
            style: TextStyle(color: AppColors.textOnDarkMuted,
              fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError(String msg) {
    return Container(
      color: AppColors.navy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.absent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.absent.withValues(alpha: 0.3))),
              child: const Icon(Icons.error_outline_rounded,
                color: AppColors.absent, size: 36)),
            const SizedBox(height: 18),
            Text(msg, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textOnDarkMuted,
                fontSize: 14, height: 1.5)),
          ]),
        ),
      ),
    );
  }

  // ── Main Body ──────────────────────────────────────────────────────────────
  Widget _buildMain() {
    final isUrgent = _secondsLeft <= 10;
    final progress = (_secondsLeft / _totalSeconds).clamp(0.0, 1.0);
    final initial  = _resolvedLabourName.isNotEmpty
        ? _resolvedLabourName[0].toUpperCase() : 'L';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, Color(0xFF0C1018), Color(0xFF111827)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(children: [

            // ── Identity pill ──────────────────────────────────────────────
            _IdentityPill(
              labourName:   _resolvedLabourName,
              initial:      initial,
              missingReason: _missingReason,
              isRefreshing: _isRefreshing,
              onRefresh:    _doRefresh,
            ),
            const SizedBox(height: 24),

            // ── QR or Missing ──────────────────────────────────────────────
            _missingReason != null
                ? _MissingCard(reason: _missingReason!)
                : _QRCardPremium(
                    qrPayload:    _qrPayload,
                    secondsLeft:  _secondsLeft,
                    progress:     progress,
                    isUrgent:     isUrgent,
                    isRefreshing: _isRefreshing,
                    pulseAnim:    _pulseAnim,
                    fadeAnim:     _fadeAnim,
                    spinCtrl:     _spinCtrl,
                    onRefresh:    _doRefresh,
                  ),
            const SizedBox(height: 20),

            // ── Security notice ────────────────────────────────────────────
            _SecurityNotice(),
          ]),
        ),
      ),
    );
  }
}

// ── Identity Pill ─────────────────────────────────────────────────────────────
class _IdentityPill extends StatelessWidget {
  const _IdentityPill({
    required this.labourName, required this.initial,
    required this.missingReason, required this.isRefreshing,
    required this.onRefresh,
  });

  final String labourName;
  final String initial;
  final String? missingReason;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ready = missingReason == null;

    return Row(children: [
      // Gold avatar
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gold, AppColors.goldDark],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(child: Text(initial,
          style: const TextStyle(color: AppColors.navy,
            fontWeight: FontWeight.w900, fontSize: 20)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(labourName,
          style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w800, fontSize: 16),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: ready ? AppColors.present : AppColors.absent,
              shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            ready ? 'Ready for Scan' : 'Not Configured',
            style: TextStyle(
              color: ready ? AppColors.present : AppColors.absent,
              fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ])),
      // Manual refresh button
      GestureDetector(
        onTap: isRefreshing ? null : onRefresh,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
          child: Icon(Icons.refresh_rounded,
            size: 20,
            color: isRefreshing
                ? Colors.white.withValues(alpha: 0.3)
                : AppColors.gold))),
    ]);
  }
}

// ── Premium QR Card ───────────────────────────────────────────────────────────
class _QRCardPremium extends StatelessWidget {
  const _QRCardPremium({
    required this.qrPayload, required this.secondsLeft,
    required this.progress, required this.isUrgent,
    required this.isRefreshing, required this.pulseAnim,
    required this.fadeAnim, required this.spinCtrl,
    required this.onRefresh,
  });

  final String qrPayload;
  final int secondsLeft;
  final double progress;
  final bool isUrgent;
  final bool isRefreshing;
  final Animation<double> pulseAnim;
  final Animation<double> fadeAnim;
  final AnimationController spinCtrl;
  final VoidCallback onRefresh;

  Color get _ringColor => isUrgent ? AppColors.absent : AppColors.gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: isUrgent ? 0.6 : 0.25),
          width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: isUrgent ? 0.18 : 0.08),
            blurRadius: 32, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(children: [

          // ── Circular countdown ring + QR ────────────────────────────────
          Stack(alignment: Alignment.center, children: [
            // Outer pulse ring (urgent only)
            if (isUrgent)
              ScaleTransition(
                scale: pulseAnim,
                child: Container(
                  width: 298, height: 298,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.absent.withValues(alpha: 0.2),
                      width: 2)))),

            // Countdown arc
            SizedBox(
              width: 280, height: 280,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(_ringColor),
                strokeCap: StrokeCap.round)),

            // QR code + gold corners
            FadeTransition(
              opacity: fadeAnim,
              child: Stack(alignment: Alignment.center, children: [
                // QR white card
                Container(
                  width: 230, height: 230,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 206,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.navy),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.navy),
                      ),
                    ),
                  ),
                ),
                // Gold corner brackets overlay
                SizedBox(
                  width: 230, height: 230,
                  child: CustomPaint(
                    painter: _GoldCornerPainter(
                      color: isUrgent ? AppColors.absent : AppColors.gold,
                      radius: 20, length: 22, thickness: 3.5))),

                // Spinning overlay during refresh
                if (isRefreshing)
                  Container(
                    width: 230, height: 230,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20)),
                    child: Center(child: RotationTransition(
                      turns: CurvedAnimation(
                        parent: spinCtrl, curve: Curves.easeInOut),
                      child: const Icon(Icons.qr_code_rounded,
                        color: AppColors.gold, size: 48)))),
              ]),
            ),

            // Seconds counter in ring gap
            Positioned(
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _ringColor.withValues(alpha: 0.5))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_rounded, size: 12, color: _ringColor),
                  const SizedBox(width: 4),
                  Text('${secondsLeft}s',
                    style: TextStyle(
                      color: _ringColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
                ]))),
          ]),

          const SizedBox(height: 22),

          // ── Linear bar + status ────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress, minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_ringColor))),

          const SizedBox(height: 14),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: isUrgent ? AppColors.absent : AppColors.present,
                shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(
              isUrgent
                  ? 'Refreshing in ${secondsLeft}s…'
                  : 'Auto-refreshes in ${secondsLeft}s',
              style: TextStyle(
                color: isUrgent
                    ? AppColors.absent
                    : Colors.white.withValues(alpha: 0.55),
                fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh_rounded, size: 13, color: AppColors.gold),
                  SizedBox(width: 5),
                  Text('Refresh', style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12, fontWeight: FontWeight.w700)),
                ]))),
          ]),
        ]),
      ),
    );
  }
}

// ── Gold Corner Bracket Painter ───────────────────────────────────────────────
class _GoldCornerPainter extends CustomPainter {
  const _GoldCornerPainter({
    required this.color,
    required this.radius,
    required this.length,
    required this.thickness,
  });

  final Color color;
  final double radius;
  final double length;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final r = radius;
    final l = length;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(r + l, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, r + l), paint);
    canvas.drawArc(Rect.fromLTWH(0, 0, r * 2, r * 2),
        math.pi, math.pi / 2, false, paint);

    // Top-right
    canvas.drawLine(Offset(w - r - l, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, r + l), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2),
        3 * math.pi / 2, math.pi / 2, false, paint);

    // Bottom-left
    canvas.drawLine(Offset(r, h), Offset(r + l, h), paint);
    canvas.drawLine(Offset(0, h - r - l), Offset(0, h - r), paint);
    canvas.drawArc(Rect.fromLTWH(0, h - r * 2, r * 2, r * 2),
        math.pi / 2, math.pi / 2, false, paint);

    // Bottom-right
    canvas.drawLine(Offset(w - r - l, h), Offset(w - r, h), paint);
    canvas.drawLine(Offset(w, h - r - l), Offset(w, h - r), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2),
        0, math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(_GoldCornerPainter old) =>
      old.color != color || old.thickness != thickness;
}

// ── Missing Card ──────────────────────────────────────────────────────────────
class _MissingCard extends StatelessWidget {
  const _MissingCard({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.absent.withValues(alpha: 0.3))),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.absent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.absent.withValues(alpha: 0.3))),
          child: const Icon(Icons.qr_code_2_rounded,
            color: AppColors.absent, size: 38)),
        const SizedBox(height: 16),
        const Text('QR Not Available',
          style: TextStyle(fontWeight: FontWeight.w800,
            fontSize: 18, color: Colors.white)),
        const SizedBox(height: 10),
        Text(reason, textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.25))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.support_agent_rounded,
              color: AppColors.gold, size: 18),
            SizedBox(width: 8),
            Text('Contact your Supervisor',
              style: TextStyle(color: AppColors.gold,
                fontWeight: FontWeight.w700, fontSize: 13)),
          ])),
      ]),
    );
  }
}

// ── Security Notice ───────────────────────────────────────────────────────────
class _SecurityNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.18))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.shield_rounded,
            color: AppColors.gold, size: 18)),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Security Notice',
            style: TextStyle(fontWeight: FontWeight.w700,
              color: AppColors.gold, fontSize: 13)),
          SizedBox(height: 5),
          Text(
            'Show this QR to your supervisor for attendance. '
            'Only supervisors can scan. Never share your QR code with others.',
            style: TextStyle(
              color: AppColors.textOnDarkMuted,
              fontSize: 12, height: 1.55)),
        ])),
      ]),
    );
  }
}
