import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_owner_calendar_view.dart';

void main() {
  for (final width in [320.0, 360.0, 412.0, 800.0]) {
    testWidgets('BookingOwnerCalendarView renders with 0 overflow on width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testVenues = [
        {'id': 'v1', 'name': 'شاليه النخيل التجريبي', 'location': 'الرمادي'},
        {'id': 'v2', 'name': 'شاليه الفرات الملكي', 'location': 'الفلوجة'},
      ];

      final now = DateTime.now();
      final testBookings = [
        {
          'id': 'b1',
          'venueId': 'v1',
          'status': 'confirmed',
          'pricing': {'mode': 'morning', 'name': 'الفترة الصباحية'},
          'start': DateTime(now.year, now.month, 10, 8).millisecondsSinceEpoch,
          'end': DateTime(now.year, now.month, 10, 15).millisecondsSinceEpoch,
        },
        {
          'id': 'b2',
          'venueId': 'v1',
          'status': 'pending',
          'pricing': {'mode': 'evening', 'name': 'الفترة المسائية'},
          'start': DateTime(now.year, now.month, 10, 16).millisecondsSinceEpoch,
          'end': DateTime(now.year, now.month, 10, 23).millisecondsSinceEpoch,
        },
        {
          'id': 'b3',
          'venueId': 'v1',
          'status': 'confirmed',
          'pricing': {'mode': 'full_day', 'name': 'يوم كامل'},
          'start': DateTime(now.year, now.month, 10, 8).millisecondsSinceEpoch,
          'end': DateTime(now.year, now.month, 10, 23).millisecondsSinceEpoch,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: Scaffold(
            body: BookingOwnerCalendarView(
              ownerId: 'owner_test_1',
              venues: testVenues,
              bookingsStream: const Stream.empty(),
              initialBookingsForTest: testBookings,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(BookingOwnerCalendarView), findsOneWidget);
      expect(find.text('المكان / الأيام'), findsOneWidget);
      expect(find.text('شاليه النخيل التجريبي'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });
  }
}
