import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_filters.dart';
import 'package:flutter/material.dart';

void main() {
  for (final apply in [true, false]) {
    testWidgets('focused filter dialog closes safely, apply=$apply',
        (tester) async {
      final filters = BookingFilters();
      var changes = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: BookingFilterBar(filters: filters, onChanged: () => changes++),
      )));
      await tester.tap(find.text('السعر والسعة والمرافق'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '120000');
      await tester.enterText(find.byType(TextField).at(2), '10');
      await tester.enterText(find.byType(TextField).at(3), '3');
      await tester.tap(find.text('مسبح'));
      await tester.tap(find.text(apply ? 'تطبيق' : 'إلغاء'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      expect(changes, apply ? 1 : 0);
      expect(filters.maxPrice, apply ? 120000 : null);
      expect(filters.capacity, apply ? 10 : null);
      expect(filters.bedrooms, apply ? 3 : null);
      expect(filters.amenities.contains('pool'), apply);
    });
  }
  test('Arabic search, old records, price modes and combined filters', () {
    final f = BookingFilters()..search = 'انبار';
    final v = <String, dynamic>{'name': 'شاليه الأَنْبَار', 'price': 100000};
    expect(f.matches(v), isTrue);
    f.capacity = 6;
    expect(f.matches(v), isFalse);
    v.addAll({
      'capacity': 8,
      'bedrooms': 2,
      'amenities': ['pool', 'parking'],
      'pricingMode': 'shifts',
      'shifts': [
        {'price': 90000},
        {'price': 120000}
      ]
    });
    f
      ..maxPrice = 100000
      ..bedrooms = 2;
    f.amenities.add('pool');
    expect(f.matches(v), isTrue);
    f.amenities.add('wifi');
    expect(f.matches(v), isFalse);
    expect(
        bookingStartingPrice({
          'price': 100001,
          'offer': {
            'percent': 10,
            'until': DateTime.now().millisecondsSinceEpoch + 60000
          }
        }),
        90000);
    expect(
        bookingStartingPrice(
            {'pricingMode': 'hourly', 'hourlyPrice': 25000, 'price': 50000}),
        25000);
  });
}
