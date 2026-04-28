import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../services/attendance_service.dart';
import '../../services/scanner_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
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
    _liveScansStream = _attendanceService.attendanceStreamForDate(_todayString());
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
        .where((value) => value['date'] == today && value['isSynced'] == false)
        .toList();
  }

  Future<void> _autoSync() async {
    final synced = await _scannerService.syncPendingScans();
    if (synced > 0 && mounted) {
      _loadPendingCount();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$synced offline scans synced')),
        );
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) {
      return;
    }

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await _cameraController.stop();

    final result = await _scannerService.processScan(rawValue);

    if (result.success) {
      await _scannerService.playSuccessFeedback();
    } else {
      await _scannerService.playErrorFeedback();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _lastResult = result;
      _isProcessing = false;
    });

    _loadPendingCount();

    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() {
      _lastResult = null;
    });
    await _cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    final frameColor = _lastResult == null
        ? Colors.white
        : (_lastResult!.type == ScanResultType.duplicate
            ? AppColors.halfDay
            : (_lastResult!.success ? AppColors.present : AppColors.absent));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance'),
        centerTitle: true,
        actions: [
          if (_pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined),
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined),
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
                    border: Border.all(
                      color: frameColor,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                if (_lastResult != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _lastResult!.success
                            ? AppColors.present
                            : (_lastResult!.type == ScanResultType.duplicate
                                ? AppColors.halfDay
                                : AppColors.absent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lastResult!.success
                                ? Icons.check_circle
                                : (_lastResult!.type == ScanResultType.duplicate
                                    ? Icons.warning_rounded
                                    : Icons.cancel),
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _lastResult!.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isProcessing)
                  Container(
                    color: Colors.black45,
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
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _liveScansStream,
                builder: (context, snap) {
                  final liveRecords = (snap.data ?? const <Map<String, dynamic>>[])
                      .where((r) => (r['markedVia'] as String?) == 'qr')
                      .toList();
                  final offlineQueued = _offlinePendingForToday();

                  // Merge: nested-path live docs are the source of truth; any
                  // offline-only Hive scans (not yet synced) are appended.
                  final liveLabourIds = liveRecords
                      .map((r) => (r['labourId'] as String?) ?? '')
                      .toSet();
                  final unsyncedOnly = offlineQueued
                      .where((q) => !liveLabourIds.contains(q['labourId']))
                      .toList();

                  // Sort live records by markedAt timestamp desc.
                  liveRecords.sort((a, b) {
                    final ta = _toMillis(a['markedAt']);
                    final tb = _toMillis(b['markedAt']);
                    return tb.compareTo(ta);
                  });

                  final totalCount = liveRecords.length + unsyncedOnly.length;
                  final isLoading = snap.connectionState == ConnectionState.waiting;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Today's Scans ($totalCount)",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.present.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.bolt,
                                      size: 11,
                                      color: AppColors.present,
                                    ),
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
                            ],
                          ),
                          if (_pendingCount > 0)
                            Text(
                              '$_pendingCount pending sync',
                              style: const TextStyle(
                                color: AppColors.halfDay,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: isLoading && totalCount == 0
                            ? const Center(child: CircularProgressIndicator())
                            : totalCount == 0
                                ? const Center(
                                    child: Text(
                                      'No scans yet today.\nPoint camera at a labour QR code.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: totalCount,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      if (index < liveRecords.length) {
                                        return _buildLiveTile(liveRecords[index]);
                                      }
                                      final off =
                                          unsyncedOnly[index - liveRecords.length];
                                      return _buildOfflineTile(off);
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
    if (scannedAt == null || scannedAt.length < 16) {
      return '';
    }
    return scannedAt.substring(11, 16);
  }

  int _toMillis(dynamic raw) {
    if (raw == null) return 0;
    try {
      // Firestore Timestamp on web exposes toDate().
      final dt = (raw as dynamic).toDate() as DateTime?;
      if (dt != null) return dt.millisecondsSinceEpoch;
    } catch (_) {/* not a Timestamp */}
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

  Widget _buildLiveTile(Map<String, dynamic> record) {
    final labourName =
        (record['labourName'] as String?)?.trim().isNotEmpty == true
            ? record['labourName'] as String
            : (record['labourId'] as String? ?? 'Labour');
    final status = (record['status'] as String?) ?? 'present';
    final markedVia = (record['markedVia'] as String?) ?? 'manual';
    final time = _formatLiveTime(record['markedAt']);

    return ListTile(
      tileColor: Colors.white,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.present.withValues(alpha: 0.2),
        child: const Icon(
          Icons.cloud_done,
          size: 16,
          color: AppColors.present,
        ),
      ),
      title: Text(labourName, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        time.isEmpty ? markedVia : '$time  •  $markedVia',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.present.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: const TextStyle(
            color: AppColors.present,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineTile(Map<String, dynamic> scan) {
    return ListTile(
      tileColor: Colors.white,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.halfDay.withValues(alpha: 0.2),
        child: const Icon(
          Icons.cloud_off,
          size: 16,
          color: AppColors.halfDay,
        ),
      ),
      title: Text(
        (scan['labourId'] as String?) ?? 'Unknown',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '${_scanTime(scan['scannedAt'] as String?)}  •  offline',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.halfDay.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          (scan['status'] as String?) ?? 'present',
          style: const TextStyle(
            color: AppColors.halfDay,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
