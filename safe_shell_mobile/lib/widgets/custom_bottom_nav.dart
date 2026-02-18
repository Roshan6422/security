import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 80 + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            color: const Color(0xFF0A2A4F).withOpacity(0.8),
            border: const Border(
              top: BorderSide(
                color: Colors.white10,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                offset: const Offset(0, -4),
                blurRadius: 24,
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            left: 24,
            right: 24,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.shield_outlined, 'Vault'),
              _buildNavItem(2, Icons.settings_rounded, 'Settings'),
              _buildNavItem(3, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (isActive)
            Positioned(
              top: -12,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isActive ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                ),
                child: Icon(
                  icon,
                  color: isActive ? AppColors.primary : AppColors.textSecondary.withOpacity(0.5),
                  size: 24,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: AppColors.primary.withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textSecondary.withOpacity(0.5),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

