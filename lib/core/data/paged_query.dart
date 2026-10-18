import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../moderation/user_blocks.dart';

/// One bounded live window per requested page. Older windows are opened only
/// on demand, so deletion/moderation stays live without per-document listeners.
/// A raw cursor is retained even when viewer blocking hides page documents.
class PagedQueryController<T extends Object?> extends ChangeNotifier {
  PagedQueryController(this.query,
      {this.pageSize = 20, this.safe = false, this.compare, this.matches});
  final Query<T> query;
  final int pageSize;
  final bool safe;
  final Comparator<QueryDocumentSnapshot<T>>? compare;
  final bool Function(T data)? matches;
  StreamSubscription<QuerySnapshot<T>>? _subscription;
  QuerySnapshot<T>? _head;
  final Map<String, QueryDocumentSnapshot<T>> _older = {};
  final Set<String> _bridgeIds = {};
  final Map<String, StreamSubscription<QuerySnapshot<T>>> _bridges = {};
  final Map<int, List<QueryDocumentSnapshot<T>>> _pages = {};
  final List<StreamSubscription<QuerySnapshot<T>>> _pageSubscriptions = [];
  final Set<Completer<void>> _pending = {};
  List<QueryDocumentSnapshot<T>> get headDocuments => _head?.docs ?? [];
  DocumentSnapshot<T>? _cursor;
  bool hasMore = false, loadingMore = false, _disposed = false;
  Object? error;
  int _generation = 0;
  bool _started = false;

  List<QueryDocumentSnapshot<T>> get documents {
    final byId = {
      for (final d in _head?.docs ?? <QueryDocumentSnapshot<T>>[]) d.id: d,
      for (final entry in _older.entries)
        if (!(_head?.docs.any((d) => d.id == entry.key) ?? false))
          entry.key: entry.value,
      for (final page in _pages.values)
        for (final d in page)
          if (!(_head?.docs.any((h) => h.id == d.id) ?? false)) d.id: d,
    };
    final result = byId.values.where((d) {
      final value = d.data();
      return (matches == null || matches!(value)) &&
          (!safe ||
              value is! Map ||
              !UserBlocks.instance.hides(Map<String, dynamic>.from(value)));
    }).toList();
    result.sort(compare ?? _queryOrder);
    return result;
  }

  int _queryOrder(QueryDocumentSnapshot<T> a, QueryDocumentSnapshot<T> b) {
    final orders = query.parameters['orderBy'] as List? ?? const [];
    for (final order in orders) {
      final field = order[0] as Object;
      final descending = order[1] == true;
      final x = field == FieldPath.documentId ? a.id : a.get(field);
      final y = field == FieldPath.documentId ? b.id : b.get(field);
      final int comparison;
      if (x == y) {
        comparison = 0;
      } else if (x == null || y == null) {
        comparison = x == null ? -1 : 1;
      } else if (x is Timestamp && y is Timestamp) {
        comparison = x.compareTo(y);
      } else if (x is num && y is num) {
        comparison = x.compareTo(y);
      } else if (x is bool && y is bool) {
        comparison = x ? 1 : -1;
      } else {
        comparison = x.toString().compareTo(y.toString());
      }
      if (comparison != 0) return descending ? -comparison : comparison;
    }
    final tie = a.id.compareTo(b.id);
    return orders.isNotEmpty && orders.last[1] == true ? -tie : tie;
  }

  AsyncSnapshot<QuerySnapshot<T>> get snapshot => error != null
      ? AsyncSnapshot.withError(ConnectionState.active, error!)
      : _head == null
          ? const AsyncSnapshot.waiting()
          : AsyncSnapshot.withData(
              ConnectionState.active, _PageSnapshot(_head!, documents));

  void start() {
    if (_started || _disposed) return;
    _started = true;
    if (safe) UserBlocks.instance.addListener(_notify);
    _subscribe();
  }

