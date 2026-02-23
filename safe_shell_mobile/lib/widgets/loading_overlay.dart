import 'dart:ui';
import 'package:flutter/material.dart';

/// Premium glassmorphism loading overlay with animated icon
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

class _GlassLoadingWidgetState extends State<_GlassLoadingWidget> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this)..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _spinController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat();

    _pulseController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1520).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.08), blurRadius: 40, spreadRadius: 5),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated shield spinner
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Spinning ring
                            RotationTransition(
                              turns: _spinController,
                              child: Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 2.5),
                                ),
                                child: CustomPaint(painter: _ArcPainter()),
                              ),
                            ),
                            // Center icon
                            const Icon(Icons.shield_rounded, color: Color(0xFFA855F7), size: 24),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                ),
              ),
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
      ..shader = const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFF8B5CF6)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
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
