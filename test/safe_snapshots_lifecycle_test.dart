import 'dart:async';
import 'package:aqar/moderation/user_blocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test-only Firestore adapter: no network or production database access.
// ignore: subtype_of_sealed_class, must_be_immutable
class _Query extends Fake implements Query<Map<String, dynamic>> {
  int active = 0;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      Stream.multi((controller) {
        active++;
        controller.add(_Snapshot());
        controller.onCancel = () {
          active--;
        };
      }, isBroadcast: true);
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

void main() {
  test('Visibility changes still refresh active listeners after reconnecting',
      () async {
    final query = _Query();
    final stream = query.safeSnapshots();
    var events = 0;
    final first = stream.listen((_) => events++);
    await Future<void>.delayed(Duration.zero);
    // The same notifier is used after a block/unblock or account change.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    UserBlocks.instance.notifyListeners();
    await Future<void>.delayed(Duration.zero);
    expect(events, 2);
    await first.cancel();
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    UserBlocks.instance.notifyListeners();
    await Future<void>.delayed(Duration.zero);
    expect(events, 2);
    final second = stream.listen((_) => events++);
    await Future<void>.delayed(Duration.zero);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    UserBlocks.instance.notifyListeners();
    await Future<void>.delayed(Duration.zero);
    expect(events, 4);
    await second.cancel();
    expect(query.active, 0);
  });

  testWidgets('Safe query survives scroll disposal and remount',
      (tester) async {
    final query = _Query();
    final stream = query.safeSnapshots();
    Widget page() => MaterialApp(
            home: StreamBuilder(
          stream: stream,
          builder: (_, snapshot) =>
              Text(snapshot.hasData ? 'loaded' : 'loading'),
        ));
    await tester.pumpWidget(page());
    await tester.pump();
    expect(find.text('loaded'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(query.active, 0);
    await tester.pumpWidget(page());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('loaded'), findsOneWidget);
  });

  test('Independent listeners can cancel and reconnect', () async {
    final query = _Query();
    final stream = query.safeSnapshots().map((s) => s.docs.length);
    final first = stream.listen((_) {});
    final second = stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(query.active, 2);
    await first.cancel();
    expect(query.active, 1);
    await second.cancel();
    expect(query.active, 0);
    expect(await stream.first, 0);
    expect(query.active, 0);
  });
}
