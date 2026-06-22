import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/super_admin_provider.dart';
import '../../../services/auth_service.dart';
import '../../../main.dart'; // For AppRoutes

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SuperAdminProvider>().loadStats();
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService().logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep premium background
      appBar: AppBar(
        title: const Text('Super Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.gold),
            onPressed: () => context.read<SuperAdminProvider>().loadStats(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Consumer<SuperAdminProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }

          final stats = provider.stats;
          if (stats == null) {
            return const Center(
              child: Text('Failed to load stats', style: TextStyle(color: Colors.red)),
            );
          }

          final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
          final numberFormatter = NumberFormat('#,##,###');

          return RefreshIndicator(
            onRefresh: () => provider.loadStats(),
            color: AppColors.gold,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'SaaS Platform Overview',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),

                // Main Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Contractors',
                        numberFormatter.format(stats.totalContractors),
                        Icons.business,
                        Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Premium Users',
                        numberFormatter.format(stats.premiumUsers),
                        Icons.workspace_premium,
                        AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Large Revenue Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.navy, AppColors.navy.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_wallet, color: AppColors.gold, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Monthly Revenue',
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currencyFormatter.format(stats.monthlyRevenue),
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Labour',
                        numberFormatter.format(stats.totalLabour),
                        Icons.people_alt,
                        Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Today\'s Attendance',
                        numberFormatter.format(stats.todayAttendance),
                        Icons.check_circle_outline,
                        Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bottom Stats Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildStatCard(
                        'Most Active',
                        stats.activeContractorName,
                        Icons.star,
                        Colors.deepPurpleAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildStatCard(
                        'Storage',
                        stats.storageUsage,
                        Icons.cloud,
                        Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
