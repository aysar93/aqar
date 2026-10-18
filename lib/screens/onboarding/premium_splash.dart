import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// One 4.6-second timeline. Text is shaped as complete Arabic strings.
class PremiumSplash extends StatelessWidget {
  const PremiumSplash({super.key, required this.animation});
  final Animation<double> animation;
  static const duration = Duration(milliseconds: 4600);
  static const background = AppTheme.backgroundColor;
  double phase(double t, double start, double end) => Curves.easeOutCubic
      .transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: background,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value * 4.6;
            final reduced = MediaQuery.disableAnimationsOf(context);
            final logo = reduced ? 1.0 : phase(t, 1, 2.2);
            final name = reduced ? 1.0 : phase(t, 2, 3);
            final tagline = reduced ? 1.0 : phase(t, 3, 4);
            return LayoutBuilder(
              builder: (context, bounds) {
                final markSize = math.min(174.0, bounds.maxWidth * .43);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: background,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: math.min(bounds.maxHeight * .24, 205),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: CityPainter(
                            progress: reduced ? 1 : phase(t, 0, 1.2),
                            light: reduced ? 2 : t / 1.7,
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Opacity(
                                opacity: logo,
                                child: Transform.translate(
                                  offset: Offset(0, 7 * (1 - logo)),
                                  child: Transform.scale(
                                    scale: .94 + .06 * logo,
                                    child: Container(
                                      width: markSize,
                                      height: markSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF766035,
                                            ).withValues(alpha: .12 * logo),
                                            blurRadius: 28,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // Display the official source at full resolution; the viewport
                                            // isolates its circular seal without resampling the asset.
                                            Transform.translate(
                                              offset:
                                                  Offset(0, markSize * .036),
                                              child: Transform.scale(
                                                  scale: 1.42,
                                                  child: Image.asset(
                                                    'assets/images/logo.png',
                                                    fit: BoxFit.cover,
                                                    alignment: const Alignment(
                                                        0, -.04),
                                                    filterQuality:
                                                        FilterQuality.high,
                                                  )),
                                            ),
                                            if (!reduced && t > 1.35 && t < 2.3)
                                              CustomPaint(
                                                painter: LogoLight(
                                                  (t - 1.35) / .95,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              _text(
                                'عقارات الانبار',
                                name,
                                32,
                                FontWeight.w700,
                                Colors.white,
                                8,
                              ),
                              const SizedBox(height: 12),
                              _text(
                                'المكان المناسب لجميع احتياجاتكم العقارية',
                                tagline,
                                15,
                                FontWeight.w400,
                                const Color(0xD9FFFFFF),
                                5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      );

  Widget _text(
    String text,
    double opacity,
    double size,
    FontWeight weight,
    Color color,
    double shift,
  ) =>
      Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, shift * (1 - opacity)),
          child: Text(
            text,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'SplashTajawal',
              decoration: TextDecoration.none,
              fontSize: size,
              height: 1.45,
              fontWeight: weight,
              color: color,
            ),
          ),
        ),
      );
}

class LogoLight extends CustomPainter {
  LogoLight(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width * .5 + size.width * 2 * progress;
    final rect = Rect.fromLTWH(x - 28, 0, 56, size.height);
    canvas.save();
    canvas.skew(-.22, 0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x24FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoLight oldDelegate) => oldDelegate.progress != progress;
}

/// Architectural elevations in a 430 × 200 design space, revealed by path length.
class CityPainter extends CustomPainter {
  CityPainter({required this.progress, required this.light});
  final double progress;
  final double light;
  static final List<Path> paths = _architecture();
  static List<Path> _architecture() {
    final list = <Path>[];
    void line(List<double> points) {
      final p = Path()..moveTo(points[0], points[1]);
      for (var i = 2; i < points.length; i += 2) {
        p.lineTo(points[i], points[i + 1]);
      }
      list.add(p);
    }

    void rect(double x, double y, double w, double h) =>
        line([x, y, x + w, y, x + w, y + h, x, y + h, x, y]);
    line([0, 177, 430, 177]);
    // Left villa: stepped flat roofs, balcony and recessed glazing.
    line([-12, 177, -12, 112, 20, 112, 20, 87, 79, 87, 79, 177]);
    line([16, 87, 83, 87, 83, 94, 16, 94, 16, 87]);
    rect(29, 104, 39, 29);
    line([48, 104, 48, 133]);
    line([15, 145, 86, 145, 86, 151, 15, 151]);
    rect(24, 151, 20, 26);
    rect(53, 151, 18, 26);
    // Tall apartment block with parapet, setbacks and regular openings.
    line([92, 177, 92, 54, 143, 54, 143, 177]);
    line([87, 54, 148, 54, 148, 61, 87, 61, 87, 54]);
    for (var y = 72.0; y < 151; y += 23) {
      rect(102, y, 10, 14);
      rect(122, y, 10, 14);
    }
    // Low contemporary house with a restrained pitched roof.
    line([150, 177, 150, 135, 184, 111, 220, 135, 220, 177]);
    line([145, 137, 184, 109, 225, 137]);
    rect(162, 144, 20, 18);
    rect(194, 145, 14, 32);
    // Central setback residential building.
    line([
      228,
      177,
      228,
      78,
      236,
      78,
      236,
      67,
      276,
      67,
      276,
      78,
      284,
      78,
      284,
      177,
    ]);
    line([228, 85, 284, 85]);
    for (var y = 96.0; y < 160; y += 23) {
      rect(239, y, 12, 14);
      rect(261, y, 12, 14);
    }
    // Right villa: cantilevered canopy and tall living-room windows.
    line([295, 177, 295, 124, 323, 124, 323, 103, 385, 103, 385, 177]);
    line([317, 103, 391, 103, 391, 110, 317, 110, 317, 103]);
    rect(335, 121, 36, 23);
    line([353, 121, 353, 144]);
    line([289, 150, 390, 150, 390, 156, 289, 156]);
    rect(307, 156, 21, 21);
    rect(340, 156, 30, 21);
    line([355, 156, 355, 177]);
    line([398, 177, 398, 88, 438, 88]);
    for (var y = 102.0; y < 160; y += 22) {
      rect(408, y, 17, 13);
    }
    // Fine ground-plane lines anchor the elevation.
    line([0, 184, 430, 184]);
    line([35, 190, 112, 190]);
    line([307, 190, 402, 190]);
    return list;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 430, size.height / 200);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: .65);
    for (final path in paths) {
      final start = path.getBounds().left.clamp(0.0, 430.0) / 430 * .48;
      final local = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * local), paint);
      }
    }
    if (light > 0 && light < 1) {
      final x = light * 540 - 55;
      final rect = Rect.fromLTWH(x - 40, 0, 80, 200);
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, 430 * progress, 200));
      for (final path in paths) {
        canvas.drawPath(path, glow);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CityPainter oldDelegate) =>
      progress != oldDelegate.progress || light != oldDelegate.light;
}
