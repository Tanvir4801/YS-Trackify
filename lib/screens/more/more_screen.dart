import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../../core/theme/app_colors.dart';
import '../../providers/branding_provider.dart';
import '../../providers/sites_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/session_service.dart';
import '../notice_board_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/help_support_screen.dart';
import '../settings/about_screen.dart';
import '../../widgets/animations/bouncy_tap.dart';
import '../../core/utils/haptic_utils.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : AppColors.backgroundColor(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text('More', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimaryColor(context))),
        centerTitle: true,
      ),
      body: Consumer<BrandingProvider>(
        builder: (context, brand, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildProfileHeader(context, brand.branding),
              const SizedBox(height: 32),
              
              _buildSectionHeader(context, 'APP'),
              _buildMenuCard(context, [
                _MenuItem(
                  icon: Icons.campaign_rounded,
                  label: 'Notices',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeBoardScreen())),
                ),
                _MenuItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ]),
              
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'APPEARANCE'),
              _buildAppearanceSection(context),

              const SizedBox(height: 24),
              _buildSectionHeader(context, 'WORKSPACE'),
              _buildWorkspaceStatus(context),

              const SizedBox(height: 24),
              _buildSectionHeader(context, 'SUPPORT'),
              _buildMenuCard(context, [
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                ),
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About Trackify',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutTrackifyScreen())),
                ),
              ]),
              
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Trackify V$_version',
                  style: TextStyle(
                    color: AppColors.textTertiaryColor(context), 
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title, 
        style: TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.w700, 
          color: AppColors.textTertiaryColor(context), 
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, dynamic b) {
    final session = SessionService.instance;
    final name = session.name ?? 'Supervisor';
    final role = session.role ?? 'Supervisor';
    
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryColor(context).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryColor(context).withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimaryColor(context)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      role.substring(0, 1).toUpperCase() + role.substring(1),
                      style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.textTertiaryColor(context), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Consumer<SitesProvider>(
                      builder: (context, sites, _) {
                        return Text(
                          'Assigned Sites: ${sites.sites.length}',
                          style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13, fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, List<_MenuItem> items) {
    return Container(
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
        children: List.generate(
          items.length,
          (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            return Column(
              children: [
                BouncyTap(
                  onTap: () {
                    HapticUtils.light();
                    item.onTap();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: isLast && index == 0
                        ? BorderRadius.circular(24)
                        : index == 0
                          ? const BorderRadius.vertical(top: Radius.circular(24))
                          : isLast
                            ? const BorderRadius.vertical(bottom: Radius.circular(24))
                            : BorderRadius.zero,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryColor(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: AppColors.textSecondaryColor(context), size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(item.label, 
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimaryColor(context))
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textTertiaryColor(context), size: 24),
                      ],
                    ),
                  ),
                ),
                if (!isLast) Divider(height: 1, indent: 70, endIndent: 20, color: AppColors.subtleBorderColor(context)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkspaceStatus(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.infoColor(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.infoColor(context).withOpacity(0.1)),
      ),
      child: riverpod.Consumer(
        builder: (context, ref, _) {
          final syncStatus = ref.watch(syncStatusProvider);
          
          IconData statusIcon = Icons.check_circle_rounded;
          Color statusColor = AppColors.successColor(context);
          String statusText = 'Data synchronized';
          
          if (syncStatus == SyncStatus.syncing) {
            statusIcon = Icons.sync_rounded;
            statusColor = AppColors.infoColor(context);
            statusText = 'Synchronizing data...';
          } else if (syncStatus == SyncStatus.pending) {
            statusIcon = Icons.cloud_upload_rounded;
            statusColor = AppColors.warningColor(context);
            statusText = 'Changes waiting to sync';
          } else if (syncStatus == SyncStatus.error) {
            statusIcon = Icons.error_rounded;
            statusColor = AppColors.errorColor(context);
            statusText = 'Sync issue — Tap to retry';
          }
          
          return InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View sync details in Settings',
                          style: TextStyle(
                            fontSize: 13,
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
        },
      ),
    );
  }
  Widget _buildAppearanceSection(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return Column(
            children: [
              _buildThemeOption(
                context,
                title: 'System Default',
                icon: Icons.brightness_auto_rounded,
                isSelected: themeProvider.themeMode == ThemeMode.system,
                onTap: () => themeProvider.setThemeMode(ThemeMode.system),
              ),
              Divider(height: 1, color: AppColors.subtleBorderColor(context), indent: 56, endIndent: 20),
              _buildThemeOption(
                context,
                title: 'Light',
                icon: Icons.light_mode_rounded,
                isSelected: themeProvider.themeMode == ThemeMode.light,
                onTap: () => themeProvider.setThemeMode(ThemeMode.light),
              ),
              Divider(height: 1, color: AppColors.subtleBorderColor(context), indent: 56, endIndent: 20),
              _buildThemeOption(
                context,
                title: 'Dark',
                icon: Icons.dark_mode_rounded,
                isSelected: themeProvider.themeMode == ThemeMode.dark,
                onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primaryColor(context).withOpacity(0.1)
                    : AppColors.textTertiaryColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon, 
                size: 20, 
                color: isSelected 
                    ? AppColors.primaryColor(context)
                    : AppColors.textSecondaryColor(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? AppColors.primaryColor(context)
                      : AppColors.textPrimaryColor(context),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppColors.primaryColor(context), size: 22),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _MenuItem({required this.icon, required this.label, required this.onTap});
}
