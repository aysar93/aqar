import 'dart:async';

import 'package:aqar/analytics/services/presence_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'activity_tracking_test.dart' show drain;

class PresenceDatabase implements FirebaseDatabase {
  final events = <String>[];
  final nodes = <String, Object?>{};
  final streams = <String, StreamController<DatabaseEvent>>{};
  final listeners = <String, int>{};
  int nextId = 0;
  bool rejectNext = false;
  Completer<void>? pendingSet;
  Stream<DatabaseEvent> stream(String path) =>
      (streams[path] ??= StreamController<DatabaseEvent>.broadcast(
        onListen: () => listeners[path] = (listeners[path] ?? 0) + 1,
        onCancel: () => listeners[path] = (listeners[path] ?? 0) - 1,
      ))
          .stream;
  void connected(bool connected) =>
      streams['.info/connected']!.add(PresenceEvent(connected));
  @override
  DatabaseReference ref([String? path]) => PresenceReference(this, path ?? '');
  @override
  Future<void> goOnline() async => events.add('goOnline');
  @override
  Future<void> goOffline() async => events.add('goOffline');
  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PresenceReference implements DatabaseReference {
  PresenceReference(this.database, this.path);
  final PresenceDatabase database;
  @override
  final String path;
  @override
  String get key => path.split('/').last;
  @override
  DatabaseReference push() =>
      PresenceReference(database, '$path/c${++database.nextId}');
  @override
  Stream<DatabaseEvent> get onValue => database.stream(path);
  @override
  Query orderByChild(String path) => this;
  @override
  Query startAt(Object? value, {String? key}) => this;
  @override
  OnDisconnect onDisconnect() => PresenceDisconnect(database, path);
  @override
  Future<void> set(Object? value) async {
    database.events.add('set:$path');
    if (database.rejectNext) {
      database.rejectNext = false;
      throw StateError('denied');
    }
    await database.pendingSet?.future;
    database.nodes[path] = value;
  }

  @override
  Future<void> update(Map<String, Object?> value) async {
    database.events.add('update:$path');
    for (final key in value.keys) {
      database.nodes.remove('$path/$key');
    }
  }

  @override
  Future<void> remove() async {
    database.events.add('remove:$path');
    database.nodes.remove(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PresenceDisconnect implements OnDisconnect {
  PresenceDisconnect(this.database, this.path);
  final PresenceDatabase database;
  final String path;
  @override
  Future<void> remove() async => database.events.add('onDisconnect:$path');
  @override
  Future<void> cancel() async => database.events.add('cancel:$path');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PresenceEvent implements DatabaseEvent {
  PresenceEvent(Object? value) : snapshot = PresenceSnapshot(value);
  @override
  final DataSnapshot snapshot;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PresenceSnapshot implements DataSnapshot {
  PresenceSnapshot(this.value);
  @override
  final Object? value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GrantedFunctions implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      GrantedCallable();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GrantedCallable implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async =>
      GrantedResult<T>();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GrantedResult<T> implements HttpsCallableResult<T> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
      'dashboard disconnect is an error, with one shared info subscription and one data listener',
      () async {
    final database = PresenceDatabase();
    final service =
        PresenceService(database: database, functions: GrantedFunctions());
    await service.connect('A');
    database.connected(true);
    await drain();
    final values = <int>[];
    final errors = <Object>[];
    final counter =
        service.onlineCount().listen(values.add, onError: errors.add);
    await drain();
    database.streams['presence']!.add(PresenceEvent({
      'A': {
        'connections': {'one': 123, 'two': 456}
      },
    }));
    await drain();
    expect(values.last, 1);
    expect(database.listeners['.info/connected'], 1);
    expect(database.listeners['presence'], 1);
    database.connected(false);
    await drain();
    expect(errors, isNotEmpty);
    expect(values, isNot(contains(0)));
    database.connected(true);
    await drain();
    expect(values.last, 1);
    await counter.cancel();
    expect(database.listeners['presence'], 0);
    expect(
        database.listeners['.info/connected'], 1); // Publishing still owns it.
    await service.disconnect();
    await drain();
    expect(database.listeners.values.every((count) => count == 0), isTrue);
    await database.close();
  });

  test(
      'registration precedes publication; reconnect and cleanup own only one connection',
      () async {
    final database = PresenceDatabase();
    final service = PresenceService(database: database);
    await service.connect('A');
    database.connected(true);
    await drain();
    expect(database.events.indexOf('onDisconnect:presence/A/connections/c1'),
        lessThan(database.events.indexOf('set:presence/A/connections/c1')));
    await service.connect('A');
    await drain();
    expect(database.nextId, 1);
    expect(database.listeners.values.reduce((a, b) => a + b), 2);
    expect(database.events.where((e) => e.startsWith('set:')).length, 1);
    database.connected(false);
    database.connected(true);
    await drain();
    expect(database.events.where((e) => e.startsWith('set:')).length, 2);
    await PresenceReference(database, 'presence/A/connections/c1').remove();
    expect(database.nodes.keys, contains('presence/A/connections/c2'));
    await service.disconnect();
    expect(database.nodes, isEmpty);
    expect(database.listeners.values.every((count) => count == 0), isTrue);
    expect(database.events, contains('cancel:presence/A/connections/c1'));
    await service.connect('B');
    database.connected(true);
    await drain();
    expect(database.nodes.keys.single, 'presence/B/connections/c3');
    await service.disconnect();
    await database.close();
  });

  test('a late acknowledged write cannot resurrect the disconnected UID',
      () async {
    final database = PresenceDatabase()..pendingSet = Completer<void>();
    final service = PresenceService(database: database);
    await service.connect('A');
    database.connected(true);
    await drain();
    final disconnect = service.disconnect();
    database.pendingSet!.complete();
    await disconnect;
    expect(database.nodes, isEmpty);
    expect(database.events.where((e) => e.contains('online:false')), isEmpty);
    await database.close();
  });

  test('a rejected publication can retry without accumulating listeners',
      () async {
    final database = PresenceDatabase()..rejectNext = true;
    final service = PresenceService(database: database);
    await service.connect('A');
    database.connected(true);
    await drain();
    expect(database.nodes, isEmpty);
    await service.connect('A');
    await drain();
    expect(database.nodes.length, 1);
    expect(database.nextId, 1);
    expect(database.listeners.values.reduce((a, b) => a + b), 2);
    await service.disconnect();
    await database.close();
  });
}
