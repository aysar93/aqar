import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aqar/bookings/booking_design.dart';
import 'package:aqar/bookings/booking_discovery_design.dart';
import 'package:aqar/bookings/booking_browse_ui.dart';
import 'package:aqar/bookings/booking_page_indicator.dart';
import 'package:aqar/bookings/booking_venue_details.dart';
import 'package:aqar/bookings/booking_workspace.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import '../tool/booking_offline_preview_main.dart';
import '../tool/booking_offline_preview/data.dart';
import '../tool/booking_offline_preview/network_guard.dart';

const output = 'E:/Codex-Booking-Native-20261023-111137/ui-polish-v2/screens';
Widget shell(Widget child, {bool dark = true, double scale = 1}) => MaterialApp(themeAnimationDuration:Duration.zero,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: bookingDesignTheme(dark ? ThemeData.dark() : ThemeData.light()),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: Directionality(textDirection: TextDirection.rtl, child: w!)),
    home: Scaffold(body: child));
Widget surface(GlobalKey key, Widget child) => Builder(
    builder: (c) => RepaintBoundary(
        key: key,
        child: Material(
            color: Theme.of(c).scaffoldBackgroundColor, child: child)));
Future<void> ready(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() async {
    for (final a in ['house', 'farm', 'building'])
      await precacheImage(AssetImage('assets/images/defaults/$a.png'),
          t.element(find.byType(Scaffold).first));
  });
  await t.pump(const Duration(milliseconds: 200));
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  await t.pump();
  final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await b.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(output).createSync(recursive: true);
    File('$output/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

BookingCalendar calendar(DateTime month, ValueChanged<DateTime> onSelect,
    {DateTime? selected}) {
  List<DateTime> range(DateTime d) => [
        DateTime.utc(d.year, d.month, d.day, 6),
        DateTime.utc(d.year, d.month, d.day, 15)
      ];
  return BookingCalendar(
      month: month,
      selectedDay: selected,
      intervalForDay: range,
      onSelect: onSelect,
      slots: [
        for (var i = 0; i < 3; i++)
          {
            'start': DateTime.utc(2027, 1, 5 + i, 6).millisecondsSinceEpoch,
            'end': DateTime.utc(2027, 1, 5 + i, 15).millisecondsSinceEpoch,
            'state': ['pending', 'confirmed', 'unavailable'][i]
          }
      ]);
}

void main() {
  final original = HttpOverrides.current;
  setUpAll(() async {
    HttpOverrides.global = OfflineHttpGuard();
    for (final e in {
      'Cairo': 'assets/fonts/Cairo.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf'
    }.entries) {
      final f = FontLoader(e.key)..addFont(rootBundle.load(e.value));
      await f.load();
    }
  });
  tearDownAll(() => HttpOverrides.global = original);
  testWidgets('featured guard and search batch scope', (t) async {
    final d = PreviewData();
    for (var i = 10; i < 29; i++)
      d.venues
          .add({...d.venues.first, 'id': 'extra-$i', 'name': 'شاليه إضافي $i'});
    await t.pumpWidget(shell(OfflineBookingPreview(data: d).page('home')));
    await ready(t);
    await t.scrollUntilVisible(find.byType(BookingBrowseContent), 300,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    BookingBrowseContent read() =>
        t.widget<BookingBrowseContent>(find.byType(BookingBrowseContent));
    expect(read().featuredVenues.length, 3);
    expect(read().venues.length, 12);
    read().onLoadMore!();
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(read().venues.length, 24);
    expect(read().venues.map((v) => v['id']).toSet().length, 24);
    expect(Firebase.apps, isEmpty);
  });
  testWidgets(
      'compact indicator keyboard all pages no visible arrows or counters',
      (t) async {
    var page = 0;
    await t.pumpWidget(shell(StatefulBuilder(
        builder: (c, set) => BookingPageIndicator(
            count: 10, page: page, onPage: (p) => set(() => page = p)))));
    await t.pump();
    expect(find.byType(IconButton), findsNothing);
    expect(find.text('1/10'), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.end);
    await t.pump();
    expect(page, 9);
    await t.sendKeyEvent(LogicalKeyboardKey.home);
    await t.pump();
    expect(page, 0);
  });
  testWidgets('detail sections selection and independent venue data',
      (t) async {
    final d = PreviewData();
    await t.pumpWidget(shell(
        SingleChildScrollView(child: BookingVenueDetails(venue: d.venues[1]))));
    await ready(t);
    expect(find.text('مسبح'), findsNothing);
    final chip = find.byKey(const ValueKey('booking-section-4'));
    await t.ensureVisible(chip);
    await t.tap(chip);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text(d.venues[1]['terms']), findsOneWidget);
  });
  testWidgets(
      'calendar selected state month and overlapping interval unchanged',
      (t) async {
    var month = DateTime(2027, 1);
    DateTime? selected;
    await t.pumpWidget(shell(
        StatefulBuilder(
            builder: (c, set) => SingleChildScrollView(
                    child: Column(children: [
                  TextButton(
                      onPressed: () => set(() => month = DateTime(2027, 2)),
                      child: const Text('الشهر التالي')),
                  calendar(month, (d) => set(() => selected = d),
                      selected: selected)
                ]))),
        scale: 1.5));
    await t.tap(find.text('8'));
    await t.pump();
    expect(selected, DateTime(2027, 1, 8));
    expect(calendar(month, (_) {}).state(DateTime(2027, 1, 6)), 'confirmed');
    await t.tap(find.text('الشهر التالي'));
    await t.pump();
    expect(find.textContaining('فبراير'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final scale in [1.0, 1.5])
      for (final dark in [true, false])
        testWidgets(
            'polish matrix ${width.toInt()} $scale ${dark ? 'dark' : 'light'}',
            (t) async {
          t.view.physicalSize = Size(width, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final d = PreviewData();
          final pages = <String, Widget>{
            'home': OfflineBookingPreview(data: d).page('home'),
            'details': SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BookingVenueDetails(venue: d.venues.first))),
            'prices': SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: BookingVenuePrices(venue: d.venues.first))),
            'calendar': SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: calendar(DateTime(2027, 1), (_) {},
                        selected: DateTime(2027, 1, 8)))),
            'owner': SingleChildScrollView(
                child: BookingOwnerPanel(bookings: d.bookings, onOpen: (_) {}))
          };
          for (final e in pages.entries) {
            final key = GlobalKey();
            await t.pumpWidget(
                shell(surface(key, e.value), dark: dark, scale: scale));
            await ready(t);
            expect(t.takeException(), isNull,
                reason: '${e.key} width$width scale$scale dark$dark');
            expect(Firebase.apps, isEmpty);
            if (width == 390 && scale == 1 || width == 320 && scale == 1.5)
              await capture(t, key,
                  '${e.key}-${width.toInt()}-${dark ? 'dark' : 'light'}-${scale == 1 ? '100' : '150'}');
            await t.pumpWidget(const SizedBox());
            await t.pump();
          }
        });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    testWidgets('ten card final page and indicators RTL ${width.toInt()}',
        (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final key = GlobalKey(), d = PreviewData();
      await t.pumpWidget(shell(
          surface(
              key,
              SingleChildScrollView(
                  child: BookingVenueRail(venues: d.venues, onOpen: (_) {}))),
          scale: 1.5));
      await ready(t);
      final c = t.widget<PageView>(find.byType(PageView)).controller!;
      await t.drag(find.byType(PageView), const Offset(320, 0));
      await t.pumpAndSettle();
      expect(c.page, greaterThan(0));
      c.jumpToPage(9);
      await t.pumpAndSettle();
      expect(
          t
              .widget<BookingPageIndicator>(find.byType(BookingPageIndicator))
              .page,
          9);
      expect(t.takeException(), isNull);
      if (width == 320) await capture(t, key, 'explore-last-320-dark-150');
    });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final dark in [true, false])
      testWidgets('owner final expanded and scoped ${width.toInt()} $dark',
          (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var managed = 0;
        final d = PreviewData(), key = GlobalKey();
        await t.pumpWidget(shell(
            surface(
                key,
                SingleChildScrollView(
                    child: BookingOwnerPanel(
                        bookings: d.bookings,
                        onOpen: (_) {},
                        onManageVenues: () => managed++))),
            dark: dark,
            scale: 1.5));
        await ready(t);
        if (width == 320 || width == 390)
          await capture(
              t, key, 'owner-${width.toInt()}-${dark ? 'dark' : 'light'}-150');
        await t.tap(find.byType(DropdownButtonFormField<String>));
        await t.pumpAndSettle();
        await t.tap(find.text(d.bookings[3]['venueName']).last);
        await t.pumpAndSettle();
        expect(
            t
                .widget<BookingOwnerOverview>(find.byType(BookingOwnerOverview))
                .bookings
                .length,
            1);
        final money = find.text('ملخص الإيرادات والعربون');
        await t.ensureVisible(money);
        await t.tap(money);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (width == 320)
          await capture(t, key,
              'owner-financial-${width.toInt()}-${dark ? 'dark' : 'light'}-150');
        final button = find.widgetWithText(OutlinedButton, 'أماكني');
        await t.ensureVisible(button);
        await t.tap(button);
        await t.pump();
        expect(managed, 1);
        final unavailable =
            find.widgetWithText(OutlinedButton, 'الإتاحة — غير موصولة');
        expect(t.widget<OutlinedButton>(unavailable).onPressed, isNull);
        expect(t.takeException(), isNull);
        expect(Firebase.apps, isEmpty);
      });
  testWidgets('owner final normal portraits', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final width in [320.0, 360.0, 390.0, 430.0])
      for (final dark in [true, false]) {
        t.view.physicalSize = Size(width, 900);
        final key = GlobalKey();
        await t.pumpWidget(shell(
            surface(
                key,
                SingleChildScrollView(
                    child: BookingOwnerPanel(
                        bookings: PreviewData().bookings,
                        onOpen: (_) {},
                        onManageVenues: () {}))),
            dark: dark));
        await ready(t);
        expect(DefaultTextStyle.of(t.element(find.text('لوحة المالك'))).style.color,Theme.of(t.element(find.text('لوحة المالك'))).colorScheme.onSurface);
        if (width == 390)
          await capture(t, key, 'owner-390-${dark ? 'dark' : 'light'}-100');
        expect(t.takeException(), isNull);
      }
  });
  testWidgets(
      'request original calendar shift back preserves selection locally',
      (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final d = PreviewData(), p = OfflineBookingPreview(data: PreviewData());
    await t.pumpWidget(shell(p.request(d.venues.first['id'], d.venues.first)));
    await ready(t);
    await t.tap(find.byKey(const ValueKey('booking-next')));
    await t.pump();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('الفترة الصباحية').last);
    await t.pumpAndSettle();
    final next = find.byTooltip('الشهر التالي');
    await t.ensureVisible(next);
    await t.pumpAndSettle();
    await t.tap(next);
    await t.pumpAndSettle();
    final day = find.widgetWithText(OutlinedButton, '8');
    await t.ensureVisible(day);
    await t.pumpAndSettle();
    await t.tap(day);
    await t.pump();
    final before =
        t.widget<BookingCalendar>(find.byType(BookingCalendar)).selectedDay;
    expect(before, isNotNull);
    await t.tap(find.byKey(const ValueKey('booking-next')));
    await t.pump();
    expect(find.text('مراجعة الطلب'), findsOneWidget);
    await t.tap(find.byTooltip('الخطوة السابقة'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byType(BookingCalendar), 200,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect(t.widget<BookingCalendar>(find.byType(BookingCalendar)).selectedDay,
        before);
    expect(t.takeException(), isNull);
    expect(Firebase.apps, isEmpty);
    expect(p.data.requests, isEmpty);
  });
  testWidgets('component closeups measured from new Flutter render', (t) async {
    t.view.physicalSize = const Size(390, 1900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final dark in [true, false]) {
      final key = GlobalKey();
      await t.pumpWidget(shell(
          surface(key, OfflineBookingPreview(data: PreviewData()).page('home')),
          dark: dark));
      await ready(t);
      expect(find.byType(BookingVenueRail), findsNWidgets(2));
      final rects = <String, List<double>>{};
      for (final e in {
        'categories': find.byType(BookingCategoryStrip),
        'featured': find.byType(BookingVenueRail).at(0),
        'explore': find.byType(BookingVenueRail).at(1)
      }.entries) {
        final r = t.getRect(e.value);
        rects[e.key] = [r.left, r.top, r.right, r.bottom];
      }
      await t.runAsync(() async {
        File('$output/bounds-${dark ? 'dark' : 'light'}.json')
            .writeAsStringSync(jsonEncode(rects));
      });
      await capture(t, key, 'home-full-390-${dark ? 'dark' : 'light'}-100');
      expect(t.takeException(), isNull);
    }
  });
  testWidgets('single and missing media keep honest counts and no indicator',
      (t) async {
    for (final paths in [
      <String>[],
      ['asset://assets/images/defaults/house.png']
    ]) {
      await t.pumpWidget(shell(
          SingleChildScrollView(child: BookingMediaGallery(paths: paths))));
      await ready(t);
      expect(
          t
              .widget<BookingPageIndicator>(find.byType(BookingPageIndicator))
              .count,
          paths.length);
      expect(
          find.byType(GestureDetector).evaluate().where((e) =>
              e.widget is GestureDetector &&
              (e.widget as GestureDetector).onTapUp != null),
          isEmpty);
      expect(t.takeException(), isNull);
      expect(Firebase.apps, isEmpty);
    }
  });
  testWidgets('featured and explore actual new composition light and dark',
      (t) async {
    t.view.physicalSize = const Size(390, 1900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final d = PreviewData();
    for (final dark in [true, false]) {
      final key = GlobalKey();
      await t.pumpWidget(shell(
          surface(key, OfflineBookingPreview(data: d).page('home')),
          dark: dark));
      await ready(t);
      await capture(t, key, 'home-full-390-${dark ? 'dark' : 'light'}-100');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump();
    }
  });
}
