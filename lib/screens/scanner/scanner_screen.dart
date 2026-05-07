import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/labour_model.dart';
import '../../services/attendance_service.dart';
import '../../services/scanner_service.dart';
import '../../widgets/status_badge.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final ScannerService _scannerService = ScannerService();
  final AttendanceService _attendanceService = AttendanceService();
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  ScanResult? _lastResult;
  int _pendingCount = 0;
  late Stream<List<Map<String, dynamic>>> _liveScansStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _liveScansStream =
        _attendanceService.attendanceStreamForDate(_todayString());
    _loadPendingCount();
    _autoSync();
  }

  void _loadPendingCount() {
    setState(() {
      _pendingCount = _scannerService.getPendingCount();
    });
  }

  List<Map<String, dynamic>> _offlinePendingForToday() {
    final box = Hive.box('pending_attendance');
    final today = _todayString();
    return box.values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .where((v) => v['date'] == today && v['isSynced'] == false)
        .toList();
  }

  Future<void> _autoSync() async {
    final synced = await _scannerService.syncPendingScans();
    if (synced > 0 && mounted) {
      _loadPendingCount();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.present,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.cloud_done_outlined,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('$synced offline scan${synced > 1 ? "s" : ""} synced',
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    await _cameraController.stop();

    final result = await _scannerService.processScan(rawValue);

    if (result.success) {
      await _scannerService.playSuccessFeedback();
    } else {
      await _scannerService.playErrorFeedback();
    }

    if (!mounted) return;

    setState(() {
      _lastResult = result;
      _isProcessing = false;
    });

    _loadPendingCount();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _lastResult = null);
    await _cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    final frameColor = _lastResult == null
        ? Colors.white.withValues(alpha: 0.7)
        : (_lastResult!.type == ScanResultType.duplicate
            ? AppColors.halfDay
            : (_lastResult!.success ? AppColors.present : AppColors.absent));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Attendance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined,
                        color: Colors.white),
                    onPressed: _autoSync,
                    tooltip: 'Sync pending',
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.absent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined, color: Colors.white),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 55,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: _onDetect,
                ),
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: frameColor, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                _ScanCornerOverlay(color: frameColor),
                if (_lastResult != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _lastResult!.success
                            ? AppColors.present
                            : (_lastResult!.type == ScanResultType.duplicate
                                ? AppColors.halfDay
                                : AppColors.absent),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (_lastResult!.success
                                    ? AppColors.present
                                    : AppColors.absent)
                                .withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _lastResult!.success
                                  ? Icons.check_circle_rounded
                                  : (_lastResult!.type ==
                                          ScanResultType.duplicate
                                      ? Icons.warning_rounded
                                      : Icons.cancel_rounded),
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lastResult!.success
                                      ? 'Attendance Marked!'
                                      : _lastResult!.type ==
                                              ScanResultType.duplicate
                                          ? 'Already Marked'
                                          : 'Scan Failed',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _lastResult!.message,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isProcessing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 45,
            child: Container(
              color: AppColors.background,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _liveScansStream,
                builder: (context, snap) {
                  final liveRecords = (snap.data ??
                          const <Map<String, dynamic>>[])
                      .where((r) => (r['markedVia'] as String?) == 'qr')
                      .toList();
                  final offlineQueued = _offlinePendingForToday();

                  final liveLabourIds = liveRecords
                      .map((r) => (r['labourId'] as String?) ?? '')
                      .toSet();
                  final unsyncedOnly = offlineQueued
                      .where((q) =>
                          !liveLabourIds.contains(q['labourId']))
                      .toList();

                  liveRecords.sort((a, b) {
                    final ta = _toMillis(a['markedAt']);
                    final tb = _toMillis(b['markedAt']);
                    return tb.compareTo(ta);
                  });

                  final totalCount =
                      liveRecords.length + unsyncedOnly.length;
                  final isLoading =
                      snap.connectionState == ConnectionState.waiting;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              "Today's Scans",
                              style: AppTextStyles.headingMedium,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$totalCount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.presentSurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt,
                                      size: 11, color: AppColors.present),
                                  SizedBox(width: 2),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: AppColors.present,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (_pendingCount > 0)
                              Text(
                                '$_pendingCount pending',
                                style: const TextStyle(
                                  color: AppColors.halfDay,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: isLoading && totalCount == 0
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary))
                            : totalCount == 0
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primarySurface,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.qr_code_scanner_outlined,
                                            size: 32,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'No scans yet today',
                                          style: AppTextStyles.headingMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Point camera at a labour QR code',
                                          style: AppTextStyles.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 0, 12, 16),
                                    itemCount: totalCount,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      if (index < liveRecords.length) {
                                        return _buildLiveTile(
                                            liveRecords[index]);
                                      }
                                      return _buildOfflineTile(unsyncedOnly[
                                          index - liveRecords.length]);
                                    },
                                  ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cameraController.start();
      _autoSync();
    } else if (state == AppLifecycleState.paused) {
      _cameraController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _scanTime(String? scannedAt) {
    if (scannedAt == null || scannedAt.length < 16) return '';
    return scannedAt.substring(11, 16);
  }

  int _toMillis(dynamic raw) {
    if (raw == null) return 0;
    try {
      final dt = (raw as dynamic).toDate() as DateTime?;
      if (dt != null) return dt.millisecondsSinceEpoch;
    } catch (_) {}
    if (raw is DateTime) return raw.millisecondsSinceEpoch;
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return 0;
  }

  String _formatLiveTime(dynamic raw) {
    final ms = _toMillis(raw);
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return DateFormat('HH:mm:ss').format(dt);
  }

  String _resolveOfflineName(Map<String, dynamic> scan) {
    final stored = (scan['labourName'] as String?)?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final labourId = (scan['labourId'] as String?) ?? '';
    if (labourId.isEmpty) return 'Unknown';
    try {
      final labourBox = Hive.box<Labour>(Labour.boxName);
      final labour = labourBox.get(labourId) ??
          labourBox.values.cast<Labour?>().firstWhere(
              (l) => l?.firestoreId == labourId,
              orElse: () => null);
      if (labour != null && labour.name.isNotEmpty) return labour.name;
    } catch (_) {}
    return labourId;
  }

  Widget _buildLiveTile(Map<String, dynamic> record) {
    final labourName =
        (record['labourName'] as String?)?.trim().isNotEmpty == true
            ? record['labourName'] as String
            : (record['labourId'] as String? ?? 'Labour');
    final status = (record['status'] as String?) ?? 'present';
    final time = _formatLiveTime(record['markedAt']);
    final markedVia = (record['markedVia'] as String?) ?? 'qr';
    final initial = labourName.isNotEmpty ? labourName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.presentSurface,
            child: Text(
              initial,
              style: const TextStyle(
                  color: AppColors.present,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labourName, style: AppTextStyles.labelLarge),
                Text(
                  time.isEmpty ? markedVia : '$time  •  $markedVia',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          StatusBadge(status: status),
        ],
      ),
    );
  }

  Widget _buildOfflineTile(Map<String, dynamic> scan) {
    final displayName = _resolveOfflineName(scan);
    final status = (scan['status'] as String?) ?? 'present';
    final time = _scanTime(scan['scannedAt'] as String?);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.halfDay.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.halfSurface,
            child: Text(
              initial,
              style: const TextStyle(
                  color: AppColors.halfDay,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: AppTextStyles.labelLarge),
                Text(
                  '${time.isNotEmpty ? "$time  •  " : ""}offline — pending sync',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.halfDay),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.halfSurface,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.halfDay.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 12, color: AppColors.halfDay),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.halfDay),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCornerOverlay extends StatelessWidget {
  const _ScanCornerOverlay({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        children: [
          _corner(Alignment.topLeft, true, true),
          _corner(Alignment.topRight, false, true),
          _corner(Alignment.bottomLeft, true, false),
          _corner(Alignment.bottomRight, false, false),
        ],
      ),
    );
  }

  Widget _corner(
      Alignment alignment, bool isLeft, bool isTop) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            bottom: !isTop
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            left: isLeft
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            right: !isLeft
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
