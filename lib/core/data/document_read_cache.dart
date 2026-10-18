import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Small TTL cache with in-flight deduplication. No timers, persistent storage
/// or additional reads. The actor namespace is reset before each read.
class AsyncReadCache<T> {
  AsyncReadCache(
      {this.ttl = const Duration(seconds: 30),
      this.maximum = 100,
      DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final Duration ttl;
  final int maximum;
  final DateTime Function() _now;
  final Map<String, ({DateTime time, T value})> _values = {};
  final Map<String, Future<T>> _inflight = {};
  int _generation = 0;
  Future<T> read(String key, Future<T> Function() loader) {
    final value = _values[key];
    if (value != null && _now().difference(value.time) < ttl) {
      _values.remove(key);
      _values[key] = value;
      return Future.value(value.value);
    }
    final pending = _inflight[key];
    if (pending != null) return pending;
    final generation = _generation;
    late final Future<T> future;
    future = Future.sync(loader).then((result) {
      if (generation == _generation) {
        _values.remove(key);
        _values[key] = (time: _now(), value: result);
        while (_values.length > maximum) {
          _values.remove(_values.keys.first);
        }
      }
      return result;
    }).whenComplete(() {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    });
    _inflight[key] = future;
    return future;
  }

  void clear() {
    _generation++;
    _values.clear();
    _inflight.clear();
  }
}

class DocumentReadCache {
  DocumentReadCache._();
  static final instance = DocumentReadCache._();
  final _cache = AsyncReadCache<DocumentSnapshot<Map<String, dynamic>>>();
  String? _actor;
  Future<DocumentSnapshot<Map<String, dynamic>>> get(String path) async {
    final actor = FirebaseAuth.instance.currentUser?.uid;
    if (actor != _actor) {
      _actor = actor;
      _cache.clear();
    }
    final result = await _cache.read(
        path, () => FirebaseFirestore.instance.doc(path).get());
    if (FirebaseAuth.instance.currentUser?.uid != actor) {
      throw StateError('Account changed during document read');
    }
    return result;
  }
}
