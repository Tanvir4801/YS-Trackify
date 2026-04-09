import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization/app_text.dart';
import '../core/theme/app_colors.dart';
import '../main.dart';
import '../providers/language_provider.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF2F8FC),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -16,
            child: Icon(
              Icons.home_work_outlined,
              size: 100,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),

            Positioned(
            top: 50,
            left: -20,
            child: Icon(
              Icons.home_work_outlined,
              size: 100,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),

          Positioned(
            left: -20,
            bottom: 320,
            child: Transform.rotate(
              angle: 0.44,
              child: Icon(
                Icons.roofing_outlined,
                size: 150,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: -24,
            bottom: 60,
            child: Transform.rotate(
              angle: -0.14,
              child: Icon(
                Icons.roofing_outlined,
                size: 170,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AppLanguage>(
                        value: language,
                        borderRadius: BorderRadius.circular(12),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          context.read<LanguageProvider>().setLanguage(value);
                        },
                        items: [
                          DropdownMenuItem(
                            value: AppLanguage.english,
                            child: Text(context.tr('english')),
                          ),
                          DropdownMenuItem(
                            value: AppLanguage.hindi,
                            child: Text(context.tr('hindi')),
                          ),
                          DropdownMenuItem(
                            value: AppLanguage.gujarati,
                            child: Text(context.tr('gujarati')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 60),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color.fromARGB(255, 29, 47, 60).withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.roofing,
                            color: AppColors.primary,
                            size: 43,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'YS Construction',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'From Site to System',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.primary.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 38, 59, 75).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.supervisorPin);
                      },
                      icon: const Icon(Icons.lock_outline),
                      label: Text(context.tr('supervisorDashboard')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      side: BorderSide(
                        color: const Color.fromARGB(255, 59, 100, 132).withValues(alpha: 0.45),
                        width: 1.3,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.85),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed(AppRoutes.labourSelection);
                    },
                    icon: const Icon(Icons.badge_outlined),
                    label: Text(context.tr('labourMode')),
                  ),
                  const Spacer(),
                  Text(
                    'Developed by Tanvir_Patel',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
