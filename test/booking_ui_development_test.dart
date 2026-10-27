import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aqar/bookings/booking_design.dart';
import 'package:aqar/widgets/banner_slider.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/bookings/booking_filters.dart';
import 'package:aqar/bookings/booking_discovery_design.dart';
import 'package:aqar/bookings/booking_browse_ui.dart';
import 'package:aqar/bookings/booking_page_indicator.dart';
import 'package:aqar/bookings/booking_venue_details.dart';
import 'package:aqar/bookings/booking_owner_metrics.dart';
import 'package:aqar/bookings/booking_workspace.dart';
import 'package:aqar/bookings/booking_pricing_draft.dart';
import '../tool/booking_offline_preview_main.dart';
import '../tool/booking_offline_preview/data.dart';
import '../tool/booking_offline_preview/network_guard.dart';
import '../tool/booking_offline_preview/pricing_editor.dart';

const output =
    'E:/Codex-Booking-Native-20261023-111137/ui-polish-v2/regression-renders';
Widget shell(Widget child,
        {bool dark = true, double scale = 1.5}) =>
    MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: bookingDesignTheme(dark ? ThemeData.dark() : ThemeData.light()),
        builder: (c, w) => MediaQuery(
            data:
                MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: Directionality(textDirection: TextDirection.rtl, child: w!)),
        home: Scaffold(body: child));
