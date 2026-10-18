import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'presence_service.dart';
import 'visit_tracking_service.dart';

/// One observer and one auth subscription; transitions are always serialized.
class AppActivityService with WidgetsBindingObserver {
  AppActivityService({
    FirebaseAuth? auth,
    VisitTrackingService? visits,
    PresenceService? presence,
  })  : _auth = auth ?? FirebaseAuth.instance,
        visits = visits ?? VisitTrackingService(),
        presence = presence ?? PresenceService();

  static final instance = AppActivityService();
  final FirebaseAuth _auth;
  final VisitTrackingService visits;
  final PresenceService presence;
  StreamSubscription<User?>? _authSubscription;
  Future<void> _transitions = Future.value();
  String? _trackingUid;
  bool _foreground = true;
  bool _signInPending = false;
  bool _signingOut = false;
  Future<void>? _signOutOperation;
  String? _activityIdentityUid;
  String? _meaningfulActivityUid;
  int _activityIdentityRevision = 0;

  void _observeActivityIdentity(String? uid) {
    if (_activityIdentityUid == uid) return;
    _activityIdentityUid = uid;
    _meaningfulActivityUid = null;
    _activityIdentityRevision++;
  }

  /// Run a meaningful operation; only its successful completion records activity.
  /// Capture the actor before awaiting so account switching cannot reattribute it.
  Future<T> recordSuccessfulAction<T>(Future<T> Function() action,
      {String? actorUid}) async {
    final capturedUid = actorUid ?? _auth.currentUser?.uid;
    final result = await action();
    unawaited(_recordMeaningfulActivity(capturedUid));
    return result;
  }

  Future<void> _recordMeaningfulActivity(String? actorUid) async {
    final user = _auth.currentUser;
    if (actorUid == null ||
        user == null ||
        user.isAnonymous ||
        user.uid != actorUid ||
        _signInPending ||
        _signingOut) {
      return;
    }
    _observeActivityIdentity(user.uid);
    final revision = _activityIdentityRevision;
    try {
      // One first-action merge per identity activation repairs missing documents
      // even when a lifecycle throttle entry exists. Subsequent actions throttle.
      await visits.recordActivity(user,
          ensureDocument: _meaningfulActivityUid != user.uid);
      if (revision == _activityIdentityRevision &&
          _auth.currentUser?.uid == user.uid) {
        _meaningfulActivityUid = user.uid;
      }
    } catch (error, stack) {
      _log('Meaningful activity', error, stack);
    }
  }

  Future<void> initialize() async {
    if (_authSubscription != null) return;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _auth.authStateChanges().listen(
      (_) {
        _observeActivityIdentity(_auth.currentUser?.uid);
        unawaited(_enqueue(_reconcile));
      },
      onError: (Object error, StackTrace stack) =>
          _log('Auth observer', error, stack),
    );
    await _enqueue(_reconcile);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _transitions.then((_) => action());
    // A failure must not poison the queue or block a later login.
    _transitions = next.catchError((Object error, StackTrace stack) {
      _log('Activity transition', error, stack);
    });
    return _transitions;
  }

  Future<void> _reconcile() async {
    final user = _auth.currentUser;
    _observeActivityIdentity(user?.uid);
    final desired = !_signInPending &&
            !_signingOut &&
            _foreground &&
            user != null &&
            !user.isAnonymous
        ? user
        : null;
    if (_trackingUid != desired?.uid) await _stopCurrent();
    if (desired == null) return;

    // Presence must not depend on a Firestore write acknowledgment.
    await presence.connect(desired.uid);
    _trackingUid = desired.uid;
    if (_auth.currentUser?.uid != desired.uid ||
        _signInPending ||
        _signingOut ||
        !_foreground) {
      return;
    }
    // Session ID is reserved synchronously; neither write blocks the other.
    await Future.wait([
      _safely('Session start', visits.startSession(desired)),
      _safely('Activity write', visits.recordActivity(desired)),
    ]);
  }

  Future<void> _safely<T>(String label, Future<T> operation) async {
    try {
      await operation;
    } catch (error, stack) {
      _log(label, error, stack);
    }
  }

  Future<void> _stopCurrent() async {
    _trackingUid = null;
    await Future.wait([
      presence.disconnect(),
      visits.endSession(),
    ].map((operation) => operation.catchError((Object error, StackTrace stack) {
          _log('Activity cleanup', error, stack);
        })));
  }

  /// Suspend tracking before native auth/consent/profile setup begins.
  Future<void> beginSignIn() async {
    _signInPending = true;
    await _enqueue(_stopCurrent);
  }

  Future<void> finishSignIn() async {
    _signInPending = false;
    await _enqueue(_reconcile);
  }

  /// Remove this connection while the previous auth token is still valid.
  Future<void> signOut() {
    return _signOutOperation ??= _performSignOut().whenComplete(() {
      _signOutOperation = null;
    });
  }

  Future<void> _performSignOut() async {
    _signingOut = true;
    try {
      await _enqueue(_stopCurrent);
      presence.invalidateDashboardAuthorization();
      await _auth.signOut();
    } finally {
      _signingOut = false;
      await _enqueue(_reconcile);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      // Preserve the boundary even if resumed arrives before the queue runs.
      unawaited(_enqueue(_stopCurrent));
      return;
    } else {
      return; // Native auth dialogs may temporarily make the app inactive.
    }
    unawaited(_enqueue(_reconcile));
  }

  Future<void> dispose() async {
    _foreground = false;
    WidgetsBinding.instance.removeObserver(this);
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _enqueue(_stopCurrent);
  }

  static void _log(String label, Object error, StackTrace stack) {
    debugPrint('$label failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}
