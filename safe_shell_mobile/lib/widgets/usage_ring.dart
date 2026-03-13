import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class UsageRing extends StatelessWidget {
  final double value; // 0 to 100

  const UsageRing({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(44, 44),
              painter: _RingPainter(
                progress: value,
                color: AppColors.primary,
                backgroundColor: isLight ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Center(
            child: Text(
              '${value.round()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isLight ? AppColors.textPrimary : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;
    final strokeWidth = 4.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * (progress / 100);
    // Start from -90 degrees (top)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => 
      oldDelegate.progress != progress;
}