Widget surface(GlobalKey key, Widget child) => Builder(
    builder: (context) => RepaintBoundary(
        key: key,
        child: Material(
            color: Theme.of(context).scaffoldBackgroundColor, child: child)));
Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(output)..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  final original = HttpOverrides.current;
  setUpAll(() async {
    HttpOverrides.global = OfflineHttpGuard();
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  tearDownAll(() {
    HttpOverrides.global = original;
  });
  test('draft quote parity, snapshots, bad matrix and day id isolation', () {
    final fixture = jsonDecode(
        File('test/support/booking_pricing_v2_cases.json')
            .readAsStringSync()) as Map;
    final draft =
        BookingPricingDraft(Map<String, dynamic>.from(fixture['policy']));
    for (final c in fixture['cases']) {
      final quote = draft.quote(
          c['kind'], DateTime.parse(c['start']), DateTime.parse(c['end']));
      expect(quote['total'], c['total']);
      expect(quote['remaining'], c['total'] - 20000);
    }
    final p =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(fixture['policy'])));
    p['shifts'][0]['weekdayPrice'] = -1;
    expect(() => BookingPricingDraft(p), throwsFormatException);
    final q = draft.quote('morning', DateTime.parse('2026-10-29T06:00:00Z'),
        DateTime.parse('2026-10-29T15:00:00Z'));
    draft.data['shifts'][0]['weekdayPrice'] = 180000;
    expect(q['total'], 100000);
    draft.data['shifts'][2]['enabled'] = false;
    expect(
        () => draft.quote('full_day', DateTime.parse('2026-10-30T06:00:00Z'),
            DateTime.parse('2026-10-31T06:00:00Z')),
        throwsFormatException);
    expect(bookingClock12(0), '12:00 ص');
    expect(bookingClock12(720), '12:00 م');
    expect(bookingClock12(1140), '7:00 م');
  });
  test('owner metrics never count pending money or infer unknown paid', () {
    final m = bookingOwnerMetrics([
      {'status': 'payment_review', 'paid': 999, 'total': 1000},
      {
        'status': 'confirmed',
        'paid': 200,
        'remaining': 800,
        'total': 1000,
        'start': 2000
      }
    ], now: DateTime.fromMillisecondsSinceEpoch(0));
    expect(m['paid'], 200);
    expect(m['expected'], 2000);
    expect(m['remaining'], 800);
    expect(m['upcoming'], 1);
    expect(
        bookingOwnerMetrics([
          {'status': 'completed', 'total': 1000}
        ])['paid'],
        null);
  });
  testWidgets(
      'welcome contains search but not categories; category keeps filter identity',
      (t) async {
    final f = BookingFilters();
    await t.pumpWidget(shell(SingleChildScrollView(
        child: BookingFilterBar(filters: f, welcome: true, onChanged: () {}))));
    await t.pump();
    final hero = find.byType(BookingWelcomeSearch);
    expect(find.descendant(of: hero, matching: find.byType(TextField)),
        findsOneWidget);
    expect(
        find.descendant(of: hero, matching: find.byType(BookingCategoryStrip)),
        findsNothing);
    await t.tap(find.byKey(const ValueKey('booking-category-hall')));
    expect(f.category, 'hall');
    expect(
        f.matches(
            {'name': 'قاعة', 'location': 'الأنبار', 'category': 'chalet'}),
        false);
    expect(Firebase.apps, isEmpty);
  });
  testWidgets('bounded window loads more and does not duplicate venue ids',
      (t) async {
    final d = PreviewData();
    for (var i = 10; i < 29; i++)
      d.venues.add({
        ...d.venues.first,
        'id': 'local-extra-$i',
        'name': 'شاليه إضافي $i'
      });
    await t.pumpWidget(
        shell(OfflineBookingPreview(data: d).page('home'), scale: 1));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.scrollUntilVisible(find.byType(BookingBrowseContent), 300,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    BookingBrowseContent read() =>
        t.widget<BookingBrowseContent>(find.byType(BookingBrowseContent));
    expect(read().venues.length, 12);
    expect(read().hasMore, true);
    read().onLoadMore!();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(read().venues.length, 24);
    read().onLoadMore!();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(read().venues.length, 29);
    expect(read().hasMore, false);
    expect(read().venues.map((v) => v['id']).toSet().length, 29);
    expect(Firebase.apps, isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
  testWidgets('compact indicator reaches final page without ellipsis',
      (t) async {
    var selected = 0;
    final key = GlobalKey();
    await t.pumpWidget(shell(
        StatefulBuilder(
            builder: (c, set) => SizedBox(
                key: key,
                child: BookingPageIndicator(
                    count: 10,
                    page: selected,
                    onPage: (v) => set(() => selected = v)))),
        scale: 1));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.end);
    await t.pump();
    expect(selected, 9);
    expect(find.byType(IconButton), findsNothing);
    expect(find.text('…'), findsNothing);
  });
  testWidgets('details anchors use the selected venue data', (t) async {
    final v = PreviewData().venues[1];
    await t.pumpWidget(shell(
        SingleChildScrollView(child: BookingVenueDetails(venue: v)),
        scale: 1));
    await t.pump();
    expect(find.text(v['name']), findsOneWidget);
    expect(find.text('مسبح'), findsNothing);
    await t.ensureVisible(find.byKey(const ValueKey('booking-section-1')));
    await t.tap(find.byKey(const ValueKey('booking-section-1')));
    await t.pumpAndSettle();
    expect(find.text('التعرفة الحالية المعتمدة'), findsOneWidget);
    expect(Firebase.apps, isEmpty);
  });

  testWidgets(
      'active category and search survive loading another bounded batch',
      (t) async {
    final d = PreviewData();
    for (var i = 10; i < 29; i++)
      d.venues.add({
        ...d.venues.first,
        'id': 'filter-extra-$i',
        'name': 'شاليه إضافي $i'
      });
    await t.pumpWidget(
        shell(OfflineBookingPreview(data: d).page('home'), scale: 1));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('booking-category-chalet')));
    await t.pump();
    await t.enterText(
        find.byKey(const ValueKey('booking-search-field')), 'إضافي');
    await t.pump();
    await t.scrollUntilVisible(find.byType(BookingBrowseContent), 300,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    BookingBrowseContent read() =>
        t.widget<BookingBrowseContent>(find.byType(BookingBrowseContent));
    expect(read().venues, isNotEmpty);
    expect(
        read().venues.every(
            (v) => v['category'] == 'chalet' && v['name'].contains('إضافي')),
        true);
    read().onLoadMore!();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(
        read().venues.every(
            (v) => v['category'] == 'chalet' && v['name'].contains('إضافي')),
        true);
    expect(
        read().venues.map((v) => v['id']).toSet().length, read().venues.length);
    expect(Firebase.apps, isEmpty);
  });
  testWidgets('banner and gallery keep independent RTL page destinations',
      (t) async {
    final preview = OfflineBookingPreview(data: PreviewData());
    String? opened;
    await t.pumpWidget(shell(
        SingleChildScrollView(
            child: BannerSlider(
                stream: localValue(preview.banners),
                onBookingVenue: (id, _) async {
                  opened = id;
                },
                imageBuilder: (_) =>
                    const ColoredBox(color: Color(0xFF182338)))),
        scale: 1));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(
        t.widget<BookingPageIndicator>(find.byType(BookingPageIndicator)).page,
        0);
    await t.drag(find.byType(PageView), const Offset(600, 0));
    await t.pumpAndSettle();
    expect(
        t.widget<BookingPageIndicator>(find.byType(BookingPageIndicator)).page,
        1);
    await t.tap(find.byType(PageView));
    await t.pump();
    expect(opened, preview.banners[1].targetId);
    expect(Firebase.apps, isEmpty);
    await t.pumpWidget(shell(
        const SingleChildScrollView(
            child: BookingMediaGallery(paths: [
          'asset://assets/images/defaults/house.png',
          'asset://assets/images/defaults/farm.png'
        ])),
        scale: 1));
    await t.pump();
    expect(
        t.widget<BookingPageIndicator>(find.byType(BookingPageIndicator)).page,
        0);
    await t.drag(find.byType(PageView), const Offset(600, 0));
    await t.pumpAndSettle();
    expect(
        t.widget<BookingPageIndicator>(find.byType(BookingPageIndicator)).page,
        1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
  testWidgets('owner venue report and financial expansion stay scoped',
      (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final d = PreviewData(), key = GlobalKey();
    await t.pumpWidget(shell(surface(
        key,
        SingleChildScrollView(
            child: BookingOwnerPanel(bookings: d.bookings, onOpen: (_) {})))));
    await t.pump();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text(d.bookings[3]['venueName']).last);
    await t.pumpAndSettle();
    final overview =
        t.widget<BookingOwnerOverview>(find.byType(BookingOwnerOverview));
    expect(overview.bookings.length, 1);
    expect(overview.bookings.single['venueId'], d.bookings[3]['venueId']);
    final tile = find.text('ملخص الإيرادات والعربون');
    await t.ensureVisible(tile);
    await t.tap(tile);
    await t.pumpAndSettle();
    final paid = find.text('العربون المعتمد المسجّل — قبل الاسترداد');
    await t.ensureVisible(paid);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await capture(t, key, 'owner-financial-320-dark-150');
    expect(Firebase.apps, isEmpty);
  });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    testWidgets('rail sync final of ten RTL ${width.toInt()}', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final data = PreviewData(), key = GlobalKey();
      await t.pumpWidget(shell(
          surface(
              key,
              SingleChildScrollView(
                  child:
                      BookingVenueRail(venues: data.venues, onOpen: (_) {}))),
          scale: 1.5));
      await t.pump();
      await t.runAsync(() async {
        await precacheImage(
            const AssetImage('assets/images/defaults/house.png'),
            t.element(find.byType(BookingVenueRail)));
      });
      await t.pumpAndSettle();
      final pages = find.byType(PageView);
      final controller = t.widget<PageView>(pages).controller!;
      expect(controller.page, 0);
      await t.drag(pages, const Offset(300, 0));
      await t.pumpAndSettle();
      expect(controller.page, greaterThan(0));
      controller.jumpToPage(9);
      await t.pumpAndSettle();
      expect(
          t
              .widget<BookingPageIndicator>(find.byType(BookingPageIndicator))
              .page,
          9);
      expect(t.takeException(), isNull);
      if (width == 320 || width == 390)
        await capture(t, key, 'explore-last-${width.toInt()}-dark-150');
    });
  testWidgets('pricing section and local draft validation are reachable',
      (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await t.pumpWidget(shell(surface(
        key,
        SingleChildScrollView(
            child: BookingVenuePrices(venue: PreviewData().venues.first)))));
    await t.pump();
    await capture(t, key, 'prices-390-dark-150');
    expect(t.takeException(), isNull);
    await t.pumpWidget(shell(
        const SingleChildScrollView(child: BookingDraftPricingEditor()),
        scale: 1));
    await t.pump();
    final save = find.text('التحقق من المسودة محليًا');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pump();
    expect(find.textContaining('صالحة'), findsWidgets);
    expect(Firebase.apps, isEmpty);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final dark in [true, false])
      testWidgets(
          'calendar legend contrast and intervals ${width.toInt()} ${dark ? 'dark' : 'light'}',
          (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final month = DateTime(2027, 1), key = GlobalKey();
        DateTime? chosen;
        List<DateTime> interval(DateTime d) => [
              DateTime.utc(d.year, d.month, d.day, 6),
              DateTime.utc(d.year, d.month, d.day, 15)
            ];
        final slots = [
          for (var i = 0; i < 3; i++)
            {
              'start': DateTime.utc(2027, 1, 5 + i, 6).millisecondsSinceEpoch,
              'end': DateTime.utc(2027, 1, 5 + i, 15).millisecondsSinceEpoch,
              'state': ['pending', 'confirmed', 'unavailable'][i]
            }
        ];
        final calendar = BookingCalendar(
            month: month,
            slots: slots,
            intervalForDay: interval,
            onSelect: (d) => chosen = d);
        expect(calendar.state(DateTime(2027, 1, 5)), 'pending');
        expect(calendar.state(DateTime(2027, 1, 6)), 'confirmed');
        expect(calendar.state(DateTime(2027, 1, 7)), 'unavailable');
        expect(calendar.state(DateTime(2027, 1, 8)), 'available');
        await t.pumpWidget(shell(
            surface(
                key,
                SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(16), child: calendar))),
            dark: dark));
        await t.pump();
        await t.tap(find.text('8'));
        await t.pump();
        expect(chosen, DateTime(2027, 1, 8));
        expect(t.takeException(), isNull);
        if (width == 320 || width == 390)
          await capture(t, key,
              'calendar-${width.toInt()}-${dark ? 'dark' : 'light'}-150');
      });
  testWidgets('home normal scale and loaded sections render', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await t.pumpWidget(shell(
        surface(key, OfflineBookingPreview(data: PreviewData()).page('home')),
        scale: 1));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await capture(t, key, 'home-390-dark-normal');
    await t.scrollUntilVisible(find.byType(BookingBrowseContent), 300,
        scrollable: find.byType(Scrollable).first);
    await t.pump();
    await capture(t, key, 'home-sections-390-dark-normal');
    expect(t.takeException(), isNull);
  });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final dark in [true, false])
      testWidgets(
          'new layouts text150 ${width.toInt()} ${dark ? 'dark' : 'light'}',
          (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final data = PreviewData();
        final pages = <String, Widget>{
          'home': OfflineBookingPreview(data: data).page('home'),
          'details': SingleChildScrollView(
              child: BookingVenueDetails(venue: data.venues.first)),
          'owner': SingleChildScrollView(
              child:
                  BookingOwnerPanel(bookings: data.bookings, onOpen: (_) {})),
          'pricing-draft':
              const SingleChildScrollView(child: BookingDraftPricingEditor())
        };
        for (final e in pages.entries) {
          final key = GlobalKey();
          await t.pumpWidget(shell(surface(key, e.value), dark: dark));
          await t.pump();
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull,
              reason: '${e.key} width$width dark$dark');
          expect(Firebase.apps, isEmpty);
          if (width == 390 || width == 320)
            await capture(t, key,
                '${e.key}-${width.toInt()}-${dark ? 'dark' : 'light'}-150');
          await t.pumpWidget(const SizedBox());
          await t.pump();
        }
      });
}
