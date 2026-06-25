import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../main.dart';
import '../services/auth_service.dart';

class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, Color(0xFF15203A)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(top: -60, right: -60,
                child: Container(width: 200, height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.05)))),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Gold icon container
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.navyLight,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: AppColors.gold.withValues(alpha: 0.2),
                            blurRadius: 28, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: const Icon(Icons.desktop_windows_outlined,
                        size: 44, color: AppColors.gold),
                    ),
                    const SizedBox(height: 28),
                    const Text('Admin Access Only',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'This account type is not supported on the mobile app.\n'
                      'Please sign in to the web admin panel from your browser.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14, height: 1.6)),
                    const SizedBox(height: 36),
                    // Gold divider
                    Container(height: 1, width: 60,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, AppColors.gold, Colors.transparent]))),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await AuthService().logout();
                          if (!navigator.mounted) return;
                          navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.gold),
                        label: const Text('Sign Out',
                          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
