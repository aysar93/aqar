// High‑priority widget test for BookingReportCard button labels
// Verifies that the card shows "فتح الحجز" for booking‑type reports
// and "فتح المكان" for place‑type reports.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:aqar/bookings/booking_operations.dart';

void main() {
  testWidgets('shows فتح الحجز when bookingId present', (WidgetTester tester) async {
    final data = {
      'bookingId': 'b123',
      'reason': 'اختلاف وصف الشاليه',
      'status': 'open',
      'userName': 'زبون اختبار',
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookingReportCard(
          data: data,
          onOpen: () {},
        ),
      ),
    ));
    expect(find.text('فتح الحجز'), findsOneWidget);
    expect(find.text('فتح المكان'), findsNothing);
  });

  testWidgets('shows فتح المكان when no bookingId', (WidgetTester tester) async {
    final data = {
      'reason': 'اختلاف وصف الشاليه',
      'status': 'open',
      'userName': 'زبون اختبار',
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookingReportCard(
          data: data,
          onOpen: () {},
        ),
      ),
    ));
    expect(find.text('فتح المكان'), findsOneWidget);
    expect(find.text('فتح الحجز'), findsNothing);
  });
}
