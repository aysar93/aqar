import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_screen.dart';

class TestMeta extends Fake implements SnapshotMetadata {
  TestMeta({this.isFromCache = false, this.hasPendingWrites = false});
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

class TestDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  TestDoc(this.value, {bool cached = false})
      : metadata = TestMeta(isFromCache: cached);
  final Map<String, dynamic> value;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic> data() => value;
}

class TestQueryDoc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  TestQueryDoc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class TestRecords extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  TestRecords(List<Map<String, dynamic>> values)
      : metadata = TestMeta(isFromCache: false, hasPendingWrites: false),
        docs = [
          for (var i = 0; i < values.length; i++) TestQueryDoc('event-$i', values[i])
        ];
  @override
  final SnapshotMetadata metadata;
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

Widget testApp(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const currentUid = 'user-123';

  Future<void> testMount(WidgetTester tester, Map<String, dynamic> bookingData) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp(
      BookingDetailsScreen(
        bookingId: 'test-booking-id',
        currentUserId: () => currentUid,
        sessions: Stream.value(currentUid),
        roles: (_) => Stream.value(TestDoc({'isBlocked': false, 'isAdmin': false})),
        paymentAccounts: Stream.value({}),
        events: Stream.value(TestRecords([])),
        dataStream: Stream.value(TestDoc(bookingData)),
        call: (name, data) async => {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('BookingDetailsScreen renders confirmed status without crashing', (tester) async {
    await testMount(tester, {
      'customerId': currentUid,
      'ownerId': 'owner-456',
      'venueName': 'شاليه النخيل',
      'status': 'confirmed',
      'start': 1795327200000,
      'end': 1795359600000,
      'total': 250000,
      'deposit': 50000,
      'remaining': 200000,
      'paid': 50000,
      'terms': 'احترام النظافة',
    });
    final err = tester.takeException();
    if (err != null) {
      print('CAUGHT ERROR: $err');
      if (err is Error) print('STACK TRACE: ${err.stackTrace}');
    }
    expect(err, isNull);
    expect(find.text('تفاصيل الحجز'), findsOneWidget);
  });

  testWidgets('BookingDetailsScreen renders cancelled status without crashing', (tester) async {
    await testMount(tester, {
      'customerId': currentUid,
      'ownerId': 'owner-456',
      'venueName': 'شاليه النخيل',
      'status': 'cancelled',
      'cancelledBy': 'customer',
      'cancellationReason': 'ظروف خاصة',
      'refundStatus': 'pending',
      'refundReference': 'REF-12345',
      'total': 250000,
      'deposit': 50000,
      'remaining': 200000,
    });
    final err = tester.takeException();
    if (err != null) {
      print('CAUGHT ERROR: $err');
      if (err is Error) print('STACK TRACE: ${err.stackTrace}');
    }
    expect(err, isNull);
  });

  testWidgets('BookingDetailsScreen renders rejected status without crashing', (tester) async {
    await testMount(tester, {
      'customerId': currentUid,
      'ownerId': 'owner-456',
      'venueName': 'شاليه النخيل',
      'status': 'rejected',
      'reason': 'المكان غير متاح في هذا التوقيت',
      'total': 250000,
      'deposit': 50000,
    });
    final err = tester.takeException();
    if (err != null) {
      print('CAUGHT ERROR: $err');
      if (err is Error) print('STACK TRACE: ${err.stackTrace}');
    }
    expect(err, isNull);
  });

  testWidgets('BookingDetailsScreen renders expired status without crashing', (tester) async {
    await testMount(tester, {
      'customerId': currentUid,
      'ownerId': 'owner-456',
      'venueName': 'شاليه النخيل',
      'status': 'expired',
      'total': 250000,
      'deposit': 50000,
    });
    final err = tester.takeException();
    if (err != null) {
      print('CAUGHT ERROR: $err');
      if (err is Error) print('STACK TRACE: ${err.stackTrace}');
    }
    expect(err, isNull);
  });

  testWidgets('BookingDetailsScreen renders document with missing optional fields without crashing', (tester) async {
    await testMount(tester, {
      'customerId': currentUid,
      'ownerId': 'owner-456',
      // all optional fields omitted
      'status': 'confirmed',
    });
    final err = tester.takeException();
    if (err != null) {
      print('CAUGHT ERROR: $err');
      if (err is Error) print('STACK TRACE: ${err.stackTrace}');
    }
    expect(err, isNull);
  });

  testWidgets('BookingDetailsScreen renders document with null values and odd types without crashing', (tester) async {
    await testMount(tester, {
      'customerId': currentUid,
      'ownerId': 'owner-456',
      'venueName': null,
      'status': null,
      'start': null,
      'end': null,
      'total': '150000', // String instead of num
      'deposit': '50000',
      'remaining': null,
      'terms': null,
      'pricing': 'fixed', // string instead of map
      'cancellationPolicy': null,
      'cancelledBy': null,
      'cancellationReason': null,
      'refundReference': null,
    });
    final err = tester.takeException();
    if (err != null) {
      print('CAUGHT ERROR: $err');
      if (err is Error) print('STACK TRACE: ${err.stackTrace}');
    }
    expect(err, isNull);
  });
}