  void _subscribe() {
    final revision = ++_generation;
    _subscription = query.limit(pageSize).snapshots().listen((value) {
      if (_disposed || revision != _generation) return;
      final previous = _head?.docs ?? <QueryDocumentSnapshot<T>>[];
      final ids = value.docs.map((d) => d.id).toSet();
      // Preserve an item displaced by a new head item only after revalidation.
      // Deleted/unauthorized items are discarded; cache never fabricates them.
      for (final d in previous.where((d) => !ids.contains(d.id))) {
        _bridgeIds.add(d.id);
      }
      _head = value;
      _reconcileBridges();
      assert(() {
        debugPrint('[READ_BUDGET] bounded-window pageSize=$pageSize '
            'returned=${value.docs.length} fromCache=${value.metadata.isFromCache} '
            'changes=${value.docChanges.length}');
        return true;
      }());
      for (final d in value.docs) {
        _older.remove(d.id);
      }
      if (_pages.isEmpty) {
        _cursor = value.docs.isEmpty ? null : value.docs.last;
        hasMore = value.docs.length == pageSize;
      }
      error = null;
      _notify();
    }, onError: (Object e) {
      if (!_disposed && revision == _generation) {
        error = e;
        _notify();
      }
    });
  }

  void _reconcileBridges() {
    final covered = {
      ...headDocuments.map((d) => d.id),
      for (final page in _pages.values) ...page.map((d) => d.id)
    };
    _bridgeIds.removeAll(covered);
    _older.removeWhere((id, _) => !_bridgeIds.contains(id));
    final ids = _bridgeIds.toList()..sort();
    final required = <String, List<String>>{};
    for (var i = 0; i < ids.length; i += 10) {
      final group = ids.sublist(i, (i + 10).clamp(0, ids.length));
      required[group.join('|')] = group;
    }
    for (final key in _bridges.keys.toList()) {
      if (!required.containsKey(key)) _bridges.remove(key)?.cancel();
    }
    final generation = _generation;
    for (final entry in required.entries) {
      if (_bridges.containsKey(entry.key)) {
        continue;
      }
      _bridges[entry.key] = query
          .where(FieldPath.documentId, whereIn: entry.value)
          .snapshots()
          .listen((snapshot) {
        if (_disposed ||
            generation != _generation ||
            !_bridges.containsKey(entry.key)) {
          return;
        }
        final found = snapshot.docs.map((d) => d.id).toSet();
        for (final id in entry.value) {
          if (!found.contains(id)) {
            _bridgeIds.remove(id);
            _older.remove(id);
          }
        }
        for (final doc in snapshot.docs) {
          _older[doc.id] = doc;
        }
        _reconcileBridges();
        _notify();
      }, onError: (Object e) {
        if (!_disposed && generation == _generation) {
          error = e;
          _notify();
        }
      });
    }
  }

