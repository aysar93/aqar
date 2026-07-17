import 'dart:math';
import 'package:flutter/material.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

class AqarRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const AqarRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      builder: (context, child, controller) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Transform.translate(
              offset: Offset(0, controller.value * 80),
              child: child,
            ),

            if (!controller.isIdle)
              Positioned(
                top: 20,
                child: Transform.rotate(
                  angle: controller.value * 2 * pi,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Image.asset(
                      "assets/images/refresh_icon.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }
}