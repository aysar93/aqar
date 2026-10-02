// Firebase SDK doubles; actual security is verified on local emulators.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:aqar/analytics/services/app_activity_service.dart';
import 'package:aqar/analytics/services/presence_service.dart';
import 'package:aqar/analytics/services/visit_tracking_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUser implements User {
  TestUser(this.uid, {this.isAnonymous = false, this.provider = 'password'});
  @override
  final String uid;
  @override
  final bool isAnonymous;
  final String provider;
  @override
  String get displayName => uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuth implements FirebaseAuth {
  TestAuth(this.currentUser);
  @override
  User? currentUser;
  final changes = StreamController<User?>.broadcast();
  int logouts = 0;
  int observers = 0;
  void emit(User? user) {
    currentUser = user;
    changes.add(user);
  }

  @override
  Stream<User?> authStateChanges() {
    observers++;
    return changes.stream;
  }

  @override
  Future<void> signOut() async {
    logouts++;
    emit(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestVisits implements VisitTrackingService {
  TestVisits(this.events);
  final List<String> events;
  String? uid;
  Completer<void>? ending;
  bool failStart = false;
  @override
  String get sessionId => uid ?? '';
  @override
  Future<String> startSession(User user) async {
    if (failStart) {
      failStart = false;
      throw StateError('write rejected');
    }
    if (uid != null) {
      expect(uid, user.uid);
      return uid!;
    }
    uid = user.uid;
    events.add('start:$uid');
    return uid!;
  }

  @override
  Future<void> recordActivity(User user) async =>
      events.add('activity:${user.uid}');
  @override
  Future<void> endSession() async {
    if (uid == null) return;
    events.add('end:$uid');
    uid = null;
    await ending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestPresence implements PresenceService {
  TestPresence(this.events, this.auth);
  final List<String> events;
  final TestAuth auth;
  String? uid;
  @override
  Future<void> connect(String userId) async {
    if (uid == userId) return;
    expect(uid, isNull);
    uid = userId;
    events.add('online:$uid');
  }

  @override
  Future<void> disconnect() async {
    if (uid == null) return;
    events.add('offline:$uid:auth=${auth.currentUser?.uid}');
    uid = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class WriteStore implements FirebaseFirestore {
  final writes = <String, List<Map<String, dynamic>>>{};
  int reads = 0;
  bool rejectNext = false;
  Completer<void>? pending;
  int nextId = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      WriteCollection(this, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class WriteCollection implements CollectionReference<Map<String, dynamic>> {
  WriteCollection(this.store, this.path);
  final WriteStore store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      WriteDocument(store, '$path/${id ?? ++store.nextId}');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class WriteDocument implements DocumentReference<Map<String, dynamic>> {
  WriteDocument(this.store, this.path);
  final WriteStore store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.writes.putIfAbsent(path, () => []).add(data);
    if (store.rejectNext) {
      store.rejectNext = false;
      throw StateError('rejected');
    }
    await store.pending?.future;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.writes
        .putIfAbsent(path, () => [])
        .add(Map<String, dynamic>.from(data));
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    store.reads++;
    throw StateError('Activity must never read');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> drain() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auth changes, logout and account switching clean the previous UID',
      () async {
    final events = <String>[];
    final auth = TestAuth(TestUser('A'));
    final visits = TestVisits(events);
    final presence = TestPresence(events, auth);
    final service =
        AppActivityService(auth: auth, visits: visits, presence: presence);
    await service.initialize();
    await service.initialize();
    expect(auth.observers, 1);
    expect(events.where((e) => e == 'start:A').length, 1);
    await Future.wait([service.signOut(), service.signOut()]);
    expect(auth.logouts, 1);
    expect(events, contains('offline:A:auth=A'));
    await service.beginSignIn();
    auth.emit(TestUser('B', provider: 'google.com'));
    await drain();
    expect(presence.uid, isNull);
    await service.finishSignIn();
    expect(presence.uid, 'B');
    auth.emit(TestUser('C', provider: 'apple.com'));
    await drain();
    expect(presence.uid, 'C');
    expect(events.indexOf('end:B'), lessThan(events.indexOf('start:C')));
    await service.dispose();
    await auth.changes.close();
  });

  test('foreground waits for background cleanup; no duplicate sessions',
      () async {
    final events = <String>[];
    final auth = TestAuth(TestUser('A'));
    final visits = TestVisits(events);
    final service = AppActivityService(
        auth: auth, visits: visits, presence: TestPresence(events, auth));
    await service.initialize();
    visits.ending = Completer<void>();
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await drain();
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await drain();
    expect(events.where((e) => e == 'start:A').length, 1);
    visits.ending!.complete();
    await drain();
    expect(events.where((e) => e == 'start:A').length, 2);
    await service.dispose();
    await auth.changes.close();
  });

  test('a rejected start does not prevent retry on the next natural event',
      () async {
    final events = <String>[];
    final auth = TestAuth(TestUser('A'));
    final visits = TestVisits(events)..failStart = true;
    final service = AppActivityService(
        auth: auth, visits: visits, presence: TestPresence(events, auth));
    await service.initialize();
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await drain();
    expect(visits.uid, 'A');
    await service.dispose();
    await auth.changes.close();
  });

  test('a rapid pause/resume preserves cleanup even before the queue starts',
      () async {
    final events = <String>[];
    final auth = TestAuth(TestUser('A'));
    final visits = TestVisits(events);
    final service = AppActivityService(
        auth: auth, visits: visits, presence: TestPresence(events, auth));
    await service.initialize();
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await drain();
    expect(events.where((event) => event == 'start:A').length, 2);
    expect(events, contains('end:A'));
    await service.dispose();
    expect(auth.changes.hasListener, isFalse);
    await auth.changes.close();
  });

  for (final platform in ['android', 'ios']) {
    for (final provider in [
      'phone',
      'password',
      'google.com',
      'apple.com',
      'facebook.com'
    ]) {
      test(
          '$platform + $provider uses UID, server timestamp and local throttle without reads',
          () async {
        final store = WriteStore();
        var elapsed = Duration.zero;
        final visits = VisitTrackingService(
            firestore: store, elapsed: () => elapsed, platform: platform);
        final user = TestUser('uid', provider: provider);
        await visits.startSession(user);
        await visits.recordActivity(user);
        elapsed = const Duration(minutes: 9);
        await visits.recordActivity(user);
        expect(store.writes['user_activity/uid']!.length, 1);
        elapsed = const Duration(minutes: 10);
        await visits.recordActivity(user);
        expect(store.writes['user_activity/uid']!.length, 2);
        expect(store.writes['user_activity/uid']!.last['lastSeen'],
            isA<FieldValue>());
        expect(store.writes['user_activity/uid']!.last['platform'], platform);
        expect(store.writes.values.first.first['platform'], platform);
        await visits.endSession();
        expect(store.writes['user_activity/uid']!.length,
            2); // No background heartbeat.
        expect(store.reads, 0);
        // Advancing time without a lifecycle event performs no write.
        elapsed = const Duration(hours: 1);
        expect(store.writes['user_activity/uid']!.length, 2);
      });
    }
  }

  test('concurrent activity requests share a write; failure is retryable',
      () async {
    final store = WriteStore()..pending = Completer<void>();
    final visits =
        VisitTrackingService(firestore: store, elapsed: () => Duration.zero);
    final first = visits.recordActivity(TestUser('A'));
    final second = visits.recordActivity(TestUser('A'));
    expect(store.writes['user_activity/A']!.length, 1);
    store.pending!.complete();
    await Future.wait([first, second]);
    store.pending = null;
    store.rejectNext = true;
    await expectLater(visits.recordActivity(TestUser('B')), throwsStateError);
    await visits.recordActivity(TestUser('B'));
    expect(store.writes['user_activity/B']!.length, 2);
  });

  test(
      'session failure clears state and a new session never reuses an ended ID',
      () async {
    final store = WriteStore()..rejectNext = true;
    final visits =
        VisitTrackingService(firestore: store, elapsed: () => Duration.zero);
    await expectLater(visits.startSession(TestUser('A')), throwsStateError);
    expect(visits.sessionId, isEmpty);
    final first = await visits.startSession(TestUser('A'));
    final end = visits.endSession();
    expect(visits.sessionId, isEmpty);
    final second = await visits.startSession(TestUser('A'));
    await end;
    expect(second, isNot(first));
  });

  test(
      'online counts unique UIDs, ignores legacy flags and survives one device leaving',
      () {
    final data = <String, dynamic>{
      'A': {
        'connections': {'android': 123, 'ios': 456}
      },
      'B': {
        'connections': {'device': 789}
      },
      'legacy': {'online': true},
    };
    expect(PresenceService.countOnlineUids(data), 2);
    (data['A']['connections'] as Map).remove('android');
    expect(PresenceService.countOnlineUids(data), 2);
    (data['A']['connections'] as Map).clear();
    expect(PresenceService.countOnlineUids(data), 1);
  });
}
