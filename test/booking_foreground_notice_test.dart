import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/booking_foreground_notice.dart';

void main() {
  const payload = {'type': 'booking', 'bookingId': 'booking-one'};
  late String? uid;
  late GlobalKey<NavigatorState> key;
  late List<Map<String, dynamic>> opened;

  Future<BookingForegroundNotice> mount(
      WidgetTester tester, Future<bool> Function(String) read) async {
    uid = 'customer';
    key = GlobalKey<NavigatorState>();
    opened = [];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      home: const Scaffold(body: Text('الحجوزات')),
    ));
    return BookingForegroundNotice(
      navigatorKey: key,
      currentUserId: () => uid,
      canReadBooking: read,
      openBooking: (data) async {
        opened.add(data);
      },
    );
  }

  testWidgets('readable foreground booking has an action for the same booking',
      (tester) async {
    final reads = <String>[];
    final notice = await mount(tester, (id) async {
      reads.add(id);
      return true;
    });
    await notice.receive(payload);
    await tester.pumpAndSettle();
    expect(find.text('لديك تحديث في حجز'), findsOneWidget);
    await tester.tap(find.text('عرض الحجز'));
    await tester.pumpAndSettle();
    expect(opened.single['bookingId'], 'booking-one');
    expect(reads, ['booking-one', 'booking-one']);
  });

  testWidgets('rejects missing session and malformed or unrelated payloads',
      (tester) async {
    var reads = 0;
    final notice = await mount(tester, (_) async {
      reads++;
      return true;
    });
    await notice.receive({'type': 'chat', 'bookingId': 'booking-one'});
    await notice.receive({'type': 'booking', 'bookingId': 'bad/path'});
    uid = null;
    await notice.receive(payload);
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('does not display denied or offline booking data',
      (tester) async {
    var offline = false;
    final notice = await mount(tester, (_) async {
      if (offline) throw StateError('offline');
      return false;
    });
    await notice.receive(payload);
    offline = true;
    await notice.receive(payload);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(opened, isEmpty);
  });

  testWidgets('account switch while verifying does not present the old notice',
      (tester) async {
    final result = Completer<bool>();
    final notice = await mount(tester, (_) => result.future);
    final pending = notice.receive(payload);
    uid = 'another-customer';
    result.complete(true);
    await pending;
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('account switch before action prevents navigation',
      (tester) async {
    var reads = 0;
    final notice = await mount(tester, (_) async {
      reads++;
      return true;
    });
    await notice.receive(payload);
    await tester.pumpAndSettle();
    uid = 'another-customer';
    await tester.tap(find.text('عرض الحجز'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(reads, 1);
  });

  testWidgets('revoked access while notice is visible prevents navigation',
      (tester) async {
    var allowed = true;
    final notice = await mount(tester, (_) async => allowed);
    await notice.receive(payload);
    await tester.pumpAndSettle();
    allowed = false;
    await tester.tap(find.text('عرض الحجز'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });
}
