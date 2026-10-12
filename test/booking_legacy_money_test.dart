import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_widgets.dart';

void main() {
  testWidgets('known zero payment remains an explicit zero amount',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BookingSummary(booking: {
      'venueName': 'Current synthetic',
      'total': 100001,
      'deposit': 1001,
      'paid': 0,
      'remaining': 100001,
    }, status: 'حجز مؤقت')))));
    expect(find.text('0 د.ع'), findsOneWidget);
    expect(find.text('غير متوفر'), findsNothing);
  });
  testWidgets(
      'legacy missing money is unavailable, never a null amount or zero',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BookingSummary(booking: {
      'venueName': 'Legacy synthetic',
      'total': 100001,
      'deposit': 1001,
      'paid': null,
    }, status: 'ملغي')))));
    expect(find.text('100001 د.ع'), findsOneWidget);
    expect(find.text('1001 د.ع'), findsOneWidget);
    expect(find.text('غير متوفر'), findsNWidgets(2));
    expect(find.text('null د.ع'), findsNothing);
    expect(find.text('0 د.ع'), findsNothing);
  });
}
