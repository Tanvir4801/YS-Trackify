import 'package:ys_trackify/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LabourHeatmap extends StatefulWidget {
  final String labourId;
  final String contractorId;

  const LabourHeatmap({
    super.key,
    required this.labourId,
    required this.contractorId,
  });

  @override
  State<LabourHeatmap> createState() => _LabourHeatmapState();
}

class _LabourHeatmapState extends State<LabourHeatmap> {
  List<String?> _statuses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLast7Days();
  }

  Future<void> _fetchLast7Days() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('labourId', isEqualTo: widget.labourId)
          .where('contractorId', isEqualTo: widget.contractorId)
          .orderBy('date', descending: true)
          .limit(7)
          .get();

      final statuses = snap.docs.map((d) => d.data()['status'] as String?).toList();
      if (mounted) {
        setState(() {
          _statuses = statuses.reversed.toList(); // chronological
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 10,
        width: 70,
        child: Center(
          child: SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final s = i < _statuses.length ? _statuses[i] : null;
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (s) {
              'present' => const Color(0xFF22C55E),
              'absent' => AppColors.danger,
              'half' => const Color(0xFFF59E0B),
              'half_day' => const Color(0xFFF59E0B),
              _ => const Color(0xFFE5E7EB),
            },
          ),
        );
      }),
    );
  }
}
