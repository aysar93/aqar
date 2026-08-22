import 'package:flutter/widgets.dart';

import 'presence_service.dart';
import 'visit_tracking_service.dart';

class AppActivityService with WidgetsBindingObserver {
  AppActivityService._();

  static final instance = AppActivityService._();

  final visits = VisitTrackingService();
  final presence = PresenceService();

  bool _started = false;
  bool _isForeground = false;

  Future<void> initialize() async {
    if (_started) return;

    _started = true;
    WidgetsBinding.instance.addObserver(this);

    await _foreground();
  }

  Future<void> _foreground() async {
    if (_isForeground) return;

    _isForeground = true;

    final sessionId = await visits.startSession();
    await presence.connect(sessionId);
  }

  Future<void> _background() async {
    if (!_isForeground) return;

    _isForeground = false;

    await Future.wait([
      presence.disconnect(),
      visits.endSession(),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _background();
    }
  }
}
