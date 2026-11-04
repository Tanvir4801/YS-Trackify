import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class TrackifyBottomNav extends StatelessWidget {
  const TrackifyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        border: Border(
          top: BorderSide(color: AppColors.borderColor(context).withValues(alpha: 0.5), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: _NavItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  isActive: isActive,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  static const List<_NavItemData> _items = [
    _NavItemData(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItemData(Icons.fact_check_outlined, Icons.fact_check_rounded, 'Attendance'),
    _NavItemData(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Reports'),
    _NavItemData(Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'More'),
  ];
}

class _NavItemData {
  const _NavItemData(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryColor(context).withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.primaryColor(context) : AppColors.textTertiaryColor(context),
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primaryColor(context) : AppColors.textTertiaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
