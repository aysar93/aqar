import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VisitTrackingService {
  VisitTrackingService(
      {FirebaseFirestore? firestore,
      Duration Function()? elapsed,
      String? platform})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _elapsed = elapsed ?? (Stopwatch()..start()).elapsedGetter,
        _platform = platform ?? Platform.operatingSystem;

  static const activityThrottle = Duration(minutes: 10);
  static const _writeTimeout = Duration(seconds: 8);
  final FirebaseFirestore _firestore;
  final Duration Function() _elapsed;
  final String _platform;
  final Map<String, Duration> _lastActivity = {};
  final Map<String, Future<void>> _activityWrites = {};
  DocumentReference<Map<String, dynamic>>? _session;
  Future<void>? _creation;
  Duration? _startedAt;
  String? _sessionUid;

  String get sessionId => _session?.id ?? '';

  Future<String> startSession(User user) async {
    if (user.isAnonymous) throw StateError('Guests are not tracked');
    if (_session != null && _sessionUid != user.uid) {
      throw StateError('End the previous session before switching UID');
    }
    if (_session == null) {
      final ref = _firestore.collection('app_sessions').doc();
      _session = ref;
      _sessionUid = user.uid;
      _startedAt = _elapsed();
      _creation = ref.set({
        'visitorId': user.uid,
        'userId': user.uid,
        'displayName': user.displayName,
        'isGuest': false,
        'platform': _platform,
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'durationSeconds': 0,
      }).catchError((Object error, StackTrace stack) {
        // A timeout is not a rejection: keep the same pending document ID.
        if (_session == ref) _clearSession();
        Error.throwWithStackTrace(error, stack);
      });
    }
    final id = _session!.id;
    await _creation!.timeout(_writeTimeout);
    return id;
  }

  Future<void> recordActivity(User user) async {
    if (user.isAnonymous) return;
    final pending = _activityWrites[user.uid];
    if (pending != null) {
      await pending.timeout(_writeTimeout);
      return;
    }
    final last = _lastActivity[user.uid];
    if (last != null && _elapsed() - last < activityThrottle) return;
    final write = _firestore.collection('user_activity').doc(user.uid).set({
      'userId': user.uid,
      'displayName': user.displayName,
      'isGuest': false,
      'platform': _platform,
      'lastSeen': FieldValue.serverTimestamp(),
      'lastSessionId': sessionId,
    }, SetOptions(merge: true));
    final tracked = write.then((_) {
      // Monotonic local time is only for throttling, never for lastSeen.
      _lastActivity[user.uid] = _elapsed();
    }).whenComplete(() {
      _activityWrites.remove(user.uid);
    });
    _activityWrites[user.uid] = tracked;
    await tracked.timeout(_writeTimeout);
  }

  Future<void> endSession() async {
    final ref = _session;
    if (ref == null) return;
    final creation = _creation!;
    final seconds = (_elapsed() - _startedAt!).inSeconds;
    // Detach before awaiting; foreground cannot reuse an ending session.
    _clearSession();
    await creation
        .then((_) => ref.update({
              'endedAt': FieldValue.serverTimestamp(),
              'durationSeconds': seconds < 0 ? 0 : seconds,
            }))
        .timeout(_writeTimeout);
  }

  void _clearSession() {
    _session = null;
    _creation = null;
    _sessionUid = null;
    _startedAt = null;
  }
}

extension on Stopwatch {
  Duration Function() get elapsedGetter => () => elapsed;
}
