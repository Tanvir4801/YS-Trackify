import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../services/scanner_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  final ScannerService _scannerService = ScannerService();
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  ScanResult? _lastResult;
  int _pendingCount = 0;
  List<Map<String, dynamic>> _todayScans = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPendingCount();
    _loadTodayScans();
    _autoSync();
  }

  void _loadPendingCount() {
    setState(() {
      _pendingCount = _scannerService.getPendingCount();
    });
  }

  void _loadTodayScans() {
    final box = Hive.box('pending_attendance');
    final today = _todayString();

    final scans = box.values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .where((value) => value['date'] == today)
        .toList();

    setState(() {
      _todayScans = scans;
    });
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

    _loadTodayScans();
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Scans (${_todayScans.length})",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
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
                    child: _todayScans.isEmpty
                        ? const Center(
                            child: Text(
                              'No scans yet today.\nPoint camera at labour QR code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _todayScans.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final scan = _todayScans[_todayScans.length - 1 - index];
                              final isSynced = (scan['isSynced'] as bool?) ?? false;
                              return ListTile(
                                tileColor: Colors.white,
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isSynced
                                      ? AppColors.present.withValues(alpha: 0.2)
                                      : AppColors.halfDay.withValues(alpha: 0.2),
                                  child: Icon(
                                    isSynced ? Icons.cloud_done : Icons.cloud_off,
                                    size: 16,
                                    color: isSynced ? AppColors.present : AppColors.halfDay,
                                  ),
                                ),
                                title: Text(
                                  (scan['labourId'] as String?) ?? 'Unknown',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  _scanTime(scan['scannedAt'] as String?),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.present.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (scan['status'] as String?) ?? 'present',
                                    style: const TextStyle(
                                      color: AppColors.present,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
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
}
