import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/site_data_provider.dart';
import '../services/session_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _attendanceSub;
  StreamSubscription? _labourSub;

  int _totalLabours = 0;
  int _presentToday = 0;
  int _absentToday = 0;
  int _halfDayToday = 0;
  double _todayWages = 0;
  double _weekWages = 0;
  double _monthWages = 0;

  @override
  void initState() {
    super.initState();
    _startStreams();
  }

  void _startStreams() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final contractorId = SessionService.instance.contractorId ?? uid;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _labourSub?.cancel();
    _labourSub = _db
        .collection('labours')
        .where('contractorId', isEqualTo: contractorId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _totalLabours = snap.docs.length);
    });

    _attendanceSub?.cancel();
    _attendanceSub = _db
        .collection('attendance')
        .doc(contractorId)
        .collection('dates')
        .doc(today)
        .collection('records')
        .snapshots()
        .listen((snap) {
      int present = 0;
      int absent = 0;
      int halfDay = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        switch (status) {
          case 'present':
            present++;
            break;
          case 'absent':
            absent++;
            break;
          case 'half_day':
            halfDay++;
            break;
        }
      }

      if (mounted) {
        setState(() {
          _presentToday = present;
          _absentToday = absent;
          _halfDayToday = halfDay;
        });
      }

      _db
          .collection('labours')
          .where('contractorId', isEqualTo: contractorId)
          .where('isActive', isEqualTo: true)
          .get()
          .then((labourSnap) {
        double total = 0;
        for (final doc in labourSnap.docs) {
          final d = doc.data();
          final rate = (d['dailyWage'] ?? d['dailyRate'] ?? 0).toDouble();
          total += rate * present;
        }
        if (mounted) setState(() => _todayWages = total);
      });
    });
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _labourSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteDataProvider>(
      builder: (context, data, _) {
        return SafeArea(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: () async {
              _startStreams();
              context.read<SiteDataProvider>().startLabourStream();
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YS Construction',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'From Site to System',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Stat cards grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _buildStatCard(
                        title: 'Total Labour',
                        value: '$_totalLabours',
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF1E40AF),
                      ),
                      _buildStatCard(
                        title: 'Present Today',
                        value: '$_presentToday',
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF16A34A),
                      ),
                      _buildStatCard(
                        title: 'Absent Today',
                        value: '$_absentToday',
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFFDC2626),
                      ),
                      _buildStatCard(
                        title: 'Half Day',
                        value: '$_halfDayToday',
                        icon: Icons.timelapse_rounded,
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Wage Snapshot',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildWageCard(
                    label: 'Today',
                    amount: _todayWages,
                    icon: Icons.today_rounded,
                    color: const Color(0xFF0891B2),
                    subtitle: 'Based on attendance',
                  ),
                  const SizedBox(height: 10),
                  _buildWageCard(
                    label: 'This Week',
                    amount: data.weekWageTotal,
                    icon: Icons.date_range_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(height: 10),
                  _buildWageCard(
                    label: 'This Month',
                    amount: data.monthWageTotal,
                    icon: Icons.calendar_month_rounded,
                    color: const Color(0xFF059669),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWageCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
