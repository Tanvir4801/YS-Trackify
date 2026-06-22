import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/site_data_provider.dart';
import '../../providers/sites_provider.dart';
import '../../widgets/animations/bouncy_tap.dart';
import '../../core/utils/haptic_utils.dart';
import 'help_support_screen.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  PackageInfo? _info;
  int _tapCount = 0;
  bool _developerModeUnlocked = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  void _onVersionTap() {
    if (_developerModeUnlocked) return;
    
    setState(() {
      _tapCount++;
      if (_tapCount >= 7) {
        _developerModeUnlocked = true;
        HapticUtils.heavy();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Developer Options Unlocked', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.gold,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else if (_tapCount >= 3) {
        HapticUtils.light();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tap ${7 - _tapCount} more times to unlock developer mode', style: const TextStyle(color: Colors.white70)),
            backgroundColor: AppColors.navyLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      } else {
        HapticUtils.light();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text('About Trackify',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 60),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildHeroSection(),
          const SizedBox(height: 24),
          _buildLiveWorkspaceStats(),
          const SizedBox(height: 32),
          _buildPremiumCardSection(
            'Security & Cloud Infrastructure',
            Icons.security_rounded,
            [
              _buildFeatureTile(Icons.enhanced_encryption_rounded, 'Data Security', '256-bit AES Encryption In-Transit'),
              _buildFeatureTile(Icons.cloud_sync_rounded, 'Cloud Sync', 'Real-time Firebase Synchronization'),
              _buildFeatureTile(Icons.admin_panel_settings_rounded, 'Access Control', 'Enterprise Role-Based Permissions'),
            ],
          ),
          const SizedBox(height: 24),
          _buildPremiumCardSection(
            'Technical Architecture',
            Icons.architecture_rounded,
            [
              _buildFeatureTile(Icons.layers_rounded, 'Frontend Engine', 'Flutter Framework (Multi-Platform)'),
              _buildFeatureTile(Icons.storage_rounded, 'Database', 'Cloud Firestore (NoSQL)'),
              _buildFeatureTile(Icons.memory_rounded, 'Offline Cache', 'Hive Local Storage'),
            ],
          ),
          const SizedBox(height: 24),
          _buildPremiumCardSection(
            'Enterprise Support',
            Icons.support_agent_rounded,
            [
              _buildContactTile(
                icon: Icons.phone_rounded,
                title: 'Phone Support',
                value: '+91 7621984915',
                onTap: () => _launchUrl('tel:+917621984915'),
              ),
              _buildContactTile(
                icon: Icons.support_agent_outlined,
                title: 'Help Desk',
                value: 'Submit a support ticket',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
              ),
              _buildContactTile(
                icon: Icons.email_rounded,
                title: 'Email',
                value: 'trackify@support.com',
                onTap: () => _launchUrl('mailto:trackify@support.com'),
              ),
            ],
          ),
          if (_developerModeUnlocked) ...[
            const SizedBox(height: 24),
            _buildDeveloperOptions(),
          ],
          const SizedBox(height: 40),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: AppColors.gold.withValues(alpha: 0.3),
                  blurRadius: 32, spreadRadius: 4, offset: const Offset(0, 8)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.architecture_rounded, color: AppColors.gold, size: 52),
          ),
          const SizedBox(height: 24),
          const Text('TRACKIFY',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 3.0)),
          const SizedBox(height: 6),
          const Text('Enterprise Workforce Management',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _onVersionTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: Text(
                'v${_info?.version ?? '—'} (Build ${_info?.buildNumber ?? '—'})',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveWorkspaceStats() {
    return Consumer2<SitesProvider, SiteDataProvider>(
      builder: (context, sitesProv, dataProv, _) {
        final totalSites = sitesProv.sites.length;
        final totalLabours = dataProv.labours.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text('LIVE WORKSPACE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textTertiary, letterSpacing: 1.5)),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Active Sites',
                      totalSites.toString(),
                      Icons.location_city_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Workforce',
                      totalLabours.toString(),
                      Icons.engineering_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPremiumCardSection(String title, IconData headerIcon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(headerIcon, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(title.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textTertiary, letterSpacing: 1.5)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    const Divider(height: 1, thickness: 1, color: AppColors.navy, indent: 56, endIndent: 16),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return BouncyTap(
      onTap: () {
        HapticUtils.light();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textTertiary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperOptions() {
    return _buildPremiumCardSection(
      'Developer Options',
      Icons.developer_mode_rounded,
      [
        _buildFeatureTile(Icons.bug_report_rounded, 'Environment', 'Production (ys-trackify)'),
        _buildFeatureTile(Icons.api_rounded, 'API Target', 'v1.4 - Firebase Functions'),
        _buildContactTile(
          icon: Icons.copy_all_rounded,
          title: 'Session Identifier',
          value: 'Copy Device ID',
          onTap: () {
            Clipboard.setData(const ClipboardData(text: 'DEV-ID-99382-TRACKIFY'));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Device ID copied to clipboard'),
                backgroundColor: AppColors.navyLight,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )
            );
          },
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Icon(Icons.architecture_rounded, color: AppColors.textTertiary, size: 24),
        const SizedBox(height: 12),
        const Text('Designed for Civil Engineering & Construction',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('© ${DateTime.now().year} YS Trackify. All rights reserved.',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch application')),
        );
      }
    }
  }
}
