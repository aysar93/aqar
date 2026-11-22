import 'package:aqar/bookings/booking_discovery_design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_filters.dart';
import 'package:aqar/bookings/booking_pricing_draft.dart';
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

  test(
      'price sort orders valid prices ascending across modes and puts missing prices at end',
      () {
    final v2Policy = {
      'version': 2,
      'timeZone': 'Asia/Baghdad',
      'deposit': 25000,
      'weekendDays': [4, 5],
      'shifts': [
        {
          'kind': 'morning',
          'enabled': true,
          'startMinute': 540,
          'endMinute': 1080,
          'endDayOffset': 0,
          'weekdayPrice': 85000,
          'weekendPrice': 115000,
        },
        {
          'kind': 'evening',
          'enabled': true,
          'startMinute': 1140,
          'endMinute': 120,
          'endDayOffset': 1,
          'weekdayPrice': 110000,
          'weekendPrice': 140000,
        },
        {
          'kind': 'full_day',
          'enabled': false,
          'startMinute': 540,
          'endMinute': 540,
          'endDayOffset': 1,
          'weekdayPrice': 180000,
          'weekendPrice': 220000,
        },
      ],
    };
    final items = <Map<String, dynamic>>[
      {'id': 'missing-1', 'name': 'بدون سعر ب'},
      {'id': 'fixed-200', 'name': 'قاعة أ', 'price': 200000},
      {'id': 'zero-price', 'name': 'بدون سعر أ', 'price': 0},
      {
        'id': 'shifts-120',
        'name': 'شاليه ب',
        'pricingMode': 'shifts',
        'shifts': [
          {'id': 's1', 'name': 'صباحي', 'price': 150000},
          {'id': 's2', 'name': 'مسائي', 'price': 120000},
        ],
      },
      {'id': 'v2-85', 'name': 'شاليه V2', 'pricing': v2Policy},
      {
        'id': 'hourly-35',
        'name': 'مزرعة بالساعة',
        'pricingMode': 'hourly',
        'hourlyPrice': 35000,
      },
    ];
    expect(bookingValidStartingPrice(items[0]), isNull);
    expect(bookingValidStartingPrice(items[2]), isNull);
    expect(bookingValidStartingPrice(items[4]), 85000);

    final f = BookingFilters()..sort = 'price';
    items.sort(f.compare);
    expect(
      items.map((e) => e['id']).toList(),
      ['hourly-35', 'v2-85', 'shifts-120', 'fixed-200', 'zero-price', 'missing-1'],
    );

    // Overnight quote & weekday/weekend parity check on BookingPricingDraft
    final draft = BookingPricingDraft.fromVenue({'pricing': v2Policy})!;
    // 2026-10-29 is Thursday (weekend day 4 in Baghdad)
    final thuStart = DateTime.utc(2026, 10, 29, 19, 0); // 22:00 Baghdad (1140m = 19:00? Wait: 1140m = 19:00 local = 16:00 UTC)
    final thuEveningStart = DateTime.utc(2026, 10, 29, 16, 0); // 19:00 Baghdad
    final friMorningEnd = DateTime.utc(2026, 10, 29, 23, 0); // 02:00 Next Day Baghdad (120m + 1440 - 1140 = 420m = 7h)
    final weekendQuote = draft.quote('evening', thuEveningStart, friMorningEnd);
    expect(weekendQuote['total'], 140000);
    expect(weekendQuote['deposit'], 25000);
    expect(weekendQuote['remaining'], 115000);
    expect((weekendQuote['pricing'] as Map)['dayGroup'], 'weekend');
    expect((weekendQuote['pricing'] as Map)['endDayOffset'], 1);
  });

  testWidgets('BookingFilterBar in welcome mode has NO sort chip below search bar', (tester) async {
    final filters = BookingFilters();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookingFilterBar(
          filters: filters,
          welcome: true,
          onChanged: () {},
        ),
      ),
    ));
    await tester.pump();
    expect(find.descendant(of: find.byType(BookingWelcomeSearch), matching: find.text('الأقل سعرًا')), findsNothing);
    expect(find.descendant(of: find.byType(BookingWelcomeSearch), matching: find.byKey(const ValueKey('booking-sort-price'))), findsNothing);
  });
}
