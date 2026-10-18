import 'dart:math' as math;
import 'package:flutter/material.dart';

class GoldRingPainter extends CustomPainter {
  final double progress;
  final bool refreshing;
  final double rotation;

  const GoldRingPainter({
    required this.progress,
    required this.refreshing,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    const stroke = 4.0;
    final radius = (size.width / 2) - stroke;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    // الحلقة الخلفية
    final background = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      background,
    );

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(rotation),
      colors: const [
        Color(0x00D4AF37),
        Color(0xFFD4AF37),
        Color(0xFFFFE082),
        Color(0xFFD4AF37),
      ],
      stops: const [
        0.0,
        0.55,
        0.82,
        1.0,
      ],
    );

    final gold = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final sweep = refreshing ? math.pi * 1.65 : (math.pi * 2 * progress);

    final start = refreshing ? rotation : -math.pi / 2;

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      gold,
    );
  }

  @override
  bool shouldRepaint(covariant GoldRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.refreshing != refreshing;
  }
}
