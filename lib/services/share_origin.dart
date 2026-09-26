import 'package:flutter/material.dart';

/// iOS 26 and iPad require a non-empty rectangle inside the presenting view.
/// Use the visible part of the caller, with a screen-center fallback for drawers
/// or pages that have moved off screen during an animation.
Rect shareOrigin(BuildContext context) {
  final view = View.of(context);
  final viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.attached && renderObject.hasSize) {
    final bounds = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final visible = bounds.intersect(viewport);
    if (visible.isFinite && visible.width >= 1 && visible.height >= 1) {
      return Rect.fromCenter(center: visible.center, width: 1, height: 1);
    }
  }
  return Rect.fromCenter(center: viewport.center, width: 1, height: 1);
}