  Future<void> loadMore() async {
    if (_disposed || loadingMore || !hasMore || _cursor == null) return;
    loadingMore = true;
    error = null;
    _notify();
    final generation = _generation;
    final completion = Completer<void>();
    _pending.add(completion);
    final pageIndex = _pages.length;
    StreamSubscription<QuerySnapshot<T>>? pageSubscription;
    try {
      pageSubscription = query
          .startAfterDocument(_cursor!)
          .limit(pageSize)
          .snapshots(includeMetadataChanges: true)
          .listen((page) {
        if (_disposed || generation != _generation) return;
        final nextIds = page.docs.map((d) => d.id).toSet();
        for (final doc in _pages[pageIndex] ?? <QueryDocumentSnapshot<T>>[]) {
          if (!nextIds.contains(doc.id)) _bridgeIds.add(doc.id);
        }
        _pages[pageIndex] = page.docs;
        _reconcileBridges();
        assert(() {
          debugPrint(
              '[READ_BUDGET] next-page pageSize=$pageSize returned=${page.docs.length} fromCache=${page.metadata.isFromCache}');
          return true;
        }());
        if (pageIndex == _pages.keys.last) {
          if (page.docs.isNotEmpty) _cursor = page.docs.last;
          hasMore = page.docs.length == pageSize;
          if (!completion.isCompleted &&
              (!page.metadata.isFromCache || page.docs.isNotEmpty)) {
            completion.complete();
          }
        }
        _notify();
      }, onError: (Object e) {
        if (!_disposed && generation == _generation) {
          error = e;
          _notify();
        }
        if (!completion.isCompleted) completion.completeError(e);
      });
      _pageSubscriptions.add(pageSubscription);
      // A single request deadline, not polling or periodic refresh.
      await completion.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      await pageSubscription?.cancel();
      _pageSubscriptions.remove(pageSubscription);
      _pages.remove(pageIndex);
      if (!_disposed && generation == _generation) error = e;
    } finally {
      _pending.remove(completion);
      if (!_disposed && generation == _generation) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    _generation++;
    await _subscription?.cancel();
    for (final subscription in _pageSubscriptions) {
      await subscription.cancel();
    }
    _pageSubscriptions.clear();
    for (final subscription in _bridges.values) {
      await subscription.cancel();
    }
    _bridges.clear();
    _bridgeIds.clear();
    for (final completion in _pending.toList()) {
      if (!completion.isCompleted) completion.complete();
    }
    if (_disposed) return;
    _head = null;
    _older.clear();
    _pages.clear();
    _cursor = null;
    hasMore = false;
    loadingMore = false;
    error = null;
    _notify();
    _subscribe();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription?.cancel();
    for (final subscription in _bridges.values) {
      subscription.cancel();
    }
    for (final subscription in _pageSubscriptions) {
      subscription.cancel();
    }
    for (final completion in _pending.toList()) {
      if (!completion.isCompleted) completion.complete();
    }
    if (safe) UserBlocks.instance.removeListener(_notify);
    super.dispose();
  }
}

class PagedQueryBuilder<T extends Object?> extends StatefulWidget {
  const PagedQueryBuilder(
      {super.key,
      required this.query,
      required this.builder,
      this.pageSize = 20,
      this.safe = false,
      this.compare,
      this.matches});
  final Query<T> query;
  final int pageSize;
  final bool safe;
  final Comparator<QueryDocumentSnapshot<T>>? compare;
  final bool Function(T data)? matches;
  final Widget Function(BuildContext, AsyncSnapshot<QuerySnapshot<T>>) builder;
  @override
  State<PagedQueryBuilder<T>> createState() => PagedQueryBuilderState<T>();
}

class PagedQueryBuilderState<T extends Object?>
    extends State<PagedQueryBuilder<T>> {
  late PagedQueryController<T> _controller;
  Future<void> refresh() => _controller.refresh();
  void _create() {
    _controller = PagedQueryController(widget.query,
        pageSize: widget.pageSize,
        safe: widget.safe,
        compare: widget.compare,
        matches: widget.matches);
    _controller.addListener(_change);
    _controller.start();
  }

  void _change() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(covariant PagedQueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query ||
        widget.pageSize != oldWidget.pageSize) {
      _controller.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollUpdateNotification &&
                n.metrics.maxScrollExtent > 0 &&
                n.metrics.extentAfter < 250) {
              unawaited(_controller.loadMore());
            }
            return false;
          },
          child: widget.builder(context, _controller.snapshot));
}

class _PageSnapshot<T extends Object?> implements QuerySnapshot<T> {
  _PageSnapshot(this.source, this.docs);
  final QuerySnapshot<T> source;
  @override
  final List<QueryDocumentSnapshot<T>> docs;
  @override
  int get size => docs.length;
  @override
  SnapshotMetadata get metadata => source.metadata;
  @override
  List<DocumentChange<T>> get docChanges => [];
}
