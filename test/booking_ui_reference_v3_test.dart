import 'dart:io';
import 'package:aqar/bookings/booking_reference_checkout.dart';
import 'package:aqar/bookings/booking_filters.dart';
import 'package:aqar/bookings/booking_screen.dart';
import '../tool/booking_offline_preview/reference_pricing_preview.dart';
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

const output =
    'E:/Codex-Booking-Native-20261023-111137/ui-reference-v3/screens';
final fullAppKey = GlobalKey();
Widget shell(Widget child, {bool dark = true, double scale = 1}) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: bookingDesignTheme(dark ? ThemeData.dark() : ThemeData.light()),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: RepaintBoundary(key: fullAppKey, child: w!))),
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

Future<void> chooseReferenceReview(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('booking-next')));
  await t.pumpAndSettle();
  await t.tap(find.byType(DropdownButtonFormField<String>));
  await t.pumpAndSettle();
  await t.tap(find.textContaining('الفترة الصباحية').last);
  await t.pumpAndSettle();
  final m = find.byTooltip('الشهر التالي');
  await t.scrollUntilVisible(m,200,scrollable:find.byType(Scrollable).first);
  await t.ensureVisible(m);
  await t.pumpAndSettle();
  await t.tap(m);
  await t.pumpAndSettle();
  final day = find.widgetWithText(OutlinedButton, '8');
  await t.ensureVisible(day);
  await t.pumpAndSettle();
  await t.tap(day);
  await t.pumpAndSettle();
}

