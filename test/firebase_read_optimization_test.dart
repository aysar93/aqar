// SDK doubles for read budgets; Rules and counters have separate emulator tests.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:aqar/core/data/document_read_cache.dart';
import 'package:aqar/core/data/paged_query.dart';
import 'package:aqar/core/data/shared_stream.dart';
import 'package:aqar/services/favorites_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'analytics/activity_tracking_test.dart' show TestAuth, TestUser;
import 'package:aqar/chat/utils/message_windows.dart';

typedef Data = Map<String, dynamic>;

class Store implements FirebaseFirestore {
  final data = <String, Data>{};
  final listeners = <void Function()>{};
  int starts = 0, cancels = 0, gets = 0;
  final limits = <int>[];
  Object? failure;
  void emit() {
    for (final listener in listeners.toList()) {
      listener();
    }
  }

  @override
  CollectionReference<Data> collection(String path) => Collection(this, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QueryFake implements Query<Data> {
  QueryFake(this.store, this.path,
      {this.size,
      this.cursor,
      String? id,
      this.ids,
      this.equal = const {},
      this.orders = const [],
      this.cursorDoc})
      : selectedId = id;
  final Store store;
  final String path;
  final int? size;
  final String? cursor, selectedId;
  final List<Object?>? ids;
  final Map<Object, Object?> equal;
  final List<List<Object>> orders;
  final DocumentSnapshot? cursorDoc;
  @override
  Map<String, dynamic> get parameters => {'orderBy': orders};
  List<QueryDocumentSnapshot<Data>> results() {
    final docs = store.data.entries
        .where((e) =>
            e.key.startsWith('$path/') &&
            e.key.substring(path.length + 1).split('/').length == 1)
        .map((e) => Doc(store, e.key, e.value))
        .where((d) =>
            (cursor == null ||
                cursorDoc != null ||
                d.id.compareTo(cursor!) > 0) &&
            (selectedId == null || d.id == selectedId) &&
            (ids == null || ids!.contains(d.id)) &&
            equal.entries.every((e) => d.data()[e.key] == e.value))
        .toList()
      ..sort(compareDocs);
    final filtered = cursorDoc == null
        ? docs
        : docs.where((d) => compareDocs(d, cursorDoc!) > 0).toList();
    return size == null ? filtered : filtered.take(size!).toList();
  }

  int compareDocs(DocumentSnapshot a, DocumentSnapshot b) {
    for (final order in orders) {
      final x = a.get(order[0]), y = b.get(order[0]);
      int cmp = 0;
      if (x is Timestamp && y is Timestamp) {
        cmp = x.compareTo(y);
      } else if (x is num && y is num) {
        cmp = x.compareTo(y);
      } else {
        cmp = x.toString().compareTo(y.toString());
      }
      if (cmp != 0) return order[1] == true ? -cmp : cmp;
    }
    final tie = a.id.compareTo(b.id);
    return orders.isNotEmpty && orders.last[1] == true ? -tie : tie;
  }

  @override
  Query<Data> limit(int value) {
    store.limits.add(value);
    return QueryFake(store, path,
        size: value,
        cursor: cursor,
        id: selectedId,
        ids: ids,
        equal: equal,
        orders: orders,
        cursorDoc: cursorDoc);
  }

  @override
  Query<Data> startAfterDocument(DocumentSnapshot documentSnapshot) =>
      QueryFake(store, path,
          size: size,
          cursor: documentSnapshot.id,
          id: selectedId,
          ids: ids,
          equal: equal,
          orders: orders,
          cursorDoc: documentSnapshot);
  @override
  Query<Data> where(Object field,
          {Object? isEqualTo,
          Object? isNotEqualTo,
          Object? isLessThan,
          Object? isLessThanOrEqualTo,
          Object? isGreaterThan,
          Object? isGreaterThanOrEqualTo,
          Object? arrayContains,
          Iterable<Object?>? arrayContainsAny,
          Iterable<Object?>? whereIn,
          Iterable<Object?>? whereNotIn,
          bool? isNull}) =>
      QueryFake(store, path,
          size: size,
          cursor: cursor,
          id: field == FieldPath.documentId ? isEqualTo as String? : selectedId,
          ids: whereIn?.toList() ?? ids,
          equal: field == FieldPath.documentId
              ? equal
              : {...equal, field: isEqualTo},
          orders: orders,
          cursorDoc: cursorDoc);
  @override
  Query<Data> orderBy(Object field, {bool descending = false}) =>
      QueryFake(store, path,
          size: size,
          cursor: cursor,
          id: selectedId,
          ids: ids,
          equal: equal,
          orders: [
            ...orders,
            [field, descending]
          ],
          cursorDoc: cursorDoc);
  @override
  Future<QuerySnapshot<Data>> get([GetOptions? options]) async {
    store.gets++;
    if (store.failure != null) throw store.failure!;
    return Snap(results());
  }

  @override
  Stream<QuerySnapshot<Data>> snapshots(
          {bool includeMetadataChanges = false,
          ListenSource source = ListenSource.defaultSource}) =>
      Stream<QuerySnapshot<Data>>.multi((c) {
        store.starts++;
        void send() {
          if (store.failure != null) {
            c.addError(store.failure!);
          } else {
            c.add(Snap(results()));
          }
        }

        store.listeners.add(send);
        send();
        c.onCancel = () {
          store.cancels++;
          store.listeners.remove(send);
        };
      });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Collection extends QueryFake implements CollectionReference<Data> {
  Collection(super.store, super.path);
  @override
  DocumentReference<Data> doc([String? id]) => Reference(store, '$path/$id');
}

class Reference implements DocumentReference<Data> {
  Reference(this.store, this.path);
  final Store store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Data> collection(String collectionPath) =>
      Collection(store, '$path/$collectionPath');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Doc implements QueryDocumentSnapshot<Data> {
  Doc(this.store, this.path, this.value);
  final Store store;
  final String path;
  final Data value;
  @override
  String get id => path.split('/').last;
  @override
  Data data() => value;
  @override
  dynamic get(Object field) =>
      value[field is FieldPath ? field.components.join('.') : field];
  @override
  bool get exists => true;
  @override
  DocumentReference<Data> get reference => Reference(store, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Meta implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
}

class Snap implements QuerySnapshot<Data> {
  Snap(this.docs);
  @override
  final List<QueryDocumentSnapshot<Data>> docs;
  @override
  int get size => docs.length;
  @override
  SnapshotMetadata get metadata => Meta();
  @override
  List<DocumentChange<Data>> get docChanges => [];
}

Future<void> flush() async {
  for (var n = 0; n < 8; n++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Store catalogue(int size) {
  final store = Store();
  for (var i = 0; i < size; i++) {
    store.data['properties/${i.toString().padLeft(3, '0')}'] = {
      'status': 'approved'
    };
  }
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('chat windows merge cursor overlap, live messages and deletion', () {
    final store = Store();
    Doc message(String id, int time) => Doc(store, 'messages/$id',
        {'createdAt': Timestamp.fromMillisecondsSinceEpoch(time)});
    final a = message('a', 1),
        b = message('b', 2),
        c = message('c', 3),
        d = message('d', 4);
    expect(
        mergeMessageWindows([
          c,
          d
        ], [
          [a, b, c]
        ]).map((d) => d.id),
        ['a', 'b', 'c', 'd']);
    expect(
        mergeMessageWindows([
          c,
          d
        ], [
          [a, c]
        ]).map((d) => d.id),
        ['a', 'c', 'd']);
  });
  test('20+20+20 cursor pages, no duplicates, no eager full query', () async {
    final store = catalogue(65);
    final page = PagedQueryController(store.collection('properties'));
    expect(page.snapshot.connectionState, ConnectionState.waiting);
    page.start();
    page.start();
    await flush();
    expect(page.documents.length, 20);
    expect(store.starts, 1);
    expect(store.gets, 0);
    await Future.wait([page.loadMore(), page.loadMore()]);
    expect(page.documents.length, 40);
    expect(store.gets, 0);
    expect(store.starts, 2);
    await page.loadMore();
    expect(page.documents.length, 60);
    await page.loadMore();
    expect(page.documents.length, 65);
    expect(page.hasMore, false);
    expect(page.documents.map((d) => d.id).toSet().length, 65);
    expect(store.limits.every((n) => n == 20), true);
    page.dispose();
    await flush();
    expect(store.listeners, isEmpty);
  });
  test('explicit refresh clears older pages and removed content', () async {
    final store = catalogue(45);
    final page = PagedQueryController(store.collection('properties'))..start();
    await flush();
    await page.loadMore();
    store.data.remove('properties/030');
    await page.refresh();
    await flush();
    await page.loadMore();
    expect(page.documents.any((d) => d.id == '030'), false);
    expect(page.documents.length, 40);
    page.dispose();
  });
  test('older pages hide deletion live and preserve a displaced boundary',
      () async {
    final store = catalogue(65);
    final page = PagedQueryController(store.collection('properties'))..start();
    await flush();
    await page.loadMore();
    store.data.remove('properties/030');
    store.emit();
    await flush();
    expect(page.documents.any((d) => d.id == '030'), false);
    expect(page.documents.any((d) => d.id == '040'), true);
    store.data['properties/-01'] = {'status': 'approved'};
    store.emit();
    await flush();
    expect(page.documents.any((d) => d.id == '019'), true);
    store.data.remove('properties/019');
    store.emit();
    await flush();
    expect(page.documents.any((d) => d.id == '019'), false);
    await page.loadMore();
    expect(
        page.documents.map((d) => d.id).toSet().length, page.documents.length);
    store.data['properties/025x'] = {'status': 'approved'};
    store.emit();
    await flush();
    expect(page.documents.any((d) => d.id == '040'), true);
    final sorted = page.documents.map((d) => d.id).toList();
    expect(sorted, List<String>.from(sorted)..sort());
    store.data.remove('properties/040');
    store.emit();
    await flush();
    expect(page.documents.any((d) => d.id == '040'), false);
    page.dispose();
    await flush();
    expect(store.listeners, isEmpty);
  });
  test('permission error remains an error, never successful zero', () async {
    final store = catalogue(1)..failure = StateError('permission-denied');
    final page = PagedQueryController(store.collection('properties'))..start();
    await flush();
    expect(page.snapshot.hasError, true);
    expect(page.snapshot.hasData, false);
    page.dispose();
  });
  testWidgets('ordinary rebuild keeps one subscription', (tester) async {
    final store = catalogue(25), query = QueryFake(catalogue(0), 'unused');
    final source = store.collection('properties');
    Widget view(String label) => MaterialApp(
        home: PagedQueryBuilder(
            query: source, builder: (context, snapshot) => Text(label)));
    await tester.pumpWidget(view('first'));
    await tester.pump();
    await tester.pumpWidget(view('rebuild'));
    await tester.pump();
    expect(store.starts, 1);
    expect(query.path, 'unused');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(store.listeners, isEmpty);
  });
  test('cache deduplicates concurrent reads and expires without timers',
      () async {
    var now = DateTime(2026);
    var calls = 0;
    final cache = AsyncReadCache<int>(now: () => now);
    Future<int> load() async => ++calls;
    expect(await Future.wait([cache.read('a', load), cache.read('a', load)]),
        [1, 1]);
    now = now.add(const Duration(seconds: 29));
    expect(await cache.read('a', load), 1);
    now = now.add(const Duration(seconds: 2));
    expect(await cache.read('a', load), 2);
    cache.clear();
    expect(await cache.read('a', load), 3);
  });
  test('cache failure is not retained; old actor result cannot repopulate',
      () async {
    final cache = AsyncReadCache<int>();
    final pending = Completer<int>();
    final old = cache.read('a', () => pending.future);
    cache.clear();
    pending.complete(1);
    await old;
    expect(await cache.read('a', () async => 2), 2);
    await expectLater(cache.read('bad', () async => throw StateError('denied')),
        throwsStateError);
    expect(await cache.read('bad', () async => 3), 3);
  });
  test('shared streams replay once and cancel their upstream', () async {
    var starts = 0, cancels = 0;
    final source = Stream<int>.multi((c) {
      starts++;
      c.add(7);
      c.onCancel = () => cancels++;
    });
    final shared = SharedStream(source);
    final a = <int>[], b = <int>[];
    final first = shared.stream.listen(a.add);
    await flush();
    final second = shared.stream.listen(b.add);
    await flush();
    expect(starts, 1);
    expect(a, [7]);
    expect(b, [7]);
    await first.cancel();
    expect(cancels, 0);
    await second.cancel();
    expect(cancels, 1);
  });
  test('20 card hearts use one bounded query; account switch and logout reset',
      () async {
    final store = Store()
      ..data['users/A/favorites/000'] = {'createdAt': Timestamp.now()};
    final auth = TestAuth(TestUser('A'));
    final registry = FavoriteRegistry(store, auth);
    final values = <String, bool>{};
    final subs = <StreamSubscription<bool>>[];
    for (var i = 0; i < 20; i++) {
      final id = i.toString().padLeft(3, '0');
      subs.add(registry.watch(id).listen((v) => values[id] = v));
    }
    await flush();
    expect(store.starts, 1);
    expect(values['000'], true);
    expect(values['001'], false);
    registry.optimistic('001', true, 'A');
    await flush();
    expect(values['001'], true);
    auth.emit(TestUser('B'));
    await flush();
    expect(values.values.every((v) => !v), true);
    expect(store.listeners.length, 1);
    auth.emit(null);
    await flush();
    expect(store.listeners, isEmpty);
    expect(values.values.every((v) => !v), true);
    for (final sub in subs) {
      await sub.cancel();
    }
    await flush();
    expect(store.listeners, isEmpty);
    await auth.changes.close();
  });
}
