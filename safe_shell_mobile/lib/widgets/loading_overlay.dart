import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/device_performance.dart';

/// Loading overlay — simplified on low-end devices (no blur, fewer animations).
class LoadingOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context, {String message = 'Loading...'}) {
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (context) => _GlassLoadingWidget(message: message),
    );
    Overlay.of(context).insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _GlassLoadingWidget extends StatefulWidget {
  final String message;
  const _GlassLoadingWidget({required this.message});

  @override
  State<_GlassLoadingWidget> createState() => _GlassLoadingWidgetState();
}

class _GlassLoadingWidgetState extends State<_GlassLoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skipBlur = DevicePerformance.isLowEnd;

    final card = Container(
      width: 180,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520).withValues(alpha: skipBlur ? 0.95 : 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: skipBlur ? null : [
          BoxShadow(color: const Color(0xFF4DA3FF).withValues(alpha: 0.08), blurRadius: 40, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spinning ring + shield icon
          Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _spinController,
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 2.5),
                  ),
                  child: CustomPaint(painter: _ArcPainter()),
                ),
              ),
              const Icon(Icons.shield_rounded, color: Color(0xFF4DA3FF), size: 24),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: skipBlur
              ? card
              : ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: card,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -0.5,
      2.0,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
