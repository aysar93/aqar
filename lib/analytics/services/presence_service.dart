import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class PresenceService {
  PresenceService({FirebaseDatabase? database, FirebaseFunctions? functions})
      : _database = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL:
                  'https://aqar-9f3f9-default-rtdb.asia-southeast1.firebasedatabase.app',
            ),
        _functions = functions;

  final FirebaseDatabase _database;
  final FirebaseFunctions? _functions;
  DatabaseReference? _connection;
  final _ownedConnections = <DatabaseReference>[];
  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  StreamSubscription<DatabaseEvent>? _ownConnectionSubscription;
  Future<void> _publication = Future.value();
  String? _uid;
  int _generation = 0;
  bool _connected = false;
  bool _published = false;
  bool _publishing = false;
  StreamSubscription<DatabaseEvent>? _transportSubscription;
  bool? _transportConnected;
  // Share one local .info observer between publishing and the dashboard.
  // Cancel the SDK subscription when the last consumer leaves.
  late final StreamController<DatabaseEvent> _transport =
      StreamController<DatabaseEvent>.broadcast(
    onListen: () {
      _transportSubscription = _database.ref('.info/connected').onValue.listen(
        (event) {
          _transportConnected = event.snapshot.value == true;
          _transport.add(event);
        },
        onError: (Object error, StackTrace stack) =>
            _transport.addError(error, stack),
      );
    },
    onCancel: () {
      final subscription = _transportSubscription;
      _transportSubscription = null;
      _transportConnected = null;
      unawaited(subscription?.cancel() ?? Future<void>.value());
    },
  );

  Future<void> connect(String uid) async {
    if (_uid == uid && _connectedSubscription != null) {
      if (_connection != null) _publish(_connection!, _generation);
      return;
    }
    await disconnect();
    await _database.goOnline();
    _uid = uid;
    final generation = ++_generation;
    _connectedSubscription = _transport.stream.listen((event) {
      final wasConnected = _connected;
      _connected = event.snapshot.value == true;
      if (!_connected) {
        _published = false;
        return;
      }
      if (!wasConnected) _beginConnection(uid, generation);
    }, onError: (Object error, StackTrace stack) => _log(error, stack));
    // A dashboard subscriber may already have received the initial event.
    _connected = _transportConnected == true;
    if (_connected) _beginConnection(uid, generation);
  }

  void _beginConnection(String uid, int generation) {
    if (generation != _generation) return;
    // Rotate on every physical reconnect: delayed cleanup from an old socket
    // must never remove its replacement's connection.
    final ref = _database.ref('presence/$uid/connections').push();
    _connection = ref;
    _ownedConnections.add(ref);
    _published = false;
    _publishing = false;
    unawaited(_ownConnectionSubscription?.cancel() ?? Future<void>.value());
    _ownConnectionSubscription = ref.onValue.listen(
      (_) {},
      onError: (Object error, StackTrace stack) => _log(error, stack),
    );
    _publish(ref, generation);
  }

  void _publish(DatabaseReference ref, int generation) {
    if (!_connected ||
        _published ||
        _publishing ||
        generation != _generation ||
        ref != _connection) {
      return;
    }
    _publishing = true;
    _publication = _publication
        .then<void>((_) async {
          if (generation != _generation || ref != _connection) return;
          await ref.onDisconnect().remove();
          if (generation != _generation || ref != _connection) return;
          await ref.set(ServerValue.timestamp);
          if (generation != _generation || ref != _connection) {
            await ref.remove();
          } else {
            _published = true;
          }
        })
        .catchError((Object error, StackTrace stack) => _log(error, stack))
        .whenComplete(() {
          if (generation == _generation && ref == _connection) {
            _publishing = false;
          }
        });
  }

  Future<void> disconnect() async {
    ++_generation;
    _connected = false;
    _published = false;
    _publishing = false;
    final uid = _uid;
    final owned = List<DatabaseReference>.of(_ownedConnections);
    _ownedConnections.clear();
    _connection = null;
    _uid = null;
    await _connectedSubscription?.cancel();
    _connectedSubscription = null;
    await _ownConnectionSubscription?.cancel();
    _ownConnectionSubscription = null;
    if (uid == null || owned.isEmpty) return;
    try {
      // Let any pending registration finish before removing/cancelling it.
      await _publication.timeout(const Duration(seconds: 5));
      await _database.ref('presence/$uid/connections').update({
        for (final ref in owned) ref.key!: null,
      }).timeout(const Duration(seconds: 5));
      await Future.wait(owned.map((ref) => ref.onDisconnect().cancel()))
          .timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      _log(error, stack);
      // When offline, writes cannot be acknowledged. Close the transport while
      // still authenticated; keep the registered server cleanup as fallback.
      await _database.goOffline();
    } finally {
      _publication = Future.value();
    }
  }

  Future<DateTime> serverNow() async {
    final snapshot = await _database
        .ref('.info/serverTimeOffset')
        .get()
        .timeout(const Duration(seconds: 8));
    final offset = snapshot.value;
    if (offset is! num) throw StateError('Server time is unavailable');
    return DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch + offset.toInt(),
    );
  }

  Stream<int> onlineCount() async* {
    try {
      // Server checks users/UID.isAdmin; clients cannot grant themselves ACLs.
      await (_functions ?? FirebaseFunctions.instance)
          .httpsCallable('authorizePresenceDashboard')
          .call();
      final counter = StreamController<int>();
      int? latest;
      void reportError(Object error, StackTrace stack) {
        _log(error, stack);
        counter.addError(error, stack);
      }

      final transport = _transport.stream.listen((event) {
        if (event.snapshot.value == true) {
          if (latest != null) counter.add(latest!);
        } else if (latest != null) {
          reportError(StateError('Live presence connection is unavailable'),
              StackTrace.current);
        }
      }, onError: reportError);
      // Objects sort after booleans; missing connections = null. Legacy/offline
      // UID nodes are excluded on the server, not downloaded and filtered.
      final data = _database
          .ref('presence')
          .orderByChild('connections')
          .startAt(true)
          .onValue
          .listen((event) {
        latest = countOnlineUids(event.snapshot.value);
        if (_transportConnected == true) {
          counter.add(latest!);
        } else {
          reportError(StateError('Live presence connection is unavailable'),
              StackTrace.current);
        }
      }, onError: reportError);
      try {
        yield* counter.stream;
      } finally {
        await Future.wait([data.cancel(), transport.cancel()]);
        await counter.close();
      }
    } catch (error, stack) {
      _log(error, stack);
      Error.throwWithStackTrace(error, stack);
    }
  }

  @visibleForTesting
  static int countOnlineUids(Object? value) {
    if (value is! Map) return 0;
    return value.values.where((node) {
      if (node is! Map) return false;
      final connections = node['connections'];
      return connections is Map &&
          connections.values.any((connection) => connection is num);
    }).length;
  }

  static void _log(Object error, StackTrace stack) {
    debugPrint('Presence failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}
