
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart';
import '../../models/labour_model.dart';
import '../../services/auth_service.dart';
import '../../services/hive_service.dart';
import '../../services/labour_mode/labour_firestore_service.dart';
import '../../services/labour_mode/labour_service.dart';
import '../../services/fcm_service.dart';
import '../../providers/branding_provider.dart';
import 'package:provider/provider.dart';
import '../qr/qr_screen.dart';
import 'labour_attendance_screen.dart';
import 'labour_dashboard_screen.dart';
import 'labour_notifications_screen.dart';
import 'labour_wallet_screen.dart';
import 'labour_support_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabourModeShell extends StatefulWidget {
  const LabourModeShell({super.key});

  @override
  State<LabourModeShell> createState() => _LabourModeShellState();
}

class _LabourModeShellState extends State<LabourModeShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 2;
  bool _isLoading = true;
  String? _error;
  late final Labour _labour;
  late final HiveService _hiveService;
  late final LabourService _labourService;
  late final LabourFirestoreService _firestoreService;
  late AnimationController _navAnimController;

  @override
  void initState() {
    super.initState();
    _firestoreService = LabourFirestoreService();
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLabourId = prefs.getString('labourId');
      
      if (cachedLabourId == null || cachedLabourId.isEmpty) {
        throw Exception('No labour session found.');
      }

      final labourDoc = await FirebaseFirestore.instance.collection('labours').doc(cachedLabourId).get();
      if (!labourDoc.exists) throw Exception('Labour account not found.');
      
      final data = labourDoc.data()!;
      final isActive = data['isActive'] as bool? ?? true;
      if (!isActive) throw Exception('Account is disabled.');

      _labour = Labour(
        id: cachedLabourId,
        supervisorId: data['supervisorId'] as String? ?? '',
        name: data['name'] as String? ?? 'Labour',
        phone: data['phone'] as String? ?? '',
        dailyWage: (data['dailyWage'] as num?)?.toDouble() ?? 0.0,
        joiningDate: (data['joiningDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        contractorId: data['contractorId'] as String? ?? '',
      );

      _hiveService = HiveService();
      _labourService = LabourService(hiveService: _hiveService);
      
      // Initialize Push Notifications and save Token
      FCMService().init(_labour.id);
      
      if (mounted) {
        context.read<BrandingProvider>().loadBranding(_labour.contractorId, 'Trackify');
      }

      setState(() { _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading labour session: $e');
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded,   label: 'Home'),
    _NavItem(icon: Icons.fact_check_rounded,  label: 'Attendance'),
    _NavItem(icon: Icons.qr_code_2_rounded,   label: 'ID Card'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Earnings'),
    _NavItem(icon: Icons.help_rounded, label: 'સહાય'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context))),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppColors.errorColor(context), size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppColors.textPrimaryColor(context))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    final screens = [
      LabourDashboardScreen(labour: _labour, firestoreService: _firestoreService),
      LabourAttendanceScreen(labour: _labour, firestoreService: _firestoreService),
      QRScreen(labour: _labour),
      LabourWalletScreen(labour: _labour, firestoreService: _firestoreService),
      LabourSupportScreen(labour: _labour, firestoreService: _firestoreService),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: _PremiumAppBar(
          labour: _labour,
          firestoreService: _firestoreService,
          onLogout: () => _confirmLogout(context),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(context.tr('logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel'), style: TextStyle(color: AppColors.textSecondaryColor(context))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorColor(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              FCMService().clearToken(_labour.id);
              Navigator.of(ctx).pop(true);
            },
            child: Text(context.tr('logout')),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) return;
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _PremiumAppBar extends StatelessWidget {
  const _PremiumAppBar({
    required this.labour,
    required this.firestoreService,
    required this.onLogout,
  });

  final Labour labour;
  final LabourFirestoreService firestoreService;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    // Format date like "Saturday, 18 Jul"
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    return Consumer<BrandingProvider>(
      builder: (ctx, brand, _) {
        final b = brand.branding;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  if (b.logoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        b.logoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.softGold(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryColor(context).withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text(
                          labour.name.isNotEmpty ? labour.name[0].toUpperCase() : 'L',
                          style: TextStyle(color: AppColors.primaryColor(context), fontWeight: FontWeight.w800, fontSize: 20),
                        ),
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Good Morning', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(
                          labour.name,
                          style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w800, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(dateStr, style: TextStyle(color: AppColors.primaryColor(context), fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _AppBarIconBtn(
                        icon: Icons.notifications_rounded,
                        tooltip: 'Notifications',
                        hasIndicator: true,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => LabourNotificationsScreen(
                              labourId: labour.id,
                              firestoreService: firestoreService,
                            )),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _AppBarIconBtn(
                        icon: Icons.exit_to_app_rounded,
                        tooltip: 'Sign Out',
                        onPressed: onLogout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppBarIconBtn extends StatelessWidget {
  const _AppBarIconBtn({required this.icon, required this.tooltip, required this.onPressed, this.hasIndicator = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool hasIndicator;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Stack(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor(context)),
              ),
              child: Icon(icon, color: AppColors.textPrimaryColor(context), size: 20),
            ),
            if (hasIndicator)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.errorColor(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.backgroundColor(context), width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        border: Border(top: BorderSide(color: AppColors.borderColor(context), width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.softGold(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 24,
                        color: isActive ? AppColors.primaryColor(context) : AppColors.textSecondaryColor(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isActive ? AppColors.primaryColor(context) : AppColors.textSecondaryColor(context),
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
