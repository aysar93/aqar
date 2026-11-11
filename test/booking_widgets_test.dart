import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_pricing_draft.dart';
import 'package:aqar/bookings/booking_widgets.dart';

void main() {
  testWidgets(
      'normal phone calendar keeps seven weekdays and aligns January 2030',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BookingCalendar(
                        month: DateTime(2030, 1),
                        slots: const [],
                        intervalForDay: (day) =>
                            [day, day.add(const Duration(days: 1))],
                        onSelect: (_) {}))))));
    for (final day in [
      'السبت',
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة'
    ]) {
      expect(find.bySemanticsLabel(day), findsOneWidget);
    }
    expect(
        (tester.getCenter(find.text('1')).dx -
                tester.getCenter(find.bySemanticsLabel('الثلاثاء')).dx)
            .abs(),
        lessThan(1));
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 430.0, 900.0])
    testWidgets('RTL venue and calendar support width $width and large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final month = DateTime(2030, 1),
          first = DateTime.utc(2030, 1, 1, 5),
          end = first.add(const Duration(hours: 8));
      final calendar = BookingCalendar(
          month: month,
          slots: [
            {
              'start': first.millisecondsSinceEpoch,
              'end': end.millisecondsSinceEpoch,
              'state': 'confirmed'
            }
          ],
          intervalForDay: (day) {
            final start = DateTime.utc(day.year, day.month, day.day, 5);
            return [start, start.add(const Duration(hours: 8))];
          },
          onSelect: (_) {});
      expect(calendar.state(DateTime(2030, 1, 1)), 'confirmed');
      expect(calendar.state(DateTime(2030, 1, 2)), 'available');
      expect(calendar.state(DateTime(2020, 1, 1)), 'unavailable');
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: Directionality(
                  textDirection: TextDirection.rtl, child: child!)),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Column(children: [
            BookingVenueCard(venue: const {
              'name': 'شاليه عربي طويل للاختبار',
              'category': 'chalet',
              'location': 'الأنبار',
              'price': 100000,
              'deposit': 20000
            }, onTap: () {}),
            Padding(padding: const EdgeInsets.all(16), child: calendar)
          ])))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

  testWidgets('BookingCalendar day cell responds to tap and selects available date', (tester) async {
    DateTime? tappedDay;
    final targetMonth = DateTime(2030, 4);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BookingCalendar(
              month: targetMonth,
              slots: const [],
              intervalForDay: (day) => [day, day.add(const Duration(days: 1))],
              onSelect: (day) => tappedDay = day,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('15'), findsOneWidget);
    await tester.tap(find.text('15'));
    await tester.pump();
    expect(tappedDay, isNotNull);
    expect(tappedDay!.year, 2030);
    expect(tappedDay!.month, 4);
    expect(tappedDay!.day, 15);
  });

  testWidgets('BookingStatusLegend renders canonical 4 statuses with zero duplication', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BookingStatusLegend(),
        ),
      ),
    ));

    expect(find.text('متاح'), findsOneWidget);
    expect(find.text('قيد المراجعة'), findsOneWidget);
    expect(find.text('محجوز'), findsOneWidget);
    expect(find.text('غير متاح'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BookingCalendar showLegend=false does not render status badges internally', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BookingCalendar(
            month: DateTime(2030, 5),
            slots: const [],
            intervalForDay: (day) => [day, day.add(const Duration(days: 1))],
            onSelect: (_) {},
            showLegend: false,
          ),
        ),
      ),
    ));

    expect(find.text('متاح'), findsNothing);
    expect(find.text('قيد المراجعة'), findsNothing);
    expect(find.text('محجوز'), findsNothing);
    expect(find.text('غير متاح'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BookingVenueOverview and safeVenueDeposit handle null, string and mismatched deposit without crash', (tester) async {
    // 1. null deposit with price computes default 50% deposit, and zero deposit yields 0
    expect(BookingPricingDraft.safeVenueDeposit({'price': 100000}), 50000);
    expect(BookingPricingDraft.safeVenueDeposit({'deposit': 0}), 0);

    // 2. string deposit
    expect(BookingPricingDraft.safeVenueDeposit({'deposit': '25000'}), 25000);

    // 3. invalid string deposit
    expect(BookingPricingDraft.safeVenueDeposit({'deposit': 'invalid'}), 0);

    // 4. num deposit
    expect(BookingPricingDraft.safeVenueDeposit({'deposit': 30000}), 30000);

    // 5. Render BookingVenueOverview with null and string deposits safely
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                BookingVenueOverview(
                  venue: const {'name': 'مكان 1', 'price': 50000, 'deposit': '10000'},
                  total: 50000,
                ),
                BookingVenueOverview(
                  venue: const {'name': 'مكان 2', 'price': 80000, 'deposit': null},
                  total: 80000,
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.text('مكان 1'), findsOneWidget);
    expect(find.text('مكان 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
