import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aqar_refresh_header.dart';

class AqarRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const AqarRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<AqarRefreshIndicator> createState() => _AqarRefreshIndicatorState();
}

class _AqarRefreshIndicatorState extends State<AqarRefreshIndicator>
    with SingleTickerProviderStateMixin {
  // مقدار السحب المطلوب لتفعيل التحديث.
  static const double _triggerDistance = 58.0;

  // مكان الزر أثناء السحب.
  // لا يرتبط بمقدار استمرار المستخدم في السحب.
  static const double _indicatorTop = 4.0;

  double _pullDistance = 0.0;
  double _progress = 0.0;

  bool _dragging = false;
  bool _refreshing = false;
  bool _success = false;

  late final AnimationController _returnController;
  late Animation<double> _returnAnimation;

  @override
  void initState() {
    super.initState();

    _returnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _returnAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _returnController,
        curve: Curves.easeOutCubic,
      ),
    );

    _returnController.addListener(() {
      if (!mounted) return;

      setState(() {
        _pullDistance = _returnAnimation.value;

        _progress = (_pullDistance / _triggerDistance).clamp(0.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _returnController.dispose();
    super.dispose();
  }

  void _setPullDistance(double distance) {
    if (!mounted || _refreshing || _success) return;

    final newDistance = distance.clamp(0.0, _triggerDistance);

    final newProgress = (newDistance / _triggerDistance).clamp(0.0, 1.0);

    if ((newDistance - _pullDistance).abs() < 0.1 &&
        (newProgress - _progress).abs() < 0.001) {
      return;
    }

    setState(() {
      _pullDistance = newDistance;
      _progress = newProgress;
    });
  }

  Future<void> _animateBack() async {
    if (!mounted) return;

    if (_returnController.isAnimating) {
      _returnController.stop();
    }

    _returnAnimation = Tween<double>(
      begin: _pullDistance,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _returnController,
        curve: Curves.easeOutCubic,
      ),
    );

    _returnController.reset();
    await _returnController.forward();

    if (!mounted) return;

    setState(() {
      _pullDistance = 0.0;
      _progress = 0.0;
    });
  }

  Future<void> _startRefresh() async {
    if (_refreshing) return;

    if (_returnController.isAnimating) {
      _returnController.stop();
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _dragging = false;
      _refreshing = true;
      _success = false;
      _pullDistance = _triggerDistance;
      _progress = 1.0;
    });

    try {
      await widget.onRefresh();

      if (!mounted) return;

      setState(() {
        _refreshing = false;
        _success = true;
      });

      await Future.delayed(
        const Duration(milliseconds: 550),
      );

      if (!mounted) return;

      setState(() {
        _success = false;
      });

      await _animateBack();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _refreshing = false;
        _success = false;
      });

      await _animateBack();
    }
  }

  bool _handleScrollNotification(
    ScrollNotification notification,
  ) {
    if (_refreshing || _success) {
      return false;
    }

    // نتعامل فقط مع ScrollView الرئيسي.
    if (notification.depth != 0) {
      return false;
    }

    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    // بداية السحب.
    if (notification is ScrollStartNotification) {
      final atTop = notification.metrics.extentBefore <= 0.0;

      _dragging = atTop;

      if (_dragging) {
        if (_returnController.isAnimating) {
          _returnController.stop();
        }

        if (_pullDistance > 0.0) {
          setState(() {
            _pullDistance = 0.0;
            _progress = 0.0;
          });
        }
      }

      return false;
    }

    // ==========================================
    // الحالة الأولى:
    // BouncingScrollPhysics
    //
    // pixels تصبح سالبة أثناء السحب من الأعلى.
    // الصفحة الرئيسية تعمل غالباً بهذه الطريقة.
    // ==========================================
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final atTop = notification.metrics.extentBefore <= 0.0;

      if (atTop) {
        _dragging = true;
      }

      if (_dragging && notification.metrics.pixels < 0.0) {
        final distance = -notification.metrics.pixels;

        _setPullDistance(distance);
      }

      return false;
    }

    // ==========================================
    // الحالة الثانية:
    // ScrollPhysics التي ترسل OverscrollNotification.
    //
    // نستخدم delta الفعلية للسحب، لكن نوقف
    // الحساب عند triggerDistance.
    // ==========================================
    if (notification is OverscrollNotification &&
        notification.overscroll < 0.0) {
      final atTop = notification.metrics.extentBefore <= 0.0;

      if (atTop) {
        _dragging = true;
      }

      if (_dragging) {
        final delta = -notification.overscroll;

        _setPullDistance(
          _pullDistance + delta,
        );
      }

      return false;
    }

    // عند رفع الإصبع.
    if (notification is ScrollEndNotification) {
      if (!_dragging) {
        return false;
      }

      _dragging = false;

      if (_progress >= 1.0) {
        _startRefresh();
      } else {
        _animateBack();
      }

      return false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _pullDistance > 0.0 || _refreshing || _success;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          widget.child,

          // زر التحديث ثابت في نفس المكان.
          // استمرار المستخدم في سحب الصفحة لا ينزله أكثر.
          Positioned(
            top: _indicatorTop,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(
                        milliseconds: 120,
                      ),
                opacity: visible ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AqarRefreshHeader(
                    progress: _progress,
                    refreshing: _refreshing,
                    success: _success,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
