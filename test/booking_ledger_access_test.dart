import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_ledger_access.dart';

void main() {
  late StreamController<String?> sessions;
  late Map<String, StreamController<BookingLedgerPermission>> roles;
  String? uid;
  setUp(() {
    sessions = StreamController<String?>.broadcast();
    roles = {
      for (final id in ['finance', 'customer'])
        id: StreamController<BookingLedgerPermission>.broadcast()
    };
    uid = 'finance';
  });
  tearDown(() async {
    await sessions.close();
    for (final role in roles.values) {
      await role.close();
    }
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        home: BookingLedgerAccess(
            sessions: sessions.stream,
            currentUid: () => uid,
            permissions: (id) => roles[id]!.stream,
            builder: (_) => const Text('PRIVATE_LEDGER_REFERENCE'))));
    sessions.add(uid);
    await tester.pump();
    await tester.pump();
  }

  Future<void> permission(WidgetTester tester, String id,
      {bool allowed = true, bool cache = false}) async {
    roles[id]!.add(BookingLedgerPermission(allowed: allowed, fromCache: cache));
    await tester.pump();
    await tester.pump();
  }

  void hidden() => expect(find.text('PRIVATE_LEDGER_REFERENCE'), findsNothing);

  testWidgets(
      'cached privilege never mounts ledger; server grant then offline hides it',
      (tester) async {
    await mount(tester);
    hidden();
    await permission(tester, 'finance', cache: true);
    hidden();
    await permission(tester, 'finance');
    expect(find.text('PRIVATE_LEDGER_REFERENCE'), findsOneWidget);
    await permission(tester, 'finance', cache: true);
    hidden();
  });
  testWidgets(
      'account switch discards grant and rejects delayed old-account updates',
      (tester) async {
    await mount(tester);
    await permission(tester, 'finance');
    expect(find.text('PRIVATE_LEDGER_REFERENCE'), findsOneWidget);
    uid = 'customer';
    sessions.add(uid);
    await tester.pump();
    await tester.pump();
    hidden();
    await permission(tester, 'finance');
    hidden();
    await permission(tester, 'customer', cache: true);
    hidden();
    await permission(tester, 'customer', allowed: false);
    hidden();
  });
  testWidgets('revocation, stream failure and sign-out remove private subtree',
      (tester) async {
    await mount(tester);
    await permission(tester, 'finance');
    await permission(tester, 'finance', allowed: false);
    hidden();
    await permission(tester, 'finance');
    roles['finance']!.addError(StateError('permission-denied'));
    await tester.pump();
    await tester.pump();
    hidden();
    await permission(tester, 'finance');
    uid = null;
    sessions.add(null);
    await tester.pump();
    await tester.pump();
    hidden();
    await permission(tester, 'finance');
    hidden();
  });
  testWidgets('identity change before auth event cannot accept delayed grant',
      (tester) async {
    await mount(tester);
    uid = 'customer';
    await permission(tester, 'finance');
    hidden();
  });
}
