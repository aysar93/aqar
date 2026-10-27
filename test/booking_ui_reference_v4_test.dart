import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aqar/bookings/booking_browse_ui.dart';
import 'package:aqar/bookings/booking_design.dart';
import 'package:aqar/bookings/booking_discovery_design.dart';
import 'package:aqar/bookings/booking_filters.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_venue_details.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../tool/booking_offline_preview/data.dart';
import '../tool/booking_offline_preview/network_guard.dart';
import '../tool/booking_offline_preview_main.dart';

const _output =
    'E:/Codex-Booking-Native-20261023-111137/ui-reference-v4/screens';

const _rootKey = ValueKey('v4-root-boundary');

Widget _app(
  Widget child, {
  required EdgeInsets viewPadding,
  required bool dark,
  double scale = 1,
}) => MaterialApp(
  themeAnimationDuration: Duration.zero,
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: bookingDesignTheme(dark ? ThemeData.dark() : ThemeData.light()),
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      viewPadding: viewPadding,
      padding: viewPadding,
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: Directionality(textDirection: TextDirection.rtl, child: widget!),
  ),
  home: child,
);

Future<void> _ready(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (final asset in ['house', 'farm', 'building', 'apartment']) {
      await precacheImage(
        AssetImage('assets/images/defaults/$asset.png'),
        tester.element(find.byType(Scaffold).first),
      );
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_rootKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_output).createSync(recursive: true);
    File('$_output/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  final original = HttpOverrides.current;
  setUpAll(() async {
    HttpOverrides.global = OfflineHttpGuard();
    for (final e in {
      'Cairo': 'assets/fonts/Cairo.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final f = FontLoader(e.key)..addFont(rootBundle.load(e.value));
      await f.load();
    }
  });
  tearDownAll(() => HttpOverrides.global = original);

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.5]) {
      for (final dark in [true, false]) {
        testWidgets(
          'v4 edge hero ${width.toInt()} ${scale == 1 ? '100' : '150'} ${dark ? 'dark' : 'light'}',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              _app(
                RepaintBoundary(
                  key: _rootKey,
                  child: OfflineBookingPreview(
                    data: PreviewData(),
                  ).page('home'),
                ),
                viewPadding: const EdgeInsets.only(top: 30),
                dark: dark,
                scale: scale,
              ),
            );
            await _ready(tester);
            final hero = tester.getRect(find.byType(BookingWelcomeSearch));
            final search = tester.getRect(
              find.byKey(const ValueKey('booking-search-field')),
            );
            final categories = tester.getRect(
              find.byType(BookingCategoryStrip),
            );
            expect(hero.left, 0);
            expect(hero.right, width);
            expect(hero.top, 0);
            expect(search.top, greaterThanOrEqualTo(30));
            // Search field keeps full readable width even on 320px
            expect(search.width, greaterThanOrEqualTo(width - 44));
            // Sort chip must NEVER appear inside the hero search bar
            expect(
              find.descendant(
                of: find.byType(BookingWelcomeSearch),
                matching: find.text('الأقل سعرًا'),
              ),
              findsNothing,
            );
            expect(
              find.descendant(
                of: find.byType(BookingWelcomeSearch),
                matching: find.byKey(const ValueKey('booking-sort-price')),
              ),
              findsNothing,
            );
            expect(categories.top, greaterThanOrEqualTo(hero.bottom));
            expect(
              tester
                  .widgetList<BookingScaffold>(find.byType(BookingScaffold))
                  .any((scaffold) => scaffold.edgeToEdge),
              isTrue,
            );
            expect(Firebase.apps, isEmpty);
            expect(tester.takeException(), isNull);
            if ((width == 390 && scale == 1) ||
                (width == 320 && scale == 1.5)) {
              await _capture(
                tester,
                'home-${width.toInt()}-${dark ? 'dark' : 'light'}-${scale == 1 ? '100' : '150'}',
              );
            }
          },
        );
      }
    }
  }

  testWidgets('v4 final composition and component bounds', (tester) async {
    tester.view.physicalSize = const Size(390, 2100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [true, false]) {
      await tester.pumpWidget(
        _app(
          RepaintBoundary(
            key: _rootKey,
            child: OfflineBookingPreview(data: PreviewData()).page('home'),
          ),
          viewPadding: const EdgeInsets.only(top: 30),
          dark: dark,
        ),
      );
      await _ready(tester);
      final rects = <String, List<double>>{};
      for (final e in {
        'hero': find.byType(BookingWelcomeSearch),
        'categories': find.byType(BookingCategoryStrip),
        'featuredHeader': find.byKey(
          const ValueKey('booking-section-header-المميزة'),
        ),
        'featured': find.byType(BookingVenueRail).at(0),
        'exploreHeader': find.byKey(
          const ValueKey('booking-section-header-استكشف الأماكن'),
        ),
        'explore': find.byType(BookingVenueRail).at(1),
      }.entries) {
        final r = tester.getRect(e.value);
        rects[e.key] = [r.left, r.top, r.right, r.bottom];
      }
      expect(rects['hero']![1], 0); // V4 Golden Header starts at 0!

      // 1. Section headers display clean title and "عرض الكل" without count pills
      expect(find.byType(BookingSectionHeader), findsNWidgets(2));
      expect(find.text('3 أماكن'), findsNothing);
      expect(find.text('10 أماكن'), findsNothing);
      expect(find.text('عرض الكل'), findsNWidgets(2));

      // 2. Consistent spacing between unified section cards
      final gapBetweenSections =
          rects['exploreHeader']![1] - rects['featured']![3];
      expect(gapBetweenSections, lessThanOrEqualTo(40.0));
      expect(gapBetweenSections, greaterThanOrEqualTo(0.0));

      // 3. Venue card height is compact (< 370px at 390w, reduced from ~495px)
      final featuredRailHeight = rects['featured']![3] - rects['featured']![1];
      final exploreRailHeight = rects['explore']![3] - rects['explore']![1];
      expect(featuredRailHeight, lessThan(370.0));
      expect(exploreRailHeight, closeTo(featuredRailHeight, 1.0));

      // 4. All 4 category items fit within 390px without clipping "قاعة"
      for (final catKey in ['', 'chalet', 'farm', 'hall']) {
        final itemRect = tester.getRect(
          find.byKey(ValueKey('booking-category-$catKey')),
        );
        expect(itemRect.left, greaterThanOrEqualTo(0.0));
        expect(itemRect.right, lessThanOrEqualTo(390.0));
        expect(itemRect.width, closeTo(68.0, 1.0));
      }

      // 5. "مميز" badge appears ONLY when venue['featured'] == true || venue['isFeatured'] == true
      final mediaWidgets = tester
          .widgetList<BookingCardMedia>(find.byType(BookingCardMedia))
          .toList();
      expect(mediaWidgets, isNotEmpty);
      final featuredRailMedia = tester
          .widgetList<BookingCardMedia>(
            find.descendant(
              of: find.byType(BookingVenueRail).at(0),
              matching: find.byType(BookingCardMedia),
            ),
          )
          .toList();
      final exploreRailMedia = tester
          .widgetList<BookingCardMedia>(
            find.descendant(
              of: find.byType(BookingVenueRail).at(1),
              matching: find.byType(BookingCardMedia),
            ),
          )
          .toList();
      expect(featuredRailMedia.every((m) => m.featured), isTrue);
      // PreviewData().venues in explore rail do not have featured:true
      expect(exploreRailMedia.every((m) => !m.featured), isTrue);

      await tester.runAsync(() async {
        File(
          '$_output/bounds-${dark ? 'dark' : 'light'}.json',
        ).writeAsStringSync(jsonEncode(rects));
      });
      await _capture(tester, 'home-full-390-${dark ? 'dark' : 'light'}-100');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  testWidgets(
      'v4 price sort in search bar orders venues ascending and persists across categories',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = PreviewData();
    // Reverse prices so default name sort is NOT ascending by price, and add a price-less venue
    data.venues[0]['price'] = 350000;
    data.venues[0]['shifts'] = [
      {
        'id': 'day',
        'name': 'الفترة الصباحية',
        'price': 350000,
        'checkInMinute': 540,
        'checkOutMinute': 1080
      }
    ];
    data.venues[3]['price'] = 110000;
    data.venues[3]['shifts'] = [
      {
        'id': 'day',
        'name': 'الفترة الصباحية',
        'price': 110000,
        'checkInMinute': 540,
        'checkOutMinute': 1080
      }
    ];
    data.venues.add({
      ...data.venues[0],
      'id': 'preview-venue-no-price',
      'name': 'شاليه بدون سعر',
      'category': 'chalet',
      'pricingMode': 'daily',
      'price': null,
      'shifts': const [],
    });

    await tester.pumpWidget(
      _app(
        OfflineBookingPreview(data: data).page('home'),
        viewPadding: const EdgeInsets.only(top: 30),
        dark: false,
      ),
    );
    await _ready(tester);

    // Open filters dialog and select "الأقل سعرًا"
    await tester.tap(find.byTooltip('تصفية النتائج'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-sort-price')));
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();

    BookingBrowseContent browse() =>
        tester.widget<BookingBrowseContent>(find.byType(BookingBrowseContent));

    final sortedAll = browse().venues;
    final validPrices = sortedAll
        .map(bookingValidStartingPrice)
        .whereType<num>()
        .toList();
    for (var i = 1; i < validPrices.length; i++) {
      expect(validPrices[i], greaterThanOrEqualTo(validPrices[i - 1]));
    }
    // Price-less venue is placed deterministically at the very end
    expect(sortedAll.last['id'], 'preview-venue-no-price');

    // Switch category to "شاليه" and verify sort stays active and ordered ascending
    await tester.tap(find.byKey(const ValueKey('booking-category-chalet')));
    await tester.pumpAndSettle();
    final sortedChalets = browse().venues;
    expect(sortedChalets.first['id'], 'preview-venue-4'); // 110,000 IQD chalet
    expect(sortedChalets.last['id'], 'preview-venue-no-price');
    expect(tester.takeException(), isNull);
  });

  testWidgets('v4 system overlay, minimap, sticky tabs, and V2 pricing flow',
      (tester) async {
    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: _rootKey,
          child: OfflineBookingPreview(data: PreviewData()).page('home'),
        ),
        viewPadding: const EdgeInsets.only(top: 28),
        dark: false,
      ),
    );
    await _ready(tester);
    final heroOverlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(BookingWelcomeSearch),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(heroOverlay.value.statusBarIconBrightness, Brightness.dark);
    expect(heroOverlay.value.statusBarColor, Colors.transparent);
    final baseVenue = Map<String, dynamic>.from(PreviewData().venues.first);
    await tester.pumpWidget(_app(
        Scaffold(
            bottomNavigationBar: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                    key: const ValueKey('booking-next'),
                    onPressed: () {},
                    child: const Text('احجز الآن'))),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: BookingVenueDetails(venue: baseVenue))),
        viewPadding: const EdgeInsets.only(top: 28),
        dark: true));
    await _ready(tester);
    expect(find.byKey(const ValueKey('booking-venue-minimap')), findsNothing);
    expect(
        find.text('إحداثيات المكان غير متاحة للاتجاهات.'), findsOneWidget);
    final initialBarTop =
        tester.getRect(find.byKey(const ValueKey('booking-section-0'))).top;
    await tester.ensureVisible(find.byKey(const ValueKey('booking-section-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-section-4')));
    await tester.pumpAndSettle();
    final stickyRect =
        tester.getRect(find.byKey(const ValueKey('booking-section-4')));
    final bookRect =
        tester.getRect(find.byKey(const ValueKey('booking-next')));
    expect(stickyRect.top, lessThan(120));
    expect(stickyRect.bottom, lessThan(bookRect.top));
    await tester.tap(find.byKey(const ValueKey('booking-section-0')));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(
        tester.getRect(find.byKey(const ValueKey('booking-section-0'))).top,
        closeTo(initialBarTop, 1.0));
    await tester.pumpWidget(_app(
        Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: BookingVenueDetails(venue: {
                  ...baseVenue,
                  'latitude': 33.4258,
                  'longitude': 43.2992,
                  'pricing': {
                    'version': 2,
                    'timeZone': 'Asia/Baghdad',
                    'deposit': 30000,
                    'weekendDays': [4, 5],
                    'shifts': [
                      {
                        'kind': 'morning',
                        'enabled': true,
                        'startMinute': 540,
                        'endMinute': 1080,
                        'endDayOffset': 0,
                        'weekdayPrice': 100000,
                        'weekendPrice': 140000,
                      },
                      {
                        'kind': 'evening',
                        'enabled': true,
                        'startMinute': 1140,
                        'endMinute': 120,
                        'endDayOffset': 1,
                        'weekdayPrice': 125000,
                        'weekendPrice': 165000,
                      },
                      {
                        'kind': 'full_day',
                        'enabled': false,
                        'startMinute': 540,
                        'endMinute': 540,
                        'endDayOffset': 1,
                        'weekdayPrice': 200000,
                        'weekendPrice': 250000,
                      },
                    ],
                  },
                }))),
        viewPadding: const EdgeInsets.only(top: 28),
        dark: true));
    await _ready(tester);
    expect(
        find.byKey(const ValueKey('booking-venue-minimap')), findsOneWidget);
    expect(find.text('33.4258, 43.2992'), findsOneWidget);
    expect(find.text('التوجه إلى موقع المكان'), findsOneWidget);
    expect(find.textContaining('(اليوم التالي)'), findsOneWidget);
    expect(find.textContaining('الخميس، الجمعة'), findsOneWidget);
    expect(Firebase.apps, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
