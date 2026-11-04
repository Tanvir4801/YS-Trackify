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
  final ValueNotifier<int> _secondsLeftNotifier = ValueNotifier(_totalSeconds);
  
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
      final session = SessionService.instance.current;
      
      String targetId = widget.labour?.contractorId ?? '';
      if (targetId.isEmpty) targetId = widget.labour?.supervisorId ?? '';
      if (targetId.isEmpty) targetId = profile?['contractorId'] as String? ?? '';
      if (targetId.isEmpty) targetId = profile?['supervisorId'] as String? ?? '';
      if (targetId.isEmpty) targetId = session?.contractorId ?? '';

      if (targetId.isNotEmpty) {
        try {
          var doc = await FirebaseFirestore.instance.collection('contractors').doc(targetId).get();
          if (!doc.exists) {
            doc = await FirebaseFirestore.instance.collection('users').doc(targetId).get();
          }
          if (doc.exists) {
            final data = doc.data() ?? {};
            
            final branding = data['branding'] as Map<String, dynamic>?;
            final brandingCompany = branding?['companyName'] as String?;
            
            supervisorName = brandingCompany ??
                             (data['companyName'] as String?) ?? 
                             (data['name'] as String?) ?? 
                             'Assigned Supervisor';
          } else {
            supervisorName = 'Assigned Supervisor';
          }
        } catch (e) {
          supervisorName = 'Assigned Supervisor';
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
      _secondsLeftNotifier.value -= 1;
      if (_secondsLeftNotifier.value <= 0) _doRefresh();
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
    _secondsLeftNotifier.value = _totalSeconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _spinCtrl.dispose();
    _fadeCtrl.dispose();
    _secondsLeftNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    final pageBgColor = AppColors.backgroundColor(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: pageBgColor,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context))),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: pageBgColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.errorColor(context), size: 64),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 16), textAlign: TextAlign.center),
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
                    Icon(Icons.autorenew_rounded, color: AppColors.textTertiaryColor(context), size: 14),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<int>(
                      valueListenable: _secondsLeftNotifier,
                      builder: (context, val, child) {
                        return Text(
                          'Refreshing in ${val}s',
                          style: TextStyle(
                            color: AppColors.textTertiaryColor(context), 
                            fontSize: 12, 
                            fontWeight: FontWeight.w500
                          ),
                        );
                      }
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
        backgroundColor: pageBgColor,
        appBar: AppBar(
          backgroundColor: pageBgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: AppColors.textPrimaryColor(context)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Digital ID', style: TextStyle(color: AppColors.textPrimaryColor(context))),
        ),
        body: content,
      );
    }

    return Container(
      color: pageBgColor,
      child: content,
    );
  }

  Widget _buildDigitalIdCard() {
    if (_missingReason != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorColor(context), size: 48),
            const SizedBox(height: 16),
            Text(_missingReason!, style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 15), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final cardBg = AppColors.cardColor(context);
    final headerBg = AppColors.softGold(context);
    final primaryNavy = AppColors.textPrimaryColor(context);
    final secondaryNavy = AppColors.surfaceColor(context);
    final primaryGold = AppColors.primaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);
    final borderCol = AppColors.borderColor(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: Theme.of(context).brightness == Brightness.light ? [
          BoxShadow(
            color: const Color(0xFF14233B).withValues(alpha: 0.04),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          )
        ] : [
          BoxShadow(
            color: AppColors.primaryColor(context).withValues(alpha: 0.1),
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
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.softGold(context),
                  radius: 28,
                  child: Text(
                    _resolvedLabourName.isNotEmpty ? _resolvedLabourName[0].toUpperCase() : '?',
                    style: TextStyle(color: primaryGold, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resolvedLabourName,
                        style: TextStyle(color: primaryNavy, fontSize: 20, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'LABOUR ID', 
                            style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _resolvedLabourId.toUpperCase(),
                            style: TextStyle(color: secondaryNavy, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ]
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // QR Code section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.backgroundColor(context)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimaryColor(context).withValues(alpha: 0.06),
                        blurRadius: 20,
                        spreadRadius: -2,
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
                const SizedBox(height: 24),
                Text(
                  'SCAN TO VERIFY',
                  style: TextStyle(color: primaryNavy, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  'Attendance • Payments • Identity',
                  style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          
          // Details Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor(context).withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
              border: Border(top: BorderSide(color: borderCol)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPremiumDetailItem(Icons.business_rounded, 'Supervisor', _resolvedContractorName, false),
                    _buildPremiumDetailItem(Icons.location_on_rounded, 'App', _resolvedSiteName, false),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPremiumDetailItem(Icons.payments_rounded, 'Daily Wage', '₹${_resolvedWage.toStringAsFixed(0)}', true),
                    _buildPremiumDetailItem(Icons.calendar_month_rounded, 'Joined On', _resolvedJoiningDate, false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumDetailItem(IconData icon, String label, String value, bool isGold) {
    final textSecondary = AppColors.textSecondaryColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final iconBg = AppColors.backgroundColor(context);
    final goldColor = AppColors.primaryColor(context);
    final iconColor = isGold ? goldColor : textSecondary;
    final valueColor = isGold ? goldColor : textPrimary;
    
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGold ? AppColors.softGold(context) : iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w700), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
