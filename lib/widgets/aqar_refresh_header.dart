import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gold_ring_painter.dart';
import 'package:flutter/services.dart';

class AqarRefreshHeader extends StatefulWidget {
  final double progress;
  final bool refreshing;
  final bool success;

  const AqarRefreshHeader({
    super.key,
    required this.progress,
    required this.refreshing,
    required this.success,
  });

  @override
  State<AqarRefreshHeader> createState() => _AqarRefreshHeaderState();
}

class _AqarRefreshHeaderState extends State<AqarRefreshHeader>
    with TickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  late final AnimationController _rotationController;
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _bounceAnimation = Tween<double>(
      begin: 1,
      end: 1.10,
    ).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0, end: -2),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -2, end: 2),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 2, end: -1.5),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -1.5, end: 1),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1, end: 0),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AqarRefreshHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.success && widget.success) {
      _bounceController.forward(from: 0);
      _shakeController.forward(from: 0);

      HapticFeedback.mediumImpact();
    }

    if (widget.refreshing) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();

    _bounceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0);

    return IgnorePointer(
      child: SizedBox(
        height: 52,
        child: Center(
          child: AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              final angle = widget.refreshing
                  ? _rotationController.value * 2 * math.pi
                  : Curves.easeOut.transform(progress) * 1.6 * math.pi;

              final logoScale =
                  widget.refreshing ? 1.0 : (0.75 + (progress * 0.25));

              return Transform.scale(
                scale: widget.refreshing ? 1.02 : (0.94 + (progress * 0.06)),
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: widget.success ? _bounceAnimation.value : 1.0,
                      child: child,
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 250),
                      scale: widget.success ? 1.08 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF162033),
                          border: Border.all(
                            color: widget.success
                                ? const Color(0xFFFFF176)
                                : const Color(0xFFD4AF37),
                            width: widget.success ? 2.0 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(
                                alpha: widget.refreshing ? .20 : .10,
                              ),
                              blurRadius: widget.refreshing ? 12 : 7,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CustomPaint(
                                painter: GoldRingPainter(
                                  progress: progress,
                                  refreshing: widget.refreshing,
                                  rotation: angle,
                                ),
                              ),
                            ),
                            Container(
                              width: 25,
                              height: 25,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFF4C2),
                                    Color(0xFFD4AF37),
                                    Color(0xFF8C6A00),
                                  ],
                                ),
                              ),
                              child: Transform.scale(
                                scale: logoScale,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  switchInCurve: Curves.easeOutBack,
                                  switchOutCurve: Curves.easeIn,
                                  child: widget.success
                                      ? const Icon(
                                          Icons.check_rounded,
                                          key: ValueKey("done"),
                                          color: Color(0xFF0F172A),
                                          size: 17,
                                        )
                                      : Padding(
                                          key: const ValueKey("logo"),
                                          padding: const EdgeInsets.all(4),
                                          child: ClipOval(
                                            child: Image.asset(
                                              'assets/images/refresh_icon.png',
                                              fit: BoxFit.cover,
                                              filterQuality: FilterQuality.high,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
