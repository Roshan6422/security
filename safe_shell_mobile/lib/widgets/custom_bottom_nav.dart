import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../utils/device_performance.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skipBlur = DevicePerformance.isLowEnd;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final navContent = Container(
      height: 80 + bottomPadding,
      decoration: BoxDecoration(
        // On low-end: solid dark bg instead of blur
        color: skipBlur ? const Color(0xFF050A12) : null,
        gradient: skipBlur ? null : LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF050A12).withOpacity(0.85),
            const Color(0xFF050A12).withOpacity(0.95),
          ],
        ),
        border: const Border(
          top: BorderSide(color: Color(0x10FFFFFF), width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: bottomPadding,
        left: 12,
        right: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(index: 0, currentIndex: currentIndex, icon: Icons.home_rounded, label: 'Home', onTap: onTap),
          _NavItem(index: 1, currentIndex: currentIndex, icon: Icons.shield_outlined, label: 'Vault', onTap: onTap),
          _NavItem(index: 2, currentIndex: currentIndex, icon: Icons.settings_rounded, label: 'Settings', onTap: onTap),
          _NavItem(index: 3, currentIndex: currentIndex, icon: Icons.person_rounded, label: 'Profile', onTap: onTap),
        ],
      ),
    );

    // Low-end: skip blur entirely
    if (skipBlur) return navContent;

    // Capable devices: full blur
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: navContent,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final Function(int) onTap;

  const _NavItem({required this.index, required this.currentIndex, required this.icon, required this.label, required this.onTap});

  bool get _isActive => currentIndex == index;

  Color get _activeColor {
    switch (index) {
      case 0: return const Color(0xFF4DA3FF);
      case 1: return const Color(0xFF8B5CF6);
      case 2: return const Color(0xFF10B981);
      case 3: return const Color(0xFFF59E0B);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                icon,
                color: _isActive ? _activeColor : Colors.white.withOpacity(0.3),
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: _isActive ? _activeColor : Colors.white.withOpacity(0.3),
                fontWeight: _isActive ? FontWeight.w700 : FontWeight.w400,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
