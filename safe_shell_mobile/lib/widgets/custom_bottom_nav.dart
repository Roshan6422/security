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
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: navContent,
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final Function(int) onTap;

  const _NavItem({required this.index, required this.currentIndex, required this.icon, required this.label, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool get _isActive => widget.currentIndex == widget.index;

  Color get _activeColor {
    switch (widget.index) {
      case 0: return const Color(0xFFA855F7);
      case 1: return const Color(0xFF8B5CF6);
      case 2: return const Color(0xFF34D399);
      case 3: return const Color(0xFFF59E0B);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skipEffects = DevicePerformance.isLowEnd;

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        HapticFeedback.selectionClick();
        widget.onTap(widget.index);
      },
      onTapCancel: () => _scaleController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: 70,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Glow effect — skip on low-end
              if (_isActive && !skipEffects)
                Positioned(
                  top: 0,
                  child: Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(colors: [_activeColor.withOpacity(0.0), _activeColor, _activeColor.withOpacity(0.0)]),
                      boxShadow: [
                        BoxShadow(color: _activeColor.withOpacity(0.5), blurRadius: 12, spreadRadius: 2),
                      ],
                    ),
                  ),
                ),
              // Simple active indicator for low-end
              if (_isActive && skipEffects)
                Positioned(
                  top: 0,
                  child: Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      color: _activeColor,
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip AnimatedContainer on low-end
                  skipEffects
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            widget.icon,
                            color: _isActive ? _activeColor : Colors.white.withOpacity(0.3),
                            size: 24,
                          ),
                        )
                      : AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _isActive ? _activeColor.withOpacity(0.12) : Colors.transparent,
                          ),
                          child: Icon(
                            widget.icon,
                            color: _isActive ? _activeColor : Colors.white.withOpacity(0.3),
                            size: 24,
                            shadows: _isActive ? [Shadow(color: _activeColor.withOpacity(0.5), blurRadius: 12)] : null,
                          ),
                        ),
                  const SizedBox(height: 3),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: _isActive ? _activeColor : Colors.white.withOpacity(0.3),
                      fontWeight: _isActive ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 10,
                    ),
                  ),
                  // Glowing dot — skip on low-end
                  if (!skipEffects) ...[
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isActive ? 4 : 0,
                      height: _isActive ? 4 : 0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _activeColor,
                        boxShadow: _isActive ? [BoxShadow(color: _activeColor.withOpacity(0.6), blurRadius: 6)] : [],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
