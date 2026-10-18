import 'package:flutter/material.dart';

class LocationPickerPin extends StatelessWidget {
  final bool isMoving;
  final bool isValid;

  const LocationPickerPin({
    super.key,
    this.isMoving = false,
    this.isValid = true,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _error = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final color = isValid ? _gold : _error;

    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(
          0,
          isMoving ? -8 : 0,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dark,
                border: Border.all(
                  color: color,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.30,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.home_rounded,
                color: color,
                size: 29,
              ),
            ),
            CustomPaint(
              size: const Size(20, 13),
              painter: _PinArrowPainter(
                color: color,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isMoving ? 18 : 10,
              height: isMoving ? 6 : 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: isMoving ? 0.18 : 0.30,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinArrowPainter extends CustomPainter {
  final Color color;

  const _PinArrowPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _PinArrowPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}
