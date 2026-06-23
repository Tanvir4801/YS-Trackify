import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/attendance_session.dart';
import '../../models/labour_model.dart';
import '../../providers/sessions_provider.dart';
import '../../services/firestore_paths.dart';
import '../../services/scanner_service.dart';
import '../../services/session_service.dart';
import '../../services/sessions_service.dart';
import 'session_summary_screen.dart';

class SiteSessionScanScreenArgs {
  final AttendanceSession session;
  const SiteSessionScanScreenArgs({required this.session});
}

class SiteSessionScanScreen extends StatefulWidget {
  final AttendanceSession session;
  const SiteSessionScanScreen({super.key, required this.session});

  @override
  State<SiteSessionScanScreen> createState() => _SiteSessionScanScreenState();
}

class _SiteSessionScanScreenState extends State<SiteSessionScanScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final MobileScannerController _scannerCtrl = MobileScannerController();
  final ScannerService  _scanner  = ScannerService();
  final SessionsService _sessions = SessionsService();

  String get _uid          => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _contractorId {
    final c = SessionService.instance.contractorId;
    return (c != null && c.isNotEmpty) ? c : _uid;
  }
  String _today() {
    final n = DateTime.now();
    return '${n.year}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // Scan state
  bool _processingQr = false;
  DateTime? _lastScan;
  static const _scanCooldown = Duration(seconds: 3);

  // Notification overlay
  _ScanNotification? _notification;
  Timer? _notifTimer;

  // Attendance records for today
  Map<String, String> _markedToday = {}; // labourId → status
  StreamSubscription? _attendanceSub;
  List<Labour> _labours = [];

  // Session live reference
  late AttendanceSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _tabController = TabController(length: 2, vsync: this);
    _loadLabours();
    _startAttendanceStream();
  }

  void _loadLabours() {
    try {
      final box = Hive.box<Labour>(Labour.boxName);
      final labours = box.values
          .where((l) =>
              (l.supervisorId == _uid ||
                  l.contractorId == _contractorId) &&
              l.isActive &&
              !l.isTemporary)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      setState(() => _labours = labours);
    } catch (_) {}

    // Also fetch from Firestore
    FirebaseFirestore.instance
        .collection('labours')
        .where('supervisorId', isEqualTo: _uid)
        .where('isActive', isEqualTo: true)
        .get()
        .then((snap) {
      if (!mounted) return;
      final fetched = snap.docs
          .map(Labour.fromFirestore)
          .where((l) => !l.isTemporary)
          .toList();
      final map = <String, Labour>{};
      for (final l in _labours) {
        map[l.id] = l;
      }
      for (final l in fetched) {
        map[l.id] = l;
      }
      if (mounted) {
        setState(() => _labours = map.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
      }
    }).catchError((_) {});
  }

  void _startAttendanceStream() {
    _attendanceSub?.cancel();
    final today = _today();
    _attendanceSub = FirebaseFirestore.instance
        .collection('attendance')
        .doc(_contractorId)
        .collection('dates')
        .doc(today)
        .collection('records')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final labourId = doc.data()['labourId'] as String? ?? doc.id;
        final status   = (doc.data()['status']   as String? ?? '').toLowerCase();
        if (labourId.isNotEmpty) map[labourId] = status;
      }
      setState(() => _markedToday = map);
    });
  }

  // ── QR Scan handler ───────────────────────────────────────────────────────

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_processingQr) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final now = DateTime.now();
    if (_lastScan != null && now.difference(_lastScan!) < _scanCooldown) return;
    _lastScan = now;

    setState(() => _processingQr = true);
    try {
      final precheck = await _scanner.precheckQR(raw);
      if (!mounted) return;

      if (precheck.isDuplicate) {
        _showNotification(_ScanNotification(
          labourId:   precheck.labourId,
          labourName: precheck.labourName,
          status:     _markedToday[precheck.labourId] ?? 'present',
          message:    '${precheck.labourName} already marked today',
          isError:    true,
        ));
        await _scanner.playErrorFeedback();
        return;
      }

      if (!precheck.isValid) {
        _showNotification(_ScanNotification(
          labourId:   '',
          labourName: '',
          status:     '',
          message:    precheck.errorMessage,
          isError:    true,
        ));
        await _scanner.playErrorFeedback();
        return;
      }

      // Mark present
      final result = await _scanner.processScanWithType(
        rawToken:  raw,
        status:    'present',
        siteId:    _session.siteId,
        sessionId: _session.id,
      );

      if (result.success) {
        await _scanner.playSuccessFeedback();
        await _sessions.incrementMarkedCount(_session.id);
        _showNotification(_ScanNotification(
          labourId:   precheck.labourId,
          labourName: precheck.labourName,
          status:     'present',
          message:    result.message,
          isError:    false,
          rawToken:   raw,
        ));
      } else {
        await _scanner.playErrorFeedback();
        _showNotification(_ScanNotification(
          labourId:   '',
          labourName: '',
          status:     '',
          message:    result.message,
          isError:    true,
        ));
      }
    } catch (e) {
      _showNotification(_ScanNotification(
        labourId:   '',
        labourName: '',
        status:     '',
        message:    'Error: $e',
        isError:    true,
      ));
    } finally {
      if (mounted) setState(() => _processingQr = false);
    }
  }

  void _showNotification(_ScanNotification notif) {
    _notifTimer?.cancel();
    setState(() => _notification = notif);
    _notifTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notification = null);
    });
  }

  Future<void> _undoScan(_ScanNotification notif) async {
    if (notif.labourId.isEmpty) return;
    _notifTimer?.cancel();
    setState(() => _notification = null);

    final today = _today();
    try {
      // Remove from nested path
      await FirestorePaths
          .attendanceRecordRef(_contractorId, today, notif.labourId)
          .delete();
      // Remove from flat collection
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('labourId',     isEqualTo: notif.labourId)
          .where('date',         isEqualTo: today)
          .where('supervisorId', isEqualTo: _uid)
          .limit(1)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      // Decrement session counter
      await FirebaseFirestore.instance
          .collection('attendanceSessions')
          .doc(_session.id)
          .update({'markedCount': FieldValue.increment(-1)});
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${notif.labourName} scan undone'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  Future<void> _addRemark(_ScanNotification notif) async {
    if (notif.labourId.isEmpty) return;
    final controller = TextEditingController();
    final remark = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RemarkSheet(controller: controller),
    );
    if (remark != null && remark.isNotEmpty) {
      try {
        final today = _today();
        await FirestorePaths
            .attendanceRecordRef(_contractorId, today, notif.labourId)
            .update({'remark': remark, 'updatedAt': FieldValue.serverTimestamp()});
      } catch (_) {}
    }
  }

  // ── Manual mark ───────────────────────────────────────────────────────────

  Future<void> _manualMark(Labour labour, String status) async {
    final already = _markedToday[labour.id];
    if (already != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${labour.name} already marked ${already}'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.absent,
      ));
      return;
    }
    final today        = _today();
    final contractorId = _contractorId;
    final supRef       = FirestorePaths.userRef(_uid);

    try {
      await FirestorePaths.attendanceRecordRef(contractorId, today, labour.id)
          .set({
        'labourId':      labour.id,
        'labourName':    labour.name,
        'contractorId':  contractorId,
        'supervisorId':  _uid,
        'supervisorRef': supRef,
        'siteId':        _session.siteId,
        'sessionId':     _session.id,
        'date':          today,
        'status':        status,
        'overtimeHours': 0,
        'markedVia':     'manual',
        'markedAt':      FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirestorePaths.attendanceDateDoc(contractorId, today)
          .set({
        'date':         today,
        'contractorId': contractorId,
        'updatedAt':    FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mirror flat collection
      final existing = await FirebaseFirestore.instance
          .collection('attendance')
          .where('labourId',     isEqualTo: labour.id)
          .where('date',         isEqualTo: today)
          .where('supervisorId', isEqualTo: _uid)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        final ref = await FirebaseFirestore.instance.collection('attendance').add({
          'labourId':      labour.id,
          'labourName':    labour.name,
          'supervisorId':  _uid,
          'supervisorRef': supRef,
          'contractorId':  contractorId,
          'siteId':        _session.siteId,
          'sessionId':     _session.id,
          'date':          today,
          'status':        status,
          'overtimeHours': 0,
          'markedVia':     'manual',
          'isSynced':      true,
          'syncedAt':      FieldValue.serverTimestamp(),
        });
        await ref.update({'id': ref.id});
      }

      await _sessions.incrementMarkedCount(_session.id);
      await _scanner.playSuccessFeedback();

      final label = status == 'half' ? 'Half Day' : 'Present';
      _showNotification(_ScanNotification(
        labourId:   labour.id,
        labourName: labour.name,
        status:     status,
        message:    '${labour.name} marked $label ✓',
        isError:    false,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.absent,
      ));
    }
  }

  // ── End Session Flow ──────────────────────────────────────────────────────

  Future<void> _onEndSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Session?'),
        content: Text(
          'Marked: ${_markedToday.length} labour(s)\n\n'
          'Do you want to end the session for ${_session.siteName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Collect unmarked labours for absent marking
    final unmarked = _labours.where((l) => !_markedToday.containsKey(l.id)).toList();
    List<String> absentIds = [];

    if (unmarked.isNotEmpty && mounted) {
      absentIds = await _showAbsentSheet(unmarked) ?? [];
    }

    // Mark absents
    if (absentIds.isNotEmpty) {
      await _markAbsents(absentIds);
    }

    // Calculate totals
    final counts = <String, int>{'present': 0, 'absent': 0, 'half': 0};
    for (final status in _markedToday.values) {
      if (counts.containsKey(status)) counts[status] = (counts[status] ?? 0) + 1;
    }
    for (final id in absentIds) {
      if (!_markedToday.containsKey(id)) counts['absent'] = (counts['absent'] ?? 0) + 1;
    }

    // End session in Firestore
    await context.read<SessionsProvider>().endSession(
      _session.id,
      totalPresent:      counts['present']!,
      totalAbsent:       counts['absent']!,
      totalHalf:         counts['half']!,
      allowancesApplied: false,
    );

    if (!mounted) return;

    // Navigate to summary
    final updated = _session.copyWith(
      status:       SessionStatus.completed,
      totalPresent: counts['present']!,
      totalAbsent:  counts['absent']!,
      totalHalf:    counts['half']!,
      endedAt:      DateTime.now(),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(session: updated),
      ),
    );
  }

  Future<List<String>?> _showAbsentSheet(List<Labour> unmarked) async {
    final selected = <String>{};
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AbsentMarkSheet(
        labours: unmarked,
        onConfirm: (ids) => Navigator.pop(ctx, ids),
        onSkip: () => Navigator.pop(ctx, <String>[]),
      ),
    );
  }

  Future<void> _markAbsents(List<String> labourIds) async {
    final today        = _today();
    final contractorId = _contractorId;
    final batch        = FirebaseFirestore.instance.batch();

    for (final labourId in labourIds) {
      if (_markedToday.containsKey(labourId)) continue;
      final labour = _labours.firstWhere(
        (l) => l.id == labourId,
        orElse: () => Labour(
          id: labourId, name: labourId, phone: '', skill: '',
          dailyWage: 0, supervisorId: _uid, contractorId: contractorId,
        ),
      );
      final nestedRef = FirestorePaths.attendanceRecordRef(contractorId, today, labourId);
      batch.set(nestedRef, {
        'labourId':      labourId,
        'labourName':    labour.name,
        'contractorId':  contractorId,
        'supervisorId':  _uid,
        'supervisorRef': FirestorePaths.userRef(_uid),
        'siteId':        _session.siteId,
        'sessionId':     _session.id,
        'date':          today,
        'status':        'absent',
        'overtimeHours': 0,
        'markedVia':     'session_end',
        'markedAt':      FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    try { await batch.commit(); } catch (e) {
      debugPrint('_markAbsents batch error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerCtrl.dispose();
    _attendanceSub?.cancel();
    _notifTimer?.cancel();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final markedCount = _markedToday.length;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(markedCount),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildQrTab(),
                  _buildManualTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int markedCount) {
    final dateStr = DateFormat('d MMM yyyy').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Session info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _session.siteName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr  •  $markedCount marked',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // End Session button
          GestureDetector(
            onTap: _onEndSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'End Session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1E293B),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.white54,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'QR Scan'),
          Tab(icon: Icon(Icons.people_rounded), text: 'Manual'),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    return Stack(
      children: [
        // Camera viewfinder
        Positioned.fill(
          child: _QrCameraView(
            controller: _scannerCtrl,
            onDetect: _onBarcodeDetected,
          ),
        ),

        // Overlay frame
        Positioned.fill(
          child: _ScannerOverlay(),
        ),

        // Processing indicator
        if (_processingQr)
          Positioned(
            top: 16, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Processing...', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),

        // Scan notification
        if (_notification != null)
          Positioned(
            left: 16, right: 16, bottom: 32,
            child: _ScanNotificationCard(
              notification: _notification!,
              onUndo: () => _undoScan(_notification!),
              onRemark: () => _addRemark(_notification!),
              onDismiss: () {
                _notifTimer?.cancel();
                setState(() => _notification = null);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildManualTab() {
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: _labours.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final labour = _labours[i];
            final status = _markedToday[labour.id];
            return _LabourManualTile(
              labour: labour,
              markedStatus: status,
              onMarkPresent: () => _manualMark(labour, 'present'),
              onMarkHalf:    () => _manualMark(labour, 'half'),
            );
          },
        ),
        // Notification overlay on manual tab too
        if (_notification != null)
          Positioned(
            left: 16, right: 16, bottom: 32,
            child: _ScanNotificationCard(
              notification: _notification!,
              onUndo: () => _undoScan(_notification!),
              onRemark: () => _addRemark(_notification!),
              onDismiss: () {
                _notifTimer?.cancel();
                setState(() => _notification = null);
              },
            ),
          ),
      ],
    );
  }
}

// ── QR Camera wrapper (mobile-only, graceful fallback on web) ─────────────────

class _QrCameraView extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  const _QrCameraView({required this.controller, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    try {
      return MobileScanner(controller: controller, onDetect: onDetect);
    } catch (_) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_rounded, color: Colors.white38, size: 64),
              SizedBox(height: 16),
              Text(
                'Camera not available on web.\nUse the Manual tab to mark attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
  }
}

// ── Scanner overlay ───────────────────────────────────────────────────────────

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: Text(
            'Align QR code within the frame',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutout  = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.72,
      height: size.width * 0.72,
    );
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final full  = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(16))),
      ),
      paint,
    );
    // Corner accents
    final accent = Paint()
      ..color  = AppColors.primary
      ..strokeWidth = 3
      ..style  = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    final r   = cutout.left;
    final t   = cutout.top;
    final ri  = cutout.right;
    final bo  = cutout.bottom;
    // TL
    canvas.drawLine(Offset(r, t + len), Offset(r, t), accent);
    canvas.drawLine(Offset(r, t), Offset(r + len, t), accent);
    // TR
    canvas.drawLine(Offset(ri - len, t), Offset(ri, t), accent);
    canvas.drawLine(Offset(ri, t), Offset(ri, t + len), accent);
    // BL
    canvas.drawLine(Offset(r, bo - len), Offset(r, bo), accent);
    canvas.drawLine(Offset(r, bo), Offset(r + len, bo), accent);
    // BR
    canvas.drawLine(Offset(ri - len, bo), Offset(ri, bo), accent);
    canvas.drawLine(Offset(ri, bo), Offset(ri, bo - len), accent);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Scan notification data ────────────────────────────────────────────────────

class _ScanNotification {
  final String labourId;
  final String labourName;
  final String status;
  final String message;
  final bool isError;
  final String? rawToken;

  const _ScanNotification({
    required this.labourId,
    required this.labourName,
    required this.status,
    required this.message,
    required this.isError,
    this.rawToken,
  });
}

// ── Scan notification card ────────────────────────────────────────────────────

class _ScanNotificationCard extends StatelessWidget {
  final _ScanNotification notification;
  final VoidCallback onUndo;
  final VoidCallback onRemark;
  final VoidCallback onDismiss;

  const _ScanNotificationCard({
    required this.notification,
    required this.onUndo,
    required this.onRemark,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = !notification.isError;
    final bg = isSuccess ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D);
    final iconColor = isSuccess ? const Color(0xFF34D399) : const Color(0xFFF87171);
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSuccess
                ? const Color(0xFF34D399).withValues(alpha: 0.4)
                : const Color(0xFFF87171).withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notification.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ),
              ],
            ),
            if (isSuccess) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _NotifButton(
                    icon: Icons.undo_rounded,
                    label: 'Undo',
                    onTap: onUndo,
                    color: const Color(0xFFF87171),
                  ),
                  const SizedBox(width: 8),
                  _NotifButton(
                    icon: Icons.edit_note_rounded,
                    label: 'Add Remark',
                    onTap: onRemark,
                    color: const Color(0xFF60A5FA),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _NotifButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Remark bottom sheet ───────────────────────────────────────────────────────

class _RemarkSheet extends StatelessWidget {
  final TextEditingController controller;
  const _RemarkSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Remark',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Late arrival, only morning shift',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Absent mark bottom sheet ──────────────────────────────────────────────────

class _AbsentMarkSheet extends StatefulWidget {
  final List<Labour> labours;
  final void Function(List<String>) onConfirm;
  final VoidCallback onSkip;

  const _AbsentMarkSheet({
    required this.labours,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  State<_AbsentMarkSheet> createState() => _AbsentMarkSheetState();
}

class _AbsentMarkSheetState extends State<_AbsentMarkSheet> {
  final Set<String> _checked = {};

  @override
  void initState() {
    super.initState();
    _checked.addAll(widget.labours.map((l) => l.id));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark Absents',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'These labours were not scanned today.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: widget.onSkip,
                child: const Text('Skip', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.labours.length,
              itemBuilder: (ctx, i) {
                final labour = widget.labours[i];
                final checked = _checked.contains(labour.id);
                return CheckboxListTile(
                  title: Text(labour.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    labour.skill.isNotEmpty ? labour.skill : 'General',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: checked,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) { _checked.add(labour.id); }
                      else           { _checked.remove(labour.id); }
                    });
                  },
                  activeColor: AppColors.absent,
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
              onPressed: () => widget.onConfirm(_checked.toList()),
              child: Text('Mark ${_checked.length} as Absent'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Labour manual tile ────────────────────────────────────────────────────────

class _LabourManualTile extends StatelessWidget {
  final Labour labour;
  final String? markedStatus;
  final VoidCallback onMarkPresent;
  final VoidCallback onMarkHalf;

  const _LabourManualTile({
    required this.labour,
    this.markedStatus,
    required this.onMarkPresent,
    required this.onMarkHalf,
  });

  @override
  Widget build(BuildContext context) {
    final isMarked = markedStatus != null;
    Color statusColor;
    String statusLabel;
    switch (markedStatus) {
      case 'present': statusColor = AppColors.present; statusLabel = 'Present'; break;
      case 'half':    statusColor = AppColors.halfDay; statusLabel = 'Half Day'; break;
      case 'absent':  statusColor = AppColors.absent;  statusLabel = 'Absent';  break;
      default:        statusColor = Colors.transparent; statusLabel = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMarked
              ? statusColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              labour.name.isNotEmpty ? labour.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + skill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labour.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (labour.skill.isNotEmpty)
                  Text(
                    labour.skill,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // Status or actions
          if (isMarked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
            GestureDetector(
              onTap: onMarkPresent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.present.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'P',
                  style: TextStyle(
                    color: AppColors.present,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onMarkHalf,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.halfDay.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'H',
                  style: TextStyle(
                    color: AppColors.halfDay,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
