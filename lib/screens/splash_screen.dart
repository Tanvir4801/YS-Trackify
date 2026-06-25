import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _footerOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _logoScale   = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 0.7, curve: Curves.easeOut)));
    _textSlide   = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic)));
    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)));

    _ctrl.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    final result = await AuthService().checkCurrentUser();
    if (!mounted) return;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    if (result == null || !result.success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      return;
    }
    if (result.role == 'supervisor' || result.role == 'admin') {
      Navigator.of(context).pushNamedAndRemoveUntil('/supervisor-home', (r) => false);
      return;
    }
    if (result.role == 'labour') {
      Navigator.of(context).pushNamedAndRemoveUntil('/labour-home', (r) => false);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/unauthorized', (r) => false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, Color(0xFF15203A), Color(0xFF0A1020)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative glow orbs
              Positioned(top: -100, right: -80,
                child: Container(width: 280, height: 280,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.06)))),
              Positioned(bottom: 60, left: -80,
                child: Container(width: 200, height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: AppColors.goldLight.withValues(alpha: 0.04)))),

              // Main content
              Center(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Column(mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo icon
                      FadeTransition(
                        opacity: _logoOpacity,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.navyLight, AppColors.navy.withValues(alpha: 0.9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.45), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: AppColors.gold.withValues(alpha: 0.3),
                                  blurRadius: 36, offset: const Offset(0, 14)),
                                BoxShadow(color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 24, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: const Icon(Icons.track_changes_rounded, size: 50, color: AppColors.gold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title + subtitle
                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Column(children: [
                            const Text('TRACKIFY',
                              style: TextStyle(color: Colors.white, fontSize: 32,
                                fontWeight: FontWeight.w900, letterSpacing: 5)),
                            const SizedBox(height: 8),
                            Text('From Site to System',
                              style: TextStyle(
                                color: AppColors.gold.withValues(alpha: 0.75),
                                fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 1.5)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 52),

                      // Pulsing dots loader
                      FadeTransition(
                        opacity: _footerOpacity,
                        child: Row(mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (i) => AnimatedBuilder(
                            animation: _ctrl,
                            builder: (_, __) {
                              final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
                              final pulse = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 7 + pulse * 3,
                                height: 7 + pulse * 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.gold.withValues(alpha: 0.35 + pulse * 0.65),
                                ),
                              );
                            },
                          ))),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer credit
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: _footerOpacity,
                  builder: (_, __) => Opacity(
                    opacity: _footerOpacity.value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text('YS Construction · Developed by Tanvir Patel',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 11, letterSpacing: 0.4)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
