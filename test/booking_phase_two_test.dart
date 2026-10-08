import 'package:aqar/bookings/booking_notification.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/subscription/payment_accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'push and internal payloads resolve the same private booking destination',
      () {
    expect(
        bookingNotificationId({'type': 'booking', 'bookingId': 'customer_123'}),
        'customer_123');
    expect(
        bookingNotificationId({
          'data': {'type': 'booking', 'bookingId': 'customer_123'}
        }),
        'customer_123');
    expect(
        bookingNotificationId({'type': 'booking', 'bookingId': 'a/b'}), isNull);
    expect(bookingNotificationId({'type': 'booking', 'bookingId': ''}), isNull);
    expect(
        bookingNotificationId(
            {'type': 'property', 'bookingId': 'customer_123'}),
        isNull);
  });
  test(
      'overnight and full-day shifts use Baghdad irrespective of device timezone',
      () {
    final dates = bookingShiftDates(
        DateTime(2026, 11, 1), {'checkInMinute': 1200, 'checkOutMinute': 480});
    expect(dates.first, DateTime.utc(2026, 11, 1, 17));
    expect(dates.last, DateTime.utc(2026, 11, 2, 5));
    expect(
        bookingShiftDates(DateTime(2026, 11, 1), {
          'checkInMinute': 60,
          'checkOutMinute': 60
        }).last.difference(bookingShiftDates(DateTime(2026, 11, 1),
            {'checkInMinute': 60, 'checkOutMinute': 60}).first),
        const Duration(days: 1));
    expect(bookingMinute('24:00'), isNull);
    expect(bookingMinute('20:00'), 1200);
  });
  testWidgets('shared account asset is available to office subscriptions',
      (tester) async {
    final accounts = await SubscriptionPaymentAccounts.load();
    expect(accounts['qicard']['number'], '7066135323');
    expect(accounts['zaincash']['enabled'], false);
  });
  testWidgets(
      'request shows explicit policy and priced shifts on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: BookingRequestScreen(venueId: 'test', venue: {
      'name': 'مزرعة',
      'ownerName': 'المالك',
      'location': 'بغداد',
      'price': 100000,
      'deposit': 20000,
      'terms': 'شروط',
      'pricingMode': 'shifts',
      'shifts': [
        {
          'id': 'night',
          'name': 'الشفت الليلي',
          'price': 200000,
          'checkInMinute': 1200,
          'checkOutMinute': 480
        }
      ],
      'cancellationPolicy': {
        'freeCancellationHours': 24,
        'lateRefundPercent': 25
      },
    })));
    expect(find.textContaining('استرداد كامل العربون'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('الشفت الليلي').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('السعر المحدد: 200000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
