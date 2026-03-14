import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/device_performance.dart';

/// Glassmorphism card widget.
/// On low-end devices, BackdropFilter blur is skipped entirely
/// to avoid GPU-intensive compositing on every frame.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.opacity = 0.05,
    this.borderRadius = 26.0,
    this.padding = const EdgeInsets.all(24.0),
    this.margin,
    this.onTap,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skipBlur = DevicePerformance.isLowEnd;

    final innerDecoration = BoxDecoration(
      color: gradient == null
          ? (isDark ? Colors.white.withOpacity(skipBlur ? 0.06 : 0.03) : Colors.white.withOpacity(skipBlur ? 0.85 : 0.7))
          : null,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.4),
        width: 1.0,
      ),
      gradient: gradient ?? (isDark ? LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(skipBlur ? 0.10 : 0.08),
          Colors.white.withOpacity(skipBlur ? 0.04 : 0.02),
        ],
      ) : LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(skipBlur ? 0.9 : 0.8),
          Colors.white.withOpacity(skipBlur ? 0.6 : 0.4),
        ],
      )),
    );

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    // Low-end: skip BackdropFilter + boxShadow entirely
    if (skipBlur) {
      return Container(
        margin: margin,
        decoration: innerDecoration,
        child: content,
      );
    }

    // Capable devices: full glassmorphism with blur
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: innerDecoration,
            child: content,
          ),
        ),
      ),
    );
  }
}