Future<void> openReferenceConfirmation(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('booking-next')));
  await t.pumpAndSettle();
  await t.scrollUntilVisible(find.byType(CheckboxListTile), 250,
      scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
  final terms = find.byType(CheckboxListTile).last;
  await t.ensureVisible(terms);
  await t.pumpAndSettle();
  await t.tap(terms);
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('booking-submit-request')));
  await t.pumpAndSettle();
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
  testWidgets('hero search and integrated real filter dialog', (t) async {
    final f = BookingFilters();
    await t.pumpWidget(shell(SingleChildScrollView(
        child: BookingFilterBar(filters: f, onChanged: () {}, welcome: true))));
    await ready(t);
    expect(
        find.descendant(
            of: find.byType(BookingWelcomeSearch),
            matching: find.byType(Image)),
        findsNothing);
    expect(
        find.descendant(
            of: find.byType(BookingWelcomeSearch),
            matching: find.byType(BookingCategoryStrip)),
        findsNothing);
    await t.tap(find.byTooltip('الفلاتر المتقدمة'));
    await t.pumpAndSettle();
    expect(find.text('تصفية النتائج'), findsOneWidget);
    await t.tap(find.text('إلغاء'));
    await t.pumpAndSettle();
    expect(Firebase.apps, isEmpty);
  });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final scale in [1.0, 1.5])
      for (final dark in [true, false])
        testWidgets('reference matrix ${width.toInt()} $scale $dark',
            (t) async {
          t.view.physicalSize = Size(width, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final d = PreviewData(),
              preview = OfflineBookingPreview(data: PreviewData());
          final pages = <String, Widget>{
            'home': OfflineBookingPreview(data: d).page('home'),
            'details': SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BookingVenueDetails(venue: d.venues.first))),
            'current-prices': SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BookingVenuePrices(venue: d.venues.first))),
            'calendar': SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: calendar(DateTime(2027, 1), (_) {},
                        selected: DateTime(2027, 1, 8)))),
            'owner': SingleChildScrollView(
                child: BookingOwnerPanel(bookings: d.bookings, onOpen: (_) {})),
            'reservation': preview.details('preview-booking-1'),
            'confirmation': SingleChildScrollView(
                child: BookingRequestConfirmation(
                    venue: d.venues.first,
                    total: d.venues.first['price'],
                    start: DateTime.utc(2027, 1, 8, 6),
                    end: DateTime.utc(2027, 1, 8, 15),
                    shiftName: 'الفترة الصباحية'))
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
  testWidgets('card image pages outer rail and unknown metadata remain honest',
      (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final d = PreviewData();
    await t.pumpWidget(shell(
        SingleChildScrollView(
            child: BookingVenueRail(venues: d.venues, onOpen: (_) {})),
        scale: 1.5));
    await ready(t);
    final outer = find.byType(PageView).first;
    final c = t.widget<PageView>(outer).controller!;
    c.jumpToPage(9);
    await t.pumpAndSettle();
    expect(c.page, 9);
    expect(t.takeException(), isNull);
    await t.pumpWidget(shell(SingleChildScrollView(
        child: BookingVenueCard(venue: {
      'name': 'مكان بلا بيانات سعر أو وسائط',
      'location': 'عينة محلية',
      'category': 'chalet'
    }, onTap: () {}))));
    await ready(t);
    expect(find.textContaining('السعر غير متوفر'), findsOneWidget);
    expect(find.text('عوائل فقط'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('reference sections prices map amenities terms', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final d = PreviewData(), key = GlobalKey();
    await t.pumpWidget(shell(surface(
        key,
        SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: BookingVenueDetails(venue: d.venues.first))))));
    await ready(t);
    for (final item in [(2, 'location'), (3, 'amenities'), (4, 'terms')]) {
      final button = find.byKey(ValueKey('booking-section-${item.$1}'));
      await t.ensureVisible(button);
      await t.pumpAndSettle();
      await t.tap(button);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await capture(t, key, '${item.$2}-390-dark-100');
    }
    expect(find.text('إحداثيات المكان غير متاحة للاتجاهات.'), findsOneWidget);
  });
  testWidgets('draft two price groups explicit days not live pricing',
      (t) async {
    t.view.physicalSize = const Size(390, 1300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final policy = Map<String, dynamic>.from(jsonDecode(
        File('test/support/booking_pricing_v2_cases.json')
            .readAsStringSync())['policy']);
    final key = GlobalKey();
    await t.pumpWidget(shell(surface(
        key,
        SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: BookingReferencePricingPreview(policy: policy))))));
    await ready(t);
    expect(find.text('أسعار الأيام العادية'), findsOneWidget);
    expect(find.text('أسعار عطلة نهاية الأسبوع'), findsOneWidget);
    expect(find.text('يوم كامل'), findsNWidgets(2));
    await capture(t, key, 'draft-prices-groups-390-dark-100');
    expect(Firebase.apps, isEmpty);
  });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final scale in [1.0, 1.5])
      for (final dark in [true, false])
        testWidgets('reference request route ${width.toInt()} $scale $dark',
            (t) async {
          t.view.physicalSize = Size(width, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final d = PreviewData();
          var requests = 0;
          await t.pumpWidget(shell(
              BookingRequestScreen(
                  venueId: d.venues.first['id'],
                  venue: d.venues.first,
                  currentUserId: () => 'preview-customer',
                  intentStore: d.intents,
                  call: (name, args) async {
                    if (name == 'requestBooking') requests++;
                    return d.call(name, args);
                  },
                  onRequested: (_) {}),
              dark: dark,
              scale: scale));
          await ready(t);
          await chooseReferenceReview(t);
          t
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await t.pumpAndSettle();
          if (width == 390 && scale == 1 || width == 320 && scale == 1.5)
            await capture(t, fullAppKey,
                'options-${width.toInt()}-${dark ? 'dark' : 'light'}-${scale == 1 ? '100' : '150'}');
          await openReferenceConfirmation(t);
          expect(find.byType(BookingRequestConfirmation), findsOneWidget);
          if (width == 390 && scale == 1 || width == 320 && scale == 1.5)
            await capture(t, fullAppKey,
                'confirm-sheet-${width.toInt()}-${dark ? 'dark' : 'light'}-${scale == 1 ? '100' : '150'}');
          final back = find.text('الرجوع للمراجعة');
          await t.ensureVisible(back);
          await t.pumpAndSettle();
          await t.tap(back);
          await t.pumpAndSettle();
          expect(requests, 0);
          expect(d.requests, isEmpty);
          expect(Firebase.apps, isEmpty);
          expect(t.takeException(), isNull);
        });
  for (final changeUid in [false, true])
    testWidgets('confirmation exact once and account guard $changeUid',
        (t) async {
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final d = PreviewData();
      String? uid = 'preview-customer';
      var requests = 0;
      await t.pumpWidget(shell(BookingRequestScreen(
          venueId: d.venues.first['id'],
          venue: d.venues.first,
          currentUserId: () => uid,
          intentStore: d.intents,
          call: (name, args) async {
            if (name == 'requestBooking') requests++;
            return d.call(name, args);
          },
          onRequested: (_) {})));
      await ready(t);
      await chooseReferenceReview(t);
      await openReferenceConfirmation(t);
      if (changeUid) uid = 'preview-other';
      final confirm = find.byKey(const ValueKey('booking-confirm-sheet-send'));
      await t.ensureVisible(confirm);
      await t.pumpAndSettle();
      final action = t.widget<FilledButton>(confirm).onPressed!;
      action();
      action();
      await t.pumpAndSettle();
      expect(requests, changeUid ? 0 : 1);
      expect(d.requests.length, changeUid ? 0 : 1);
      expect(Firebase.apps, isEmpty);
      expect(t.takeException(), isNull);
    });
  testWidgets('video layout metadata preview no playback acceptance',
      (t) async {
    final d = PreviewData(), key = GlobalKey();
    await t.pumpWidget(shell(surface(
        key,
        SingleChildScrollView(
            child: Column(children: [
          const Text('معاينة موضع الفيديو — التشغيل غير مختبر'),
          BookingVenueVideoPreview(
              path: 'preview-not-uploaded.mp4',
              poster: d.venues.first['mediaPaths'][0]),
          BookingAmenityGrid(
              amenities: List<String>.from(d.venues.first['amenities']))
        ])))));
    await ready(t);
    await capture(t, key, 'video-layout-only');
    expect(Firebase.apps, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('reference final composition and component bounds', (t) async {
    t.view.physicalSize = const Size(390, 2100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final dark in [true, false]) {
      final key = GlobalKey();
      await t.pumpWidget(shell(
          surface(key, OfflineBookingPreview(data: PreviewData()).page('home')),
          dark: dark));
      await ready(t);
      final rects = <String, List<double>>{};
      for (final e in {
        'hero': find.byType(BookingWelcomeSearch),
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
      await t.pumpWidget(const SizedBox());
      await t.pump();
    }
  });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    testWidgets('reference five ten cards swipe last ${width.toInt()}',
        (t) async {
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final d = PreviewData();
      for (final count in [5, 10]) {
        final key = GlobalKey();
        await t.pumpWidget(shell(
            surface(
                key,
                SingleChildScrollView(
                    child: BookingVenueRail(
                        venues: d.venues.take(count).toList(),
                        onOpen: (_) {}))),
            scale: 1.5));
        await ready(t);
        final outer = find.byType(PageView).first,
            c = t.widget<PageView>(find.byType(PageView).first).controller!;
        await t.drag(outer, const Offset(280, 0));
        await t.pumpAndSettle();
        expect(c.page, greaterThan(0));
        c.jumpToPage(count - 1);
        await t.pumpAndSettle();
        final indicator = find.byType(BookingPageIndicator).last;
        expect(t.widget<BookingPageIndicator>(indicator).page, count - 1);
        expect(t.widget<BookingPageIndicator>(indicator).count, count);
        expect(t.takeException(), isNull);
        if (width == 320 && count == 10)
          await capture(t, key, 'last-card-320-dark-150');
        await t.pumpWidget(const SizedBox());
        await t.pump();
      }
    });
  testWidgets('reference media reset after filtering and independent gallery',
      (t) async {
    final paths = [
      'asset://assets/images/defaults/house.png',
      'asset://assets/images/defaults/farm.png'
    ];
    await t.pumpWidget(shell(
        BookingCardMedia(paths: paths, name: 'عينة أ', category: 'شاليه')));
    await ready(t);
    final controller = t.widget<PageView>(find.byType(PageView)).controller!;
    controller.jumpToPage(1);
    await t.pumpAndSettle();
    expect(
        t.widget<BookingPageIndicator>(find.byType(BookingPageIndicator)).page,
        1);
    await t.pumpWidget(shell(BookingCardMedia(
        paths: [paths.first], name: 'عينة ب', category: 'قاعة')));
    await ready(t);
    expect(controller.page, 0);
    expect(find.byType(BookingPageIndicator), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'reference description expands from measured lines and resets per venue',
      (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(shell(
        const Padding(
            padding: EdgeInsets.all(20),
            child: BookingVenueDescription(
                text:
                    'وصف عربي لمكان معاينة محلي يحتوي على عدة مرافق وخدمات ومساحات مناسبة للعائلة مع شروط مستقلة لكل مكان وحجز.')),
        scale: 1.5));
    await ready(t);
    expect(find.text('المزيد'), findsOneWidget);
    await t.tap(find.text('المزيد'));
    await t.pumpAndSettle();
    expect(find.text('عرض أقل'), findsOneWidget);
    await t.pumpWidget(shell(
        const Padding(
            padding: EdgeInsets.all(20),
            child: BookingVenueDescription(text: 'وصف قصير.')),
        scale: 1.5));
    await ready(t);
    expect(find.text('عرض أقل'), findsNothing);
    expect(find.text('المزيد'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
