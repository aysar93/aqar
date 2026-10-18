import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../analytics/services/app_activity_service.dart';

class FavoritesService {
  FavoritesService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FavoriteRegistry registry =
      FavoriteRegistry(_db, FirebaseAuth.instance);
  static final Map<String, Future<void>> _toggles = {};

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Stream<bool> favoriteStream(String propertyId) =>
      registry.watch(propertyId);

  static Future<bool> isFavorite(String propertyId) async {
    if (_uid == null) return false;
    final known = registry.known(propertyId);
    if (known != null) return known;
    final doc = await _db
        .collection("users")
        .doc(_uid)
        .collection("favorites")
        .doc(propertyId)
        .get();

    return doc.exists;
  }

  static Future<void> toggleFavorite(String propertyId) async {
    final uid = _uid;
    if (uid == null) return;
    final key = '$uid/$propertyId';
    final previous = _toggles[key] ?? Future<void>.value();
    late final Future<void> next;
    next = previous
        .catchError((Object _) {})
        .then((_) => _toggle(propertyId, uid))
        .whenComplete(() {
      if (identical(_toggles[key], next)) _toggles.remove(key);
    });
    _toggles[key] = next;
    await next;
  }

  static Future<void> _toggle(String propertyId, String uid) async {
    if (_uid != uid) throw StateError('Account changed during favorite toggle');

    await AppActivityService.instance.recordSuccessfulAction(() async {
      final ref = _db
          .collection("users")
          .doc(uid)
          .collection("favorites")
          .doc(propertyId);

      final doc = await ref.get();
      if (_uid != uid) {
        throw StateError('Account changed during favorite toggle');
      }

      registry.optimistic(propertyId, !doc.exists, uid);
      try {
        if (doc.exists) {
          await ref.delete();
        } else {
          await ref.set({"createdAt": FieldValue.serverTimestamp()});
        }
      } catch (_) {
        registry.optimistic(propertyId, doc.exists, uid);
        rethrow;
      }
    }, actorUid: uid);
  }
}

/// Queries only currently requested IDs in groups of at most 30. Card rebuilds
/// share batches; no full favorite/property collection is needed for hearts.
class FavoriteRegistry {
  FavoriteRegistry(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final Map<String, Set<MultiStreamController<bool>>> _watchers = {};
  final Map<String, bool> _values = {};
  final Set<String> _ready = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _batches = {};
  StreamSubscription<User?>? _auth;
  String? _uid;
  bool _scheduled = false;
  bool? known(String id) =>
      _uid == auth.currentUser?.uid && _ready.contains(id) ? _values[id] : null;
  Stream<bool> watch(String id) => Stream<bool>.multi((controller) {
        _watchers.putIfAbsent(id, () => {}).add(controller);
        _uid ??= auth.currentUser?.uid;
        _auth ??= auth.authStateChanges().listen((user) {
          if (user?.uid == _uid) return;
          _uid = user?.uid;
          _values.clear();
          _ready.clear();
          for (final id in _watchers.keys) {
            _emit(id, false);
          }
          _schedule();
        });
        controller.add(known(id) ?? false);
        _schedule();
        controller.onCancel = () {
          _watchers[id]?.remove(controller);
          if (_watchers[id]?.isEmpty ?? false) _watchers.remove(id);
          _schedule();
        };
      });
  void optimistic(String id, bool value, String uid) {
    if (_uid != uid || auth.currentUser?.uid != uid) return;
    _values[id] = value;
    _ready.add(id);
    _emit(id, value);
  }

  void _emit(String id, bool value) {
    for (final c in _watchers[id] ?? <MultiStreamController<bool>>{}) {
      c.add(value);
    }
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      _reconcile();
    });
  }

  void _reconcile() {
    final uid = _uid;
    final ids = _watchers.keys.toList()..sort();
    final required = <String, List<String>>{};
    if (uid != null) {
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
        required['$uid|${chunk.join('|')}'] = chunk;
      }
    }
    for (final key in _batches.keys.toList()) {
      if (!required.containsKey(key)) {
        _batches.remove(key)?.cancel();
      }
    }
    for (final entry in required.entries) {
      if (_batches.containsKey(entry.key)) {
        continue;
      }
      _batches[entry.key] = db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .where(FieldPath.documentId, whereIn: entry.value)
          .snapshots()
          .listen((snapshot) {
        if (_uid != uid ||
            auth.currentUser?.uid != uid ||
            !_batches.containsKey(entry.key)) {
          return;
        }
        final found = snapshot.docs.map((d) => d.id).toSet();
        for (final id in entry.value) {
          _values[id] = found.contains(id);
          _ready.add(id);
          _emit(id, _values[id]!);
        }
      }, onError: (Object e) {
        if (_uid == uid) {
          for (final id in entry.value) {
            for (final c in _watchers[id] ?? <MultiStreamController<bool>>{}) {
              c.addError(e);
            }
          }
        }
      });
    }
    _values.removeWhere((key, _) => !_watchers.containsKey(key));
    _ready.removeWhere((key) => !_watchers.containsKey(key));
    if (ids.isEmpty) {
      _auth?.cancel();
      _auth = null;
      _uid = null;
      _values.clear();
      _ready.clear();
    }
  }
}
