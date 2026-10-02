// Firebase SDK doubles; actual security is verified on local emulators.
// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'package:aqar/analytics/models/analytics_models.dart';
import 'package:aqar/analytics/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class QueryStore implements FirebaseFirestore {
  final results =
      <String, List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>{};
  final queries = <RecordedQuery>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      RecordedQuery(this, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordedQuery implements CollectionReference<Map<String, dynamic>> {
  RecordedQuery(this.store, this.path);
  final QueryStore store;
  @override
  final String path;
  final conditions = <(Object, Object?, Object?, Object?, Object?)>[];
  final ordering = <(Object, bool)>[];
  int? maximum;
  DocumentSnapshot? cursor;
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    conditions.add((
      field,
      isEqualTo,
      isGreaterThanOrEqualTo,
      isLessThanOrEqualTo,
      whereIn
    ));
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    ordering.add((field, descending));
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    maximum = limit;
    return this;
  }

  @override
  Query<Map<String, dynamic>> startAfterDocument(
      DocumentSnapshot documentSnapshot) {
    cursor = documentSnapshot;
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.queries.add(this);
    final batches = store.results[path] ?? [];
    return QueryResult(batches.isEmpty ? [] : batches.removeAt(0));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QueryResult implements QuerySnapshot<Map<String, dynamic>> {
  QueryResult(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QueryDoc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  QueryDoc(this.id, this.values);
  @override
  final String id;
  final Map<String, dynamic> values;
  @override
  Map<String, dynamic> data() => values;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('30-result server filter and cursor; one profile batch and cache reuse',
      () async {
    final end = DateTime(2026, 10, 2, 12);
    final docs = List.generate(
        30,
        (index) => QueryDoc('uid$index', {
              'isGuest': false,
              'userId': 'uid$index',
              'lastSeen':
                  Timestamp.fromDate(end.subtract(Duration(minutes: index))),
              'platform': index.isEven ? 'android' : 'ios',
            }));
    final store = QueryStore();
    store.results['user_activity'] = [
      docs,
      [docs.first]
    ];
    store.results['users'] = [
      docs
          .map((doc) => QueryDoc(doc.id, {
                'name': 'Name ${doc.id}',
                'photoUrl': 'https://example.com/photo.png',
                'provider': 'google.com',
              }))
          .toList()
    ];
    final service = AnalyticsService(firestore: store);
    final first = await service.activeLast24Hours(windowEnd: end);
    final next =
        await service.activeLast24Hours(windowEnd: end, after: first.cursor);
    final activity =
        store.queries.where((query) => query.path == 'user_activity').toList();
    expect(activity.length, 2);
    expect(activity.every((query) => query.maximum == 30), isTrue);
    expect(activity.first.conditions,
        contains(('isGuest', false, null, null, null)));
    expect(
        activity.first.conditions.any((entry) =>
            entry.$1 == 'lastSeen' &&
            entry.$3 ==
                Timestamp.fromDate(end.subtract(const Duration(hours: 24)))),
        isTrue);
    expect(activity.first.ordering, [('lastSeen', true)]);
    expect(activity.last.cursor, same(first.cursor));
    expect(store.queries.where((query) => query.path == 'users').length, 1);
    expect(first.hasMore, isTrue);
    expect(next.hasMore, isFalse);
    expect(next.users.first.provider, 'google.com');
    expect(first.users.first.platform, 'android');
    expect(first.users[1].platform, 'ios');
  });

  test(
      'summary/chart share one bounded-time query and preserve session meanings',
      () async {
    final now = DateTime(2026, 10, 2, 12);
    final store = QueryStore();
    final sessions = [
      QueryDoc('1', {
        'visitorId': 'A',
        'userId': 'A',
        'isGuest': false,
        'startedAt': Timestamp.fromDate(now),
        'endedAt': Timestamp.fromDate(now),
        'durationSeconds': 60
      }),
      QueryDoc('2', {
        'visitorId': 'A',
        'userId': 'A',
        'isGuest': false,
        'startedAt': Timestamp.fromDate(now),
        'endedAt': null,
        'durationSeconds': 0
      }),
      QueryDoc('3', {
        'visitorId': 'B',
        'userId': 'B',
        'isGuest': false,
        'startedAt': Timestamp.fromDate(now),
        'endedAt': Timestamp.fromDate(now),
        'durationSeconds': 120
      }),
      QueryDoc('4', {
        'visitorId': 'guest',
        'isGuest': true,
        'startedAt': Timestamp.fromDate(now),
        'endedAt': null
      }),
    ];
    store.results['app_sessions'] = [sessions, sessions];
    final service = AnalyticsService(firestore: store)..setServerNow(now);
    final values = await Future.wait([
      service.summary(AnalyticsPeriod.last24Hours),
      service.chart(AnalyticsPeriod.last24Hours)
    ]);
    final summary = values.first as AnalyticsSummary;
    expect(summary.sessions, 4);
    expect(summary.registeredUsers, 3);
    expect(summary.registeredUniqueUsers, 2);
    expect(summary.guests, 1);
    expect(summary.averageDurationSeconds, 90);
    expect(summary.completedSessions, 2);
    expect(store.queries.length, 1);
    expect(
        store.queries.single.conditions.any((entry) =>
            entry.$1 == 'startedAt' && entry.$4 == Timestamp.fromDate(now)),
        isTrue);
    service.invalidateSessions();
    await service.summary(AnalyticsPeriod.last24Hours);
    expect(store.queries.length, 2);
  });
}
