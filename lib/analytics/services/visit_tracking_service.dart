import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'analytics_identity.dart';

class VisitTrackingService {
  VisitTrackingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  DocumentReference<Map<String, dynamic>>? _session;
  DateTime? _startedAt;

  String get sessionId => _session?.id ?? '';

  Future<String> startSession() async {
    if (_session != null) return _session!.id;
    final visitorId = await AnalyticsIdentity.id();
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;
    _startedAt = DateTime.now();
    _session = _firestore.collection('app_sessions').doc();
    await _session!.set({
      'visitorId': visitorId,
      'userId': isGuest ? null : user.uid,
      'displayName': isGuest ? null : user.displayName,
      'isGuest': isGuest,
      'platform': Platform.operatingSystem,
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'durationSeconds': 0,
    });
    await _firestore.collection('user_activity').doc(visitorId).set({
      'userId': isGuest ? null : user.uid,
      'displayName': isGuest ? null : user.displayName,
      'isGuest': isGuest,
      'platform': Platform.operatingSystem,
      'lastSeen': FieldValue.serverTimestamp(),
      'lastSessionId': _session!.id,
    }, SetOptions(merge: true));
    return _session!.id;
  }

  Future<void> heartbeat() async {
    final visitorId = await AnalyticsIdentity.id();
    await _firestore.collection('user_activity').doc(visitorId).set({
      'lastSeen': FieldValue.serverTimestamp(),
      'platform': Platform.operatingSystem,
    }, SetOptions(merge: true));
  }

  Future<void> endSession() async {
    final ref = _session;
    if (ref == null) return;
    final seconds = DateTime.now().difference(_startedAt!).inSeconds;
    await ref.update({
      'endedAt': FieldValue.serverTimestamp(),
      'durationSeconds': seconds,
    });
    await heartbeat();
    _session = null;
    _startedAt = null;
  }
}
