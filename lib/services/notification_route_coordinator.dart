import 'dart:async';

import 'package:flutter/material.dart';

/// Waits for the actual app shell, rather than the splash Navigator alone.
class NotificationRouteCoordinator {
  NotificationRouteCoordinator(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;
  Route<dynamic>? _mainRoute;
  VoidCallback? _showHome;
  Future<void> Function(BuildContext)? _pending;

  void attach(Route<dynamic> route, VoidCallback showHome) {
    _mainRoute = route;
    _showHome = showHome;
    final pending = _pending;
    _pending = null;
    if (pending != null) unawaited(open(pending));
  }

  void detach(Route<dynamic> route) {
    if (!identical(route, _mainRoute)) return;
    _mainRoute = null;
    _showHome = null;
  }

  Future<void> open(Future<void> Function(BuildContext) navigate) async {
    final navigator = navigatorKey.currentState;
    final route = _mainRoute;
    if (navigator == null || route == null || !route.isActive) {
      // Keep the latest tap while startup/login is still in progress.
      _pending = navigate;
      return;
    }

    // Keep MainShell alive as the destination's back route.
    navigator.popUntil((candidate) => identical(candidate, route));
    _showHome?.call();
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) await navigate(context);
  }
}
