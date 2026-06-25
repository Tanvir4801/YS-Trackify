import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/attendance_model.dart';
import '../../models/attendance_session_model.dart';
import '../../models/labour_model.dart';
import '../../services/attendance_session_service.dart';
import '../../services/attendance_service.dart';
import '../../services/firestore_paths.dart';
import '../../services/session_service.dart';

enum _EndStep { none, absentConfirm, allowances, summary }

class SessionScannerScreen extends StatefulWidget {
  const SessionScannerScreen({super.key, required this.session});
  final AttendanceSession session;

  @override
  State<SessionScannerScreen> createState() => _SessionScannerScreenState();
}

class _SessionScannerScreenState extends State<SessionScannerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late TabController _tabController;
  final MobileScannerController _cam = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final AttendanceSessionService _sessionSvc = AttendanceSessionService();
  final AttendanceService _attendanceSvc = AttendanceService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AttendanceSession? _liveSession;
  StreamSubscription? _sessionSub;

  bool _isProcessing = false;
  bool _cooldown = false;
  _ScanFlash? _flash;
  Timer? _flashTimer;

  List<Labour> _allLabours = [];
  Set<String> _markedLabourIds = {};
  StreamSubscription? _markedSub;
  String _search = '';

  _EndStep _endStep = _EndStep.none;
  List<Labour> _absentLabours = [];
  final _allowanceForm = <String, double>{
    'petrol': 0, 'lunch': 0, 'breakfast': 0, 'tea': 0,
  };
  Map<String, double> _advances = {};

  // Summary data
  int _summaryPresent = 0;
  int _summaryAbsent = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _liveSession = widget.session;
    _startSessionStream();
    _loadLabours();
    _startMarkedStream();
  }

  void _startSessionStream() {
    _sessionSub = _sessionSvc
        .streamSession(widget.session.id)
        .listen((s) {
      if (mounted && s != null) setState(() => _liveSession = s);
    });
  }

  Future<void> _loadLabours() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final contractorId = SessionService.instance.contractorId ?? uid;

    // Try Hive cache first
    List<Labour> labours = [];
    try {
      final box = Hive.box<Labour>(Labour.boxName);
      labours = box.values
          .where((l) => l.isActive && !l.isTemporary &&
              (l.supervisorId == uid || l.contractorId == contractorId))
          .toList();
    } catch (_) {}

    if (labours.isEmpty) {
      try {
        // Primary: fetch by supervisorId
        final bySupSnap = await _db
            .collection('labours')
            .where('supervisorId', isEqualTo: uid)
            .where('isActive', isEqualTo: true)
            .get();
        final Map<String, Labour> map = {
          for (final d in bySupSnap.docs) d.id: Labour.fromFirestore(d)
        };

        // Fallback: fetch by contractorId (covers labours added by contractor admin)
        if (map.isEmpty && contractorId != uid) {
          final byCtSnap = await _db
              .collection('labours')
              .where('contractorId', isEqualTo: contractorId)
              .where('isActive', isEqualTo: true)
              .get();
          for (final d in byCtSnap.docs) {
            map.putIfAbsent(d.id, () => Labour.fromFirestore(d));
          }
        }

        labours = map.values.toList();

        // Cache into Hive
        try {
          final box = Hive.box<Labour>(Labour.boxName);
          for (final l in labours) await box.put(l.id, l);
        } catch (_) {}
      } catch (e) {
        debugPrint('_loadLabours Firestore error: $e');
      }
    }

    labours.sort((a, b) => a.name.compareTo(b.name));
    if (mounted) setState(() => _allLabours = labours);
  }

  void _startMarkedStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final contractorId = SessionService.instance.contractorId ?? uid;
    final today = _today();
    _markedSub = FirestorePaths.attendanceRecordsCol(contractorId, today)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _markedLabourIds = snap.docs.map((d) {
          final data = d.data();
          return (data['labourId'] as String?) ?? d.id;
        }).toSet();
      });
    });
  }

  List<Labour> get _unmarkedLabours => _allLabours
      .where((l) => !_markedLabourIds.contains(l.id) &&
          (l.name.toLowerCase().contains(_search.toLowerCase())))
      .toList();

  // ── QR decode (handles admin format and v2 format) ───────────────────────────
  Map<String, dynamic>? _decodeQr(String raw) {
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final type     = parsed['type']     as String?;
      final labourId = (parsed['labourId'] as String?)?.trim() ?? '';

      if (labourId.isEmpty) return null;

      // Admin format: {"type":"labour_qr","labourId":"...","name":"...","appId":"..."}
      if (type == 'labour_qr') {
        return {
          'labourId':   labourId,
          'labourName': (parsed['name'] as String?) ?? 'Labour',
        };
      }

      // V2 format: {"labourId":"...","contractorId":"...","labourName":"...","expiresAt":...}
      final contractorId = (parsed['contractorId'] as String?)?.trim() ?? '';
      final expiresAt    = (parsed['expiresAt']    as num?)?.toInt() ?? 0;
      if (expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt) {
        return {'error': 'expired'};
      }
      if (contractorId.isNotEmpty) {
        final myContractorId = SessionService.instance.contractorId ??
            FirebaseAuth.instance.currentUser?.uid ?? '';
        if (contractorId != myContractorId) return {'error': 'wrong_contractor'};
        return {
          'labourId':   labourId,
          'labourName': (parsed['labourName'] as String?) ?? 'Labour',
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── On QR detect ─────────────────────────────────────────────────────────────
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _cooldown || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() { _isProcessing = true; _cooldown = true; });
    await _cam.stop();

    final decoded = _decodeQr(raw);

    if (decoded == null) {
      await _playError();
      _showFlash(_ScanFlash(color: AppColors.absent, icon: Icons.cancel_rounded,
          message: 'Invalid QR code'));
      await Future.delayed(const Duration(seconds: 2));
      _endFlash();
      await _cam.start();
      _setCooldown();
      return;
    }

    final err = decoded['error'] as String?;
    if (err == 'expired') {
      await _playError();
      _showFlash(_ScanFlash(color: AppColors.absent, icon: Icons.cancel_rounded,
          message: 'QR expired — ask labour to refresh'));
      await Future.delayed(const Duration(seconds: 2));
      _endFlash();
      await _cam.start();
      _setCooldown();
      return;
    }
    if (err != null) {
      await _playError();
      _showFlash(_ScanFlash(color: AppColors.absent, icon: Icons.cancel_rounded,
          message: 'Invalid QR — wrong contractor'));
      await Future.delayed(const Duration(seconds: 2));
      _endFlash();
      await _cam.start();
      _setCooldown();
      return;
    }

    final labourId   = decoded['labourId']   as String;
    final labourName = decoded['labourName'] as String? ?? 'Labour';

    // Duplicate in this session
    if (_markedLabourIds.contains(labourId)) {
      await _playSuccess();
      _showFlash(_ScanFlash(
          color: AppColors.halfDay,
          icon: Icons.warning_rounded,
          message: 'Already marked in this session',
          labourName: labourName));
      await Future.delayed(const Duration(seconds: 2));
      _endFlash();
      await _cam.start();
      _setCooldown();
      return;
    }

    // Mark attendance
    await _playSuccess();
    final success = await _markLabour(labourId, labourName, 'present');
    if (!mounted) return;

    if (success) {
      _showFlash(_ScanFlash(
          color: AppColors.present,
          icon: Icons.check_circle_rounded,
          message: '$labourName marked ✓',
          labourName: labourName,
          labourId: labourId,
          showActions: true));
      await _sessionSvc.incrementMarkedCount(widget.session.id);
    } else {
      _showFlash(_ScanFlash(
          color: AppColors.absent,
          icon: Icons.cancel_rounded,
          message: 'Failed to mark — try again'));
      await Future.delayed(const Duration(seconds: 2));
      _endFlash();
    }

    await _cam.start();
    _setCooldown();
  }

  /// Mark a labour's attendance in both the nested and flat collections.
  /// [markedVia] should be 'qr' for QR scans and 'manual' for manual entry.
  Future<bool> _markLabour(
    String labourId,
    String labourName,
    String status, {
    String markedVia = 'qr',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final contractorId = SessionService.instance.contractorId ?? uid;
    final today = _today();
    final session = _liveSession ?? widget.session;

    try {
      // ── Primary write: nested multi-tenant path (source of truth) ─────────
      final nestedRef = FirestorePaths.attendanceRecordRef(contractorId, today, labourId);
      await nestedRef.set({
        'labourId':     labourId,
        'labourName':   labourName,
        'contractorId': contractorId,
        'supervisorId': uid,
        'supervisorRef': FirestorePaths.userRef(uid),
        'siteId':       session.siteId,
        'siteName':     session.siteName,
        'sessionId':    session.id,
        'date':         today,
        'status':       status,
        'overtimeHours': 0,
        'markedVia':    markedVia,
        'markedAt':     FieldValue.serverTimestamp(),
        'wageAtTime': _allLabours
    .where((l) => l.id == labourId)
    .map((l) => l.dailyWage)
    .firstOrNull ?? 0,
      }, SetOptions(merge: true));

      // Date-level metadata doc
      await FirestorePaths.attendanceDateDoc(contractorId, today).set({
        'date': today, 'contractorId': contractorId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ── Secondary write: flat collection (for admin panel reads) ──────────
      // Uses a deterministic doc ID so the write is idempotent (no query needed)
      final flatDocId = '${contractorId}_${today}_$labourId';
      final flatRef = _db.collection('attendance').doc(flatDocId);
      try {
        final wageAtTime = _allLabours
            .where((l) => l.id == labourId)
            .map((l) => l.dailyWage)
            .firstOrNull ?? 0.0;
        await flatRef.set({
          'id':           flatDocId,
          'labourId':     labourId,
          'labourName':   labourName,
          'supervisorId': uid,
          'contractorId': contractorId,
          'siteId':       session.siteId,
          'siteName':     session.siteName,
          'sessionId':    session.id,
          'date':         today,
          'status':       status,
          'overtimeHours': 0,
          'markedVia':    markedVia,
          'wageAtTime':   wageAtTime,
          'isSynced':     true,
          'syncedAt':     FieldValue.serverTimestamp(),
          'updatedAt':    FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('⚠️ flat write failed (non-critical): $e');
      }

      // ── Hive local cache ──────────────────────────────────────────────────
      try {
        final box = Hive.box('pending_attendance');
        box.put('${labourId}_$today', {
          'labourId': labourId, 'labourName': labourName,
          'supervisorId': uid, 'contractorId': contractorId,
          'siteId': session.siteId, 'sessionId': session.id,
          'date': today, 'status': status, 'markedVia': markedVia,
          'isSynced': true, 'scannedAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('_markLabour error: $e');
      // Offline queue
      try {
        final box = Hive.box('pending_attendance');
        box.put('${labourId}_$today', {
          'labourId': labourId, 'labourName': labourName,
          'supervisorId': uid, 'contractorId': contractorId,
          'siteId': session.siteId, 'sessionId': session.id,
          'date': today, 'status': status, 'markedVia': markedVia,
          'isSynced': false, 'scannedAt': DateTime.now().toIso8601String(),
        });
        return true;
      } catch (_) {}
      return false;
    }
  }

  void _showFlash(_ScanFlash flash) {
    _flashTimer?.cancel();
    if (mounted) setState(() { _flash = flash; _isProcessing = false; });
    if (!flash.showActions) {
      _flashTimer = Timer(const Duration(seconds: 3), _endFlash);
    }
  }

  void _endFlash() {
    _flashTimer?.cancel();
    if (mounted) setState(() => _flash = null);
  }

  void _setCooldown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _cooldown = false);
    });
  }

  Future<void> _playSuccess() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 150, amplitude: 128);
      }
    } catch (_) {}
    try { await SystemSound.play(SystemSoundType.click); } catch (_) {}
  }

  Future<void> _playError() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 80, 80, 80]);
      }
    } catch (_) {}
  }

  // ── Add remark ───────────────────────────────────────────────────────────────
  void _showRemarkDialog(String labourId, String labourName) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(labourName, style: AppTextStyles.headingMedium),
            const SizedBox(height: 4),
            Text('What work did $labourName do?', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. shuttering work, tile fixing 2nd floor',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () async {
                      final remark = ctrl.text.trim();
                      Navigator.pop(ctx);
                      if (remark.isNotEmpty) {
                        await _attendanceSvc.updateAttendanceRemark(
                            labourId, _today(), remark);
                      }
                    },
                    child: const Text('Save Remark'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Manual mark ──────────────────────────────────────────────────────────────
  Future<void> _manualMark(Labour labour) async {
    await _markLabour(labour.id, labour.name, 'present');
    await _sessionSvc.incrementMarkedCount(widget.session.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.present,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text('${labour.name} marked ✓'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── End Session flow ─────────────────────────────────────────────────────────
  void _startEndSession() {
    _absentLabours = _allLabours
        .where((l) => !_markedLabourIds.contains(l.id))
        .toList();

    // Pre-fill allowances from site defaults
    final session = _liveSession ?? widget.session;
    setState(() {
      _endStep = _EndStep.absentConfirm;
      _allowanceForm['petrol']    = 0;
      _allowanceForm['lunch']     = 0;
      _allowanceForm['breakfast'] = 0;
      _allowanceForm['tea']       = 0;
      _advances = {};
    });
    _showAbsentConfirmSheet();
  }

  void _showAbsentConfirmSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx2, scroll) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unmarked Labours', style: AppTextStyles.headingMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${_absentLabours.length} labours not marked yet.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _absentLabours.isEmpty
                  ? const Center(child: Text('All labours are marked ✓'))
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _absentLabours.length,
                      itemBuilder: (_, i) {
                        final l = _absentLabours[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.absentSurface,
                            child: Text(l.name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.absent,
                                    fontWeight: FontWeight.w700)),
                          ),
                          title: Text(l.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('₹${l.dailyWage.toStringAsFixed(0)}/day'),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: 16, right: 16, bottom: MediaQuery.of(ctx).padding.bottom + 16),
              child: Column(
                children: [
                  if (_absentLabours.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text('Mark ${_absentLabours.length} as Absent'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          for (final l in _absentLabours) {
                            await _markLabour(l.id, l.name, 'absent');
                          }
                          _showAllowancesSheet();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAllowancesSheet();
                      },
                      child: const Text('Skip — Leave Unmarked'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _endStep = _EndStep.none);
                      },
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllowancesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AllowancesSheet(
        form: Map.from(_allowanceForm),
        onDone: (form) {
          Navigator.pop(ctx);
          _allowanceForm.addAll(form);
          _doEndSession();
        },
        onSkip: () {
          Navigator.pop(ctx);
          _doEndSession();
        },
      ),
    );
  }

  Future<void> _doEndSession() async {
    final session = _liveSession ?? widget.session;
    final today = _today();
    final totalAllowance = _allowanceForm.values.fold(0.0, (a, b) => a + b);

    // Apply allowances if any
    if (totalAllowance > 0) {
      try {
        await _attendanceSvc.applyAllowances(
          siteId:    session.siteId,
          date:      today,
          petrol:    _allowanceForm['petrol']    ?? 0,
          lunch:     _allowanceForm['lunch']     ?? 0,
          breakfast: _allowanceForm['breakfast'] ?? 0,
          tea:       _allowanceForm['tea']       ?? 0,
        );
      } catch (e) {
        debugPrint('applyAllowances error: $e');
      }
    }

    final presentCount = _markedLabourIds.length;
    await _sessionSvc.endSession(session.id, totalPresent: presentCount);

    // Calc summary
    double baseWages = 0;
    for (final l in _allLabours) {
      if (_markedLabourIds.contains(l.id)) baseWages += l.dailyWage;
    }
    final absentCount = _allLabours.length - presentCount;

    if (!mounted) return;
    _showSummarySheet(
      presentCount: presentCount,
      absentCount: absentCount,
      baseWages: baseWages,
      totalAllowances: totalAllowance * presentCount,
    );
  }

  void _showSummarySheet({
    required int presentCount,
    required int absentCount,
    required double baseWages,
    required double totalAllowances,
  }) {
    final session = _liveSession ?? widget.session;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: AppColors.presentSurface, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.present, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text('Session Complete', style: AppTextStyles.displayMedium)),
            const SizedBox(height: 20),
            _summaryRow('Site', session.siteName),
            _summaryRow('Date', DateFormat('d MMM yyyy').format(DateTime.now())),
            _summaryRow('Supervisor', session.supervisorName),
            const Divider(height: 24),
            _summaryRow('Present', '$presentCount', color: AppColors.present),
            _summaryRow('Absent', '$absentCount', color: AppColors.absent),
            const Divider(height: 24),
            _summaryRow('Base Wages', '₹${baseWages.toStringAsFixed(0)}'),
            _summaryRow('Allowances', '₹${totalAllowances.toStringAsFixed(0)}'),
            _summaryRow('Net Total',
                '₹${(baseWages + totalAllowances).toStringAsFixed(0)}',
                bold: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Done'),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppColors.textPrimary,
                fontSize: bold ? 17 : 15,
              )),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_tabController.index == 0) {
      if (state == AppLifecycleState.resumed) _cam.start();
      if (state == AppLifecycleState.paused)  _cam.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _cam.dispose();
    _sessionSub?.cancel();
    _markedSub?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final session = _liveSession ?? widget.session;
    final markedCount = session.markedCount;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.present, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    session.siteName,
                    style: const TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text('$markedCount marked today',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined, color: Colors.white),
            onPressed: () => _cam.toggleTorch(),
          ),
          TextButton(
            onPressed: _startEndSession,
            child: const Text('End Session',
                style: TextStyle(color: AppColors.absent, fontWeight: FontWeight.w700)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'QR Scanner'),
            Tab(text: 'Manual List'),
          ],
          onTap: (i) {
            if (i == 0) _cam.start(); else _cam.stop();
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildQrTab(),
          _buildManualTab(),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(controller: _cam, onDetect: _onDetect),
        // Corner overlay
        CustomPaint(
          size: const Size(220, 220),
          painter: _CornerPainter(
            color: _flash == null
                ? Colors.white.withValues(alpha: 0.8)
                : _flash!.color,
          ),
        ),
        if (_flash != null)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _FlashCard(
              flash: _flash!,
              onRemark: () {
                if (_flash!.labourId != null) {
                  _endFlash();
                  _showRemarkDialog(_flash!.labourId!, _flash!.labourName!);
                }
              },
              onUndo: () async {
                if (_flash!.labourId != null) {
                  final lid = _flash!.labourId!;
                  _endFlash();
                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    final contractorId = SessionService.instance.contractorId ?? uid;
                    await FirestorePaths
                        .attendanceRecordRef(contractorId, _today(), lid)
                        .delete();
                  } catch (_) {}
                }
              },
              onDismiss: _endFlash,
            ),
          ),
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildManualTab() {
    final unmarked = _unmarkedLabours;
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search labours…',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: unmarked.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.present, size: 48),
                        const SizedBox(height: 12),
                        const Text('All labours marked!',
                            style: AppTextStyles.headingMedium),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: unmarked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final l = unmarked[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primarySurface,
                              child: Text(l.name[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('₹${l.dailyWage.toStringAsFixed(0)}/day',
                                      style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.present,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8)),
                              onPressed: () => _manualMark(l),
                              child: const Text('Mark Present',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Flash card ────────────────────────────────────────────────────────────────
class _ScanFlash {
  const _ScanFlash({
    required this.color,
    required this.icon,
    required this.message,
    this.labourName,
    this.labourId,
    this.showActions = false,
  });
  final Color color;
  final IconData icon;
  final String message;
  final String? labourName;
  final String? labourId;
  final bool showActions;
}

class _FlashCard extends StatelessWidget {
  const _FlashCard({
    required this.flash,
    required this.onRemark,
    required this.onUndo,
    required this.onDismiss,
  });
  final _ScanFlash flash;
  final VoidCallback onRemark;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: flash.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: flash.color.withValues(alpha: 0.4),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle),
                child: Icon(flash.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(flash.message,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.8), size: 20),
              ),
            ],
          ),
          if (flash.showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Add Remark', style: TextStyle(fontSize: 13)),
                    onPressed: onRemark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Undo', style: TextStyle(fontSize: 13)),
                    onPressed: onUndo,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Allowances sheet ──────────────────────────────────────────────────────────
class _AllowancesSheet extends StatefulWidget {
  const _AllowancesSheet({
    required this.form,
    required this.onDone,
    required this.onSkip,
  });
  final Map<String, double> form;
  final void Function(Map<String, double>) onDone;
  final VoidCallback onSkip;

  @override
  State<_AllowancesSheet> createState() => _AllowancesSheetState();
}

class _AllowancesSheetState extends State<_AllowancesSheet> {
  late Map<String, double> _form;
  late Map<String, bool> _enabled;
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _form = Map.from(widget.form);
    _enabled = {
      'petrol':    _form['petrol']    != 0,
      'lunch':     _form['lunch']     != 0,
      'breakfast': _form['breakfast'] != 0,
      'tea':       _form['tea']       != 0,
    };
    for (final key in _form.keys) {
      _controllers[key] = TextEditingController(
          text: _form[key] == 0 ? '' : _form[key]!.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Apply Allowances', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          const Text('Applied to all present labours in this session',
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 20),
          for (final entry in {
            'petrol': '⛽ Petrol',
            'lunch': '🍱 Lunch',
            'breakfast': '☕ Breakfast',
            'tea': '🫖 Tea',
          }.entries)
            _AllowanceRow(
              label: entry.value,
              key_: entry.key,
              enabled: _enabled[entry.key] ?? false,
              controller: _controllers[entry.key]!,
              onToggle: (v) => setState(() => _enabled[entry.key] = v),
              onChanged: (v) => _form[entry.key] = double.tryParse(v) ?? 0,
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    for (final key in _form.keys) {
                      if (!(_enabled[key] ?? false)) _form[key] = 0;
                    }
                    widget.onDone(_form);
                  },
                  child: const Text('Apply & End Session'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllowanceRow extends StatelessWidget {
  const _AllowanceRow({
    super.key,
    required this.label,
    required this.key_,
    required this.enabled,
    required this.controller,
    required this.onToggle,
    required this.onChanged,
  });
  final String label;
  final String key_;
  final bool enabled;
  final TextEditingController controller;
  final void Function(bool) onToggle;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
                )),
          ),
          if (enabled)
            SizedBox(
              width: 100,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                onChanged: onChanged,
                decoration: InputDecoration(
                  prefixText: '₹',
                  hintText: '0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Corner overlay painter ────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const r = 16.0;
    const l = 36.0;

    // Top-left
    canvas.drawPath(Path()
      ..moveTo(0, r + l)..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(r + l, 0), paint);
    // Top-right
    canvas.drawPath(Path()
      ..moveTo(size.width - r - l, 0)..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
      ..lineTo(size.width, r + l), paint);
    // Bottom-left
    canvas.drawPath(Path()
      ..moveTo(0, size.height - r - l)..lineTo(0, size.height - r)
      ..arcToPoint(Offset(r, size.height), radius: const Radius.circular(r))
      ..lineTo(r + l, size.height), paint);
    // Bottom-right
    canvas.drawPath(Path()
      ..moveTo(size.width - r - l, size.height)
      ..lineTo(size.width - r, size.height)
      ..arcToPoint(Offset(size.width, size.height - r),
          radius: const Radius.circular(r))
      ..lineTo(size.width, size.height - r - l), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}
