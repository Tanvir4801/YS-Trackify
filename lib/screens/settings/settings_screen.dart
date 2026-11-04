import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/theme/app_colors.dart';
import '../../providers/sync_provider.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildSectionHeader(context, 'WORKSPACE'),
          _buildWorkspaceSection(context, ref),
          
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'SECURITY'),
          _buildSecuritySection(context),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
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

  Widget _buildWorkspaceSection(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    
    IconData statusIcon;
    Color statusColor;
    String statusText;
    
    switch (syncStatus) {
      case SyncStatus.synced:
        statusIcon = Icons.check_circle_rounded;
        statusColor = AppColors.successColor(context);
        statusText = 'Data synchronized';
        break;
      case SyncStatus.syncing:
        statusIcon = Icons.sync_rounded;
        statusColor = AppColors.infoColor(context);
        statusText = 'Synchronizing data...';
        break;
      case SyncStatus.pending:
        statusIcon = Icons.cloud_upload_rounded;
        statusColor = AppColors.warningColor(context);
        statusText = 'Changes waiting to sync';
        break;
      case SyncStatus.error:
        statusIcon = Icons.error_rounded;
        statusColor = AppColors.errorColor(context);
        statusText = 'Sync issue — Tap to retry';
        break;
    }

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
        children: [
          InkWell(
            onTap: syncStatus != SyncStatus.syncing
                ? () async {
                    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
                    try {
                      final engine = ref.read(syncEngineProvider);
                      await engine.syncPendingRecords();
                      
                      // Check connectivity before marking as success
                      final isOnline = await ref.read(connectivityServiceProvider).isOnline();
                      if (!isOnline) {
                        ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No internet connection. Sync paused.', style: TextStyle(color: Colors.white)),
                              backgroundColor: AppColors.errorColor(context),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else {
                        ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('All data synchronized successfully!', style: TextStyle(color: Colors.white)),
                              backgroundColor: AppColors.successColor(context),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to sync: $e', style: TextStyle(color: Colors.white)),
                            backgroundColor: AppColors.errorColor(context),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: syncStatus == SyncStatus.syncing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: statusColor),
                          )
                        : Icon(statusIcon, color: statusColor, size: 24),
                  ),
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
                          'Tap to refresh manually',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.refresh_rounded, color: AppColors.textTertiaryColor(context), size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
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
      child: InkWell(
        onTap: () => _handleLogout(context),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorColor(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.logout_rounded, color: AppColors.errorColor(context), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorColor(context),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiaryColor(context), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceColor(context),
        title: Text(
          'Sign Out',
          style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textSecondaryColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondaryColor(context), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorColor(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await AuthService().logout();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}
