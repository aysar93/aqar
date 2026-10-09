import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_widgets.dart';

void main() {
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
}
