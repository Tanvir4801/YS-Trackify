import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../models/labour_model.dart';
// Note: We need to push to LabourProfileScreen, typically named LabourDetailScreen or similar.
// I will just use pushNamed('/labour-profile', arguments: labour) or let the user handle it if the route is different. 
// Assuming the app has a standard navigation route or we can pass a callback for full profile.

class LabourQuickSheet extends StatefulWidget {
  final Labour labour;

  const LabourQuickSheet({super.key, required this.labour});

  static void show(BuildContext context, Labour labour) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LabourQuickSheet(labour: labour),
    );
  }

  @override
  State<LabourQuickSheet> createState() => _LabourQuickSheetState();
}

class _LabourQuickSheetState extends State<LabourQuickSheet> {
  bool _loading = true;
  String _todayStatus = 'Not Marked';
  double _monthAdvance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final monthPrefix = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      // Fetch today's attendance
      final attSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('labourId', isEqualTo: widget.labour.id)
          .where('date', isEqualTo: todayStr)
          .limit(1)
          .get();
      if (attSnap.docs.isNotEmpty) {
        _todayStatus = attSnap.docs.first.data()['status'] ?? 'Not Marked';
      }

      // Fetch month advances
      // Usually stored in 'advances' or 'payments'
      final advSnap = await FirebaseFirestore.instance
          .collection('advances')
          .where('labourId', isEqualTo: widget.labour.id)
          // We can't filter by startswith easily, so just get recent and filter in memory or get all for labour
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      double adv = 0.0;
      for (final doc in advSnap.docs) {
        final data = doc.data();
        final date = data['date'] as String? ?? '';
        if (date.startsWith(monthPrefix)) {
          adv += (data['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      if (mounted) {
        setState(() {
          _monthAdvance = adv;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labour = widget.labour;
    final initials = labour.name.isNotEmpty ? labour.name[0].toUpperCase() : 'L';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
                  )),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labour.name, style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
                    )),
                    const SizedBox(height: 4),
                    Text(labour.type == LabourType.regular ? 'Regular' : 'Temporary', style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary,
                    )),
                  ],
                ),
              ),
              // Call Button
              GestureDetector(
                onTap: () async {
                  if (labour.phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No phone number for ${labour.name}')),
                    );
                    return;
                  }
                  final uri = Uri.parse('tel:${labour.phone}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Today',
                    value: _todayStatus.toUpperCase(),
                    valueColor: _todayStatus == 'present' ? AppColors.present 
                        : (_todayStatus == 'absent' ? AppColors.absent : AppColors.halfDay),
                    icon: Icons.fact_check_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Month Advance',
                    value: '₹${_monthAdvance.toStringAsFixed(0)}',
                    valueColor: AppColors.textPrimary,
                    icon: Icons.currency_rupee_rounded,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                // Currently navigating to '/labour_profile'. We will need to check routes.
                // It might be named differently, e.g. /labour-detail
                // I will use a fallback or simply log. For now, pop.
                // Assuming route is defined:
                Navigator.pushNamed(context, '/labour-detail', arguments: labour);
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View Full Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(
                fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: valueColor,
          ), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
