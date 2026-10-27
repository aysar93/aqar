import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import '../tool/booking_offline_preview_main.dart';
import '../tool/booking_offline_preview/data.dart';
import '../tool/booking_offline_preview/network_guard.dart';

void main() {
 testWidgets('preview text scale reaches actual booking route', (t) async {
   final app=OfflineBookingPreview(); await t.pumpWidget(app);await t.pumpAndSettle();
   await t.tap(find.text('الدخول إلى المعاينة'));await t.pumpAndSettle();
   app.previewScale.value=1.5;await t.pumpAndSettle();
   expect(MediaQuery.textScalerOf(t.element(find.text('مكان يليق بك'))).scale(10),15);
   expect(t.takeException(),isNull);
 });
 test('fixture live streams support reattachment after route rebuild', () async {
   final d=PreviewData(); final records=d.records(0); final document=d.watch('preview-booking-2');
   expect((await records.first).docs.length,10);expect((await records.first).docs.length,10);
   expect((await document.first).id,'preview-booking-2');expect((await document.first).id,'preview-booking-2');
 });
 testWidgets('admin lazy scrolling reattaches local streams', (t) async {
  t.view.physicalSize = const Size(360,800); t.view.devicePixelRatio=1;
  addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: OfflineBookingPreview().page('admin')));
  await t.pumpAndSettle();
  await t.drag(find.byType(ListView).first, const Offset(0,-1500));await t.pumpAndSettle();
  await t.drag(find.byType(ListView).first, const Offset(0,1500));await t.pumpAndSettle();
  expect(t.takeException(),isNull);
 });
  test('local fixture streams permit later route listeners', () async {
    final stream = localValue(42);
    expect(await stream.first, 42);
    expect(await stream.first, 42);
  });
  testWidgets('price preview supplies Material to its real field', (t) async {
    await t.pumpWidget(MaterialApp(home: PricesPreview(data: PreviewData(), onSaved: () {})));
    await t.pump();
    expect(t.takeException(), isNull);
    await t.enterText(find.byType(TextField), '175000');
    await t.tap(find.text('حفظ داخل الذاكرة'));
    await t.pump();
    expect(t.takeException(), isNull);
  });
  test('fixture identities and request idempotency stay local', () async {
    final d = PreviewData();
    expect(d.venues.length, 10);
    expect(d.bookings.map((b) => b['status']).toSet().length, 8);
    expect(d.venues[0]['amenities'], contains('pool'));
    expect(d.venues[1]['amenities'], isNot(contains('pool')));
    final p = {
      'requestId': '123',
      'venueId': d.venues.first['id'],
      'price': 150000,
      'start': 1,
      'end': 2
    };
    final a = await d.call('requestBooking', p),
        b = await d.call('requestBooking', p);
    expect(a, b);
    expect(d.bookings.length, 9);
    expect(Firebase.apps, isEmpty);
  });
  test('Dart network guard refuses clients without opening sockets', () {
    HttpOverrides.runZoned(() => expect(() => HttpClient(), throwsStateError),
        createHttpClient: OfflineHttpGuard().createHttpClient);
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('all existing preview pages text150 at $width', (t) async {
      t.view.physicalSize = Size(width, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final app = OfflineBookingPreview();
      for (final route in [
        'home',
        'bookings',
        'owner',
        'admin',
        'finance',
        'payment',
        'review',
        'chat',
        'support',
        'notifications',
        'images',
        'empty',
        'offline',
        'denied',
        'prices'
      ]) {
        await t.pumpWidget(MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData.dark(),
            builder: (c, w) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: w!),
            home: app.page(route)));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull, reason: 'route=$route width=$width');
        expect(Firebase.apps, isEmpty);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      }
    });
  }
  testWidgets(
      'direct entry and real venue navigation do not initialize Firebase',
      (t) async {
    t.view.physicalSize = const Size(430, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(OfflineBookingPreview());
    await t.pumpAndSettle();
    await t.tap(find.text('الدخول إلى المعاينة'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byType(BookingVenueCard).first, 250,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect(find.text('استكشف الأماكن'), findsOneWidget);
    await t.ensureVisible(find.byType(BookingVenueCard).first);
    await t.tap(find.text('شاليه المعاينة 1').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('booking-next')));
    await t.pumpAndSettle();
    expect(find.text('اختيار الموعد'), findsOneWidget);
    expect(Firebase.apps, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'picker stays accessible outside the route semantics and opens real routes',
      (t) async {
    final semantics = t.ensureSemantics();

    t.view.physicalSize = const Size(430, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(OfflineBookingPreview());
    await t.pumpAndSettle();
    await t.tap(find.text('الدخول إلى المعاينة'));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('شاشات المعاينة'), findsOneWidget);
    await t.tap(find.text('شاشات المعاينة'));
    await t.pumpAndSettle();
    expect(find.text('دفع العربون'), findsOneWidget);
    await t.tap(find.text('حجوزاتي').last);
    await t.pumpAndSettle();
    expect(find.text('حجوزاتي'), findsWidgets);
    expect(t.takeException(), isNull);
    semantics.dispose();
  });
}

