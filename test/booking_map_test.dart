import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aqar/bookings/booking_map.dart';
import 'package:aqar/bookings/booking_location.dart';

class FakeLocation extends BookingLocationService {
  int calls = 0;
  BookingLocationFailure? failure;
  @override
  Future<LatLng> locate() async {
    calls++;
    if (failure != null) throw failure!;
    return const LatLng(33.4, 43.3);
  }
}

const venue = <String, dynamic>{
  'id': 'test',
  'name': 'مزرعة اختبار',
  'category': 'farm',
  'location': 'الأنبار',
  'latitude': 33.41,
  'longitude': 43.3,
  'price': 100000,
  'terms': 'شروط اختبار'
};
void main() {
  for (final failure in [
    null,
    const BookingLocationFailure('الإذن مرفوض'),
    const BookingLocationFailure('GPS معطل', locationSettings: true),
    const BookingLocationFailure('مهلة الموقع')
  ]) {
    testWidgets('map remains usable with location result ${failure?.message}',
        (tester) async {
      final gps = FakeLocation()..failure = failure;
      await tester.pumpWidget(MaterialApp(
          home: BookingMapScreen(
              locationService: gps,
              loadTiles: false,
              venues: Stream.value([
                venue,
                {
                  ...venue,
                  'id': 'invalid',
                  'name': 'غير صالح',
                  'latitude': double.nan
                }
              ]))));
      await tester.pumpAndSettle();
      expect(gps.calls, 0);
      expect(find.textContaining('غير صالح'), findsNothing);
      await tester.tap(find.text('موقعي الحالي'));
      await tester.pumpAndSettle();
      expect(gps.calls, 1);
      if (failure != null)
        expect(find.text(failure.message), findsOneWidget);
      else {
        expect(find.textContaining('الأماكن القريبة ضمن'), findsOneWidget);
        await tester.tap(find.text('إخفاء موقعي'));
        await tester.pumpAndSettle();
        expect(find.textContaining('الأماكن القريبة ضمن'), findsNothing);
      }
      await tester.tap(find.text('مزرعة اختبار'));
      await tester.pumpAndSettle();
      expect(find.text('الاتجاهات'), findsOneWidget);
      expect(find.text('التفاصيل والحجز'), findsOneWidget);
      expect(find.text('شروط اختبار'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('شروط اختبار'))),
          TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'long venue name keeps the complete price visible at scale $scale',
        (tester) async {
      const longName = 'مزرعة عربية ذات اسم طويل جدًا لاختبار عرض السعر';
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: BookingMapScreen(
              loadTiles: false,
              venues: Stream.value([
                {...venue, 'name': longName}
              ]))));
      await tester.pumpAndSettle();
      final price = find.text('100000 د.ع');
      expect(price, findsOneWidget);
      final markerButton =
          find.ancestor(of: price, matching: find.byType(TextButton)).first;
      final bounds = tester.getRect(markerButton);
      expect(bounds.contains(tester.getTopLeft(price) + const Offset(.1, .1)),
          isTrue);
      expect(
          bounds.contains(tester.getBottomRight(price) - const Offset(.1, .1)),
          isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('compact landscape with large Arabic text remains scrollable',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home:
            BookingMapScreen(loadTiles: false, venues: Stream.value([venue]))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('offline stream error preserves map and location action',
      (tester) async {
    final stream = StreamController<List<Map<String, dynamic>>>();
    await tester.pumpWidget(MaterialApp(
        home: BookingMapScreen(loadTiles: false, venues: stream.stream)));
    stream.add([
      {...venue, '_fromCache': true}
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('بيانات محلية'), findsOneWidget);
    stream.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر تحديث الأماكن'), findsOneWidget);
    expect(find.text('مزرعة اختبار'), findsOneWidget);
    expect(find.text('موقعي الحالي'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    unawaited(stream.close());
    await tester.pumpAndSettle();
  });
}
