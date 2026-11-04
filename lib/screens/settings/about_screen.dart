import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/branding_provider.dart';
import '../../providers/labour_provider.dart';
import '../../providers/sites_provider.dart';
import 'help_support_screen.dart';

class AboutTrackifyScreen extends StatefulWidget {
  const AboutTrackifyScreen({super.key});

  @override
  State<AboutTrackifyScreen> createState() => _AboutTrackifyScreenState();
}

class _AboutTrackifyScreenState extends State<AboutTrackifyScreen> {
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
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: Text(
          'About Trackify',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        backgroundColor: AppColors.backgroundColor(context),
        foregroundColor: AppColors.textPrimaryColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildBrandHeader(context),
          const SizedBox(height: 32),
          _buildLiveWorkspace(context),
          const SizedBox(height: 32),
          _buildSecurityReliability(context),
          const SizedBox(height: 32),
          _buildSupervisorSupport(context),
          const SizedBox(height: 32),
          _buildAboutDescription(context),
          const SizedBox(height: 48),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Consumer<BrandingProvider>(
      builder: (context, brandingProvider, _) {
        final logoUrl = brandingProvider.branding.logoUrl;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.subtleBorderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? Image.network(logoUrl, height: 64, width: 64, fit: BoxFit.contain)
                  : Icon(Icons.domain_rounded, size: 64, color: AppColors.primaryColor(context)),
            ),
            const SizedBox(height: 24),
            Text(
              'TRACKIFY',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enterprise Workforce Management',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 12),
            if (_info != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v${_info!.version} (Build ${_info!.buildNumber})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor(context),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLiveWorkspace(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'LIVE WORKSPACE'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Consumer<SitesProvider>(
                builder: (context, sites, _) {
                  return _buildStatCard(
                    context,
                    title: 'Active Sites',
                    value: sites.sites.length.toString(),
                    icon: Icons.business_center_rounded,
                    backgroundColor: AppColors.infoColor(context).withValues(alpha: 0.15),
                    iconColor: AppColors.infoColor(context),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Consumer<LabourProvider>(
                builder: (context, labour, _) {
                  return _buildStatCard(
                    context,
                    title: 'Workforce',
                    value: labour.labours.length.toString(),
                    icon: Icons.people_alt_rounded,
                    backgroundColor: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    iconColor: const Color(0xFF9C27B0),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: iconColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityReliability(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'SECURITY & RELIABILITY'),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.subtleBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildFeatureTile(
                context,
                icon: Icons.shield_rounded,
                iconColor: AppColors.primaryColor(context),
                title: 'Data Protection',
                subtitle: 'Your workforce and operational data is protected.',
              ),
              Divider(height: 1, color: AppColors.subtleBorderColor(context), indent: 64, endIndent: 20),
              _buildFeatureTile(
                context,
                icon: Icons.lock_person_rounded,
                iconColor: AppColors.primaryColor(context),
                title: 'Secure Access',
                subtitle: 'Role-based access keeps supervisor actions controlled.',
              ),
              Divider(height: 1, color: AppColors.subtleBorderColor(context), indent: 64, endIndent: 20),
              _buildFeatureTile(
                context,
                icon: Icons.sync_rounded,
                iconColor: AppColors.successColor(context),
                title: 'Reliable Sync',
                subtitle: 'Attendance and site information stays synchronized.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupervisorSupport(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'SUPERVISOR SUPPORT'),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.subtleBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildActionTile(
                context,
                icon: Icons.phone_rounded,
                iconColor: AppColors.infoColor(context),
                title: 'Phone Support',
                subtitle: '+91 7621984915',
                onTap: () => _launchUrl('tel:+917621984915'),
              ),
              Divider(height: 1, color: AppColors.subtleBorderColor(context), indent: 64, endIndent: 20),
              _buildActionTile(
                context,
                icon: Icons.support_agent_rounded,
                iconColor: const Color(0xFF9C27B0),
                title: 'Help Desk',
                subtitle: 'Submit a support ticket',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
              ),
              Divider(height: 1, color: AppColors.subtleBorderColor(context), indent: 64, endIndent: 20),
              _buildActionTile(
                context,
                icon: Icons.email_rounded,
                iconColor: AppColors.primaryColor(context),
                title: 'Email',
                subtitle: 'trackify@support.com',
                onTap: () => _launchUrl('mailto:trackify@support.com'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutDescription(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'ABOUT TRACKIFY'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondaryColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.subtleBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trackify is an enterprise workforce management platform built for civil engineering and construction teams. It helps supervisors manage sites, track labour attendance, monitor workforce costs, and keep daily operations organized from one place.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'KEY FEATURES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 16),
              _buildCheckFeature(context, 'Site & Workforce Management'),
              _buildCheckFeature(context, 'Labour Attendance Tracking'),
              _buildCheckFeature(context, 'Daily Labour Cost Monitoring'),
              _buildCheckFeature(context, 'Materials & Site Cost Management'),
              _buildCheckFeature(context, 'Daily Closing & Reports'),
              _buildCheckFeature(context, 'Workforce Insights'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckFeature(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.successColor(context), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Consumer<BrandingProvider>(
      builder: (context, brand, _) {
        return Column(
          children: [
            Text(
              brand.branding.companyName.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Designed for Civil Engineering & Construction',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '© ${DateTime.now().year} Trackify. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiaryColor(context),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textTertiaryColor(context),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryColor(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiaryColor(context), size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
