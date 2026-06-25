import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../main.dart';
import '../../services/auth_service.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('About Trackify',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        children: [
          // Logo hero
          Center(
            child: Container(
              width: 92, height: 92,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: AppColors.gold.withValues(alpha: 0.2),
                    blurRadius: 24, offset: const Offset(0, 8)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.track_changes_rounded, color: AppColors.gold, size: 46),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Trackify',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
          Center(
            child: Text('Version ${_info?.version ?? '—'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          const SizedBox(height: 32),

          _sectionLabel('App Details'),
          const SizedBox(height: 8),
          _infoTile(Icons.apps_rounded,       'App Name',     'Trackify — Labour Attendance'),
          _infoTile(Icons.tag_rounded,         'Version',      _info?.version ?? '—'),
          _infoTile(Icons.build_rounded,       'Build',        _info?.buildNumber ?? '—'),
          _infoTile(Icons.devices_rounded,     'Platforms',    'Android, iOS & Web'),
          const SizedBox(height: 20),

          _sectionLabel('Technical'),
          const SizedBox(height: 8),
          _infoTile(Icons.cloud_rounded,       'Backend',      'Firebase Firestore'),
          _infoTile(Icons.storage_rounded,     'Local Cache',  'Hive (IndexedDB on Web)'),
          _infoTile(Icons.business_rounded,    'Developer',    'YS Construction'),
          const SizedBox(height: 32),

          // Sign out button
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await AuthService().logout();
                if (context.mounted) {
                  navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                }
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.absent, size: 18),
              label: const Text('Sign Out',
                style: TextStyle(color: AppColors.absent, fontWeight: FontWeight.w700, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.absent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Text(title.toUpperCase(),
      style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: AppColors.textTertiary, letterSpacing: 1.0));
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.navy),
          const SizedBox(width: 12),
          Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
