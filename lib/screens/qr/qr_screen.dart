import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/labour_model.dart';
import '../../services/qr_service.dart';
import '../../services/session_service.dart';
import '../../services/telemetry_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({super.key, this.showAppBar = false, this.labour});
  final bool showAppBar;
  final Labour? labour;

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> with TickerProviderStateMixin {
  final QRService _qrService = QRService();
  Timer? _ticker;

  late final AnimationController _spinCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const int _totalSeconds = 60;

  String _qrPayload = '';
  int _secondsLeft = _totalSeconds;
  
  String _resolvedLabourId     = '';
  String _resolvedContractorId = '';
  String _resolvedLabourName   = 'Labour';
  String _resolvedContractorName = 'Multiple Contractors';
  String _resolvedSiteName     = 'Trackify Site';
  double _resolvedWage         = 0.0;
  String _resolvedJoiningDate  = 'N/A';
  
  String? _missingReason;
  bool _isLoading   = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      final profile = await _qrService.getLabourProfile();
      
      // Fetch supervisor name from Firestore
      String supervisorName = 'Assigned Supervisor';
      final supervisorId = widget.labour?.supervisorId ?? '';
      if (supervisorId.isNotEmpty) {
        try {
          var doc = await FirebaseFirestore.instance.collection('users').doc(supervisorId).get();
          if (!doc.exists) {
            doc = await FirebaseFirestore.instance.collection('contractors').doc(supervisorId).get();
          }
          if (doc.exists) {
            supervisorName = doc.data()?['name'] as String? ?? supervisorId;
          } else {
            supervisorName = supervisorId;
          }
        } catch (e) {
          supervisorName = supervisorId;
        }
      }

      _resolveLabourFields(profile, supervisorName);
      _refreshPayload();
      _startTicker();
    } catch (e) {
      _error = 'Unable to load QR code. Please sign in again.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resolveLabourFields(Map<String, dynamic>? p, String supervisorName) {
    final session = SessionService.instance.current;
    final labour = widget.labour;

    // Use widget.labour if provided, otherwise fallback to session/qr profile
    _resolvedLabourId = labour?.id ?? session?.labourId ?? '';
    _resolvedContractorId = labour?.contractorId ?? session?.contractorId ?? '';
    
    _resolvedLabourName = labour?.name ?? session?.name ?? 'Labour';
    
    // Use fetched supervisor name
    _resolvedContractorName = supervisorName;

    _resolvedSiteName = 'Trackify App';
    _resolvedWage = labour?.dailyWage ?? 0.0;
    
    if (labour != null) {
      _resolvedJoiningDate = DateFormat('dd MMM yyyy').format(labour.joiningDate);
    }

    _missingReason = _resolvedLabourId.isEmpty
        ? 'Labour profile not linked. Contact your supervisor.'
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

    await _fadeCtrl.reverse();
    _spinCtrl.forward(from: 0);

    setState(() {
      _refreshPayload();
      _isRefreshing = false;
    });

    if (mounted) _fadeCtrl.forward();
  }

  void _refreshPayload() {
    if (_missingReason != null) return;
    TelemetryService.instance.trackFeatureUsage('Generate QR');
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
    _spinCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.absent, size: 64),
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    Widget content = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            children: [
              _buildDigitalIdCard(),
              const SizedBox(height: 24),
              if (_missingReason == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_rounded, color: AppColors.textTertiary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Refreshing in ${_secondsLeft}s',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Digital ID', style: TextStyle(color: Colors.white)),
        ),
        body: content,
      );
    }

    return Container(
      color: AppColors.background,
      child: content,
    );
  }

  Widget _buildDigitalIdCard() {
    if (_missingReason != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.absent, size: 48),
            const SizedBox(height: 16),
            Text(_missingReason!, style: const TextStyle(color: Colors.white, fontSize: 15), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                  radius: 28,
                  child: Text(
                    _resolvedLabourName.isNotEmpty ? _resolvedLabourName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resolvedLabourName,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ID: ${_resolvedLabourId.toUpperCase()}',
                          style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // QR Code section
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: QrImageView(
                      data: _qrPayload,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan for Attendance & Payments',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Details Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem(Icons.business_rounded, 'Supervisor', _resolvedContractorName),
                    _buildDetailItem(Icons.location_on_rounded, 'App', _resolvedSiteName),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem(Icons.payments_rounded, 'Daily Wage', '₹${_resolvedWage.toStringAsFixed(0)}'),
                    _buildDetailItem(Icons.calendar_month_rounded, 'Joined On', _resolvedJoiningDate),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
