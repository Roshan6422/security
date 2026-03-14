import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Confetti overlay to show celebratory particle burst
class ConfettiOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context) {
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (context) => const _ConfettiWidget(),
    );
    Overlay.of(context).insert(_entry!);
    Future.delayed(const Duration(seconds: 3), () {
      _entry?.remove();
      _entry = null;
    });
  }
}

class _ConfettiWidget extends StatefulWidget {
  const _ConfettiWidget();

  @override
  State<_ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<_ConfettiWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 3), vsync: this)..forward();
    _particles = List.generate(50, (_) => _Particle(_rng));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: size,
            painter: _ConfettiPainter(_particles, _controller.value),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x; // 0-1
  final double speed; // fall speed multiplier
  final double size;
  final Color color;
  final double wobble;
  final double rotation;

  _Particle(math.Random rng)
      : x = rng.nextDouble(),
        speed = 0.5 + rng.nextDouble() * 1.5,
        size = 4 + rng.nextDouble() * 6,
        color = [
          const Color(0xFF4DA3FF),
          const Color(0xFF8B5CF6),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
          const Color(0xFFE11D48),
          const Color(0xFFFCD34D),
        ][rng.nextInt(6)],
        wobble = rng.nextDouble() * 3,
        rotation = rng.nextDouble() * math.pi * 2;
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = -50 + (progress * size.height * p.speed * 1.2);
      final x = p.x * size.width + math.sin(progress * math.pi * 4 * p.wobble) * 20;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(0.2);
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2 * p.rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
