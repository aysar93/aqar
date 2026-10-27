import 'package:flutter/painting.dart';
import 'dart:async';
import 'package:aqar/bookings/booking_media_image.dart';
import 'package:aqar/bookings/booking_admin_tasks.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/banners/banner_model.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/bookings/booking_browse_ui.dart';
import 'package:aqar/bookings/booking_experience.dart';
import 'package:aqar/bookings/booking_workspace.dart';
import 'booking_services_ui_test.dart' as fixtures;
import 'booking_checkout_experience_test.dart' as checkout;
import 'support/booking_intent_store_fake.dart';

// These inputs live only in tests, never in the application or its backend.
final venues = List.generate(
    10,
    (i) => <String, dynamic>{
          ...checkout.venue,
          'name': i.isEven
              ? 'شاليه اختبار الواجهة ${i + 1}'
              : 'قاعة اختبار الواجهة ${i + 1}',
          'category': i.isEven ? 'chalet' : 'hall',
          'mediaPaths': <String>[]
        });
Widget host(Widget body, {double scale = 1}) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: RepaintBoundary(
        key: const ValueKey('approved-flutter-capture'), child: body));

void main() {
  Future<void> fonts() async {
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  }

  Future<void> mount(WidgetTester t, Widget child,
      {double width = 390, double scale = 1}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 1050);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await fonts();
    await t.pumpWidget(host(child, scale: scale));
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    expect(t.takeException(), isNull);
    const out = String.fromEnvironment('BOOKING_FLUTTER_UI_EVIDENCE');
    if (out.isEmpty) return;
    final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('approved-flutter-capture')));
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$out/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  BookingScreen home() => BookingScreen(
      currentUserId: () => 'fixture-user',
      records: (_) => Stream.value(fixtures.Records(venues)),
      banners: Stream.value([
        BannerModel(
            id: 'fixture-banner',
            title: 'أماكن لمناسبتك في عقارات الأنبار',
            subtitle: 'صورة اصطناعية لاختبار العرض فقط',
            imageUrl: 'local-fixture',
            type: 'chalet',
            targetId: 'fixture-venue',
            isActive: true,
            order: 0)
      ]),
      bannerImageBuilder: (_) =>
          Image.asset('assets/images/defaults/farm.png', fit: BoxFit.cover));
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('approved browse and native RTL rail at $width', (t) async {
      await mount(t, home(), width: width);
      await capture(t, 'home-${width.toInt()}');
      expect(find.text('المميزة'), findsOneWidget);
      expect(find.text('أحدث العروض'), findsNothing);
      expect(find.text('استكشف الأماكن'), findsOneWidget);
      final rail = find.byKey(const ValueKey('استكشف الأماكن'));
      await t.ensureVisible(rail);
      await t.pumpAndSettle();
      final page = find.descendant(of: rail, matching: find.byType(PageView));
      for (var i = 0; i < 9; i++) {
        await t.drag(page, const Offset(310, 0));
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
      await capture(t, 'rail-last-${width.toInt()}');
      final ctrl = t.widget<PageView>(page).controller!;
      expect(ctrl.page!, closeTo(9, 0.01));
    });
  }
  testWidgets('live checkout detail calendar review and keyboard-safe back',
      (t) async {
    await mount(
        t,
        BookingRequestScreen(
            venueId: 'fixture-venue',
            venue: checkout.venue,
            call: checkout.reads,
            intentStore: MemoryIntentStore(),
            currentUserId: () => 'fixture-user'));
    await capture(t, 'venue');
    await t.tap(find.byKey(const ValueKey('booking-next')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('الفترة النهارية').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('الشهر التالي'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('الشهر التالي'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('22'));
    await t.pumpAndSettle();
    await t.tap(find.text('22'));
    await t.pumpAndSettle();
    await capture(t, 'calendar');
    await t.tap(find.byKey(const ValueKey('booking-next')));
    await t.pumpAndSettle();
    await capture(t, 'request');
    await t.ensureVisible(find.byType(TextField));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'ملاحظة اختبار داخل الذاكرة فقط');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('اختيار الموعد'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('booking-next')));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
        'ملاحظة اختبار داخل الذاكرة فقط');
    expect(t.takeException(), isNull);
  });
  testWidgets('role payment owner and admin actual widgets', (t) async {
    final tx = TextEditingController();
    addTearDown(tx.dispose);
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('العربون')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingPaymentPanel(
                  deposit: 50000,
                  accounts: const {
                    'qicard': {'number': '000000 — اصطناعي غير قابل للدفع'}
                  },
                  method: 'qicard',
                  transaction: tx,
                  busy: false,
                  onMethod: (_) {},
                  onSubmit: null)
            ])));
    await capture(t, 'payment');
    await mount(
        t,
        BookingScreen(
            key: UniqueKey(),
            initialTab: 1,
            currentUserId: () => 'fixture-user',
            records: (_) =>
                Stream.value(fixtures.Records([fixtures.booking]))));
    await capture(t, 'my-bookings');
    await mount(
        t,
        BookingScreen(
            key: UniqueKey(),
            initialTab: 2,
            currentUserId: () => 'fixture-user',
            records: (_) =>
                Stream.value(fixtures.Records([fixtures.booking]))));
    await capture(t, 'owner');
    await mount(
        t,
        BookingScreen(
            key: UniqueKey(),
            admin: true,
            currentUserId: () => 'fixture-user',
            records: (_) => Stream.value(fixtures.Records(venues))));
    await capture(t, 'admin');
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('تفاصيل الحجز')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingSummary(
                  booking: fixtures.booking, status: 'الإيصال قيد المراجعة'),
              BookingProgress(status: 'payment_review')
            ])));
    await capture(t, 'booking-details');
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('المراجعة المالية')),
            body: const BookingLedgerContent(entries: [])));
    await capture(t, 'finance-empty');
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('shared surfaces text150 and host light at $width', (t) async {
      await mount(t, home(), width: width, scale: 1.5);
      await capture(t, 'home-${width.toInt()}-text150');
      final frame = t.getRect(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ReferenceBannerCard'));
      final title = t.getRect(find.text('أماكن لمناسبتك في عقارات الأنبار'));
      final tag = t.getRect(find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_BannerTag'));
      expect(title.top, greaterThanOrEqualTo(frame.top + 8));
      expect(title.bottom, lessThanOrEqualTo(frame.bottom - 8));
      expect(title.top, greaterThanOrEqualTo(tag.bottom));
      await mount(
          t,
          BookingScaffold(
              body: ListView(children: [
            BookingCalendar(
                month: DateTime(2030, 1),
                slots: const [],
                intervalForDay: (d) => [d, d.add(const Duration(days: 1))],
                onSelect: (_) {})
          ])),
          width: width,
          scale: 1.5);
      await capture(t, 'calendar-${width.toInt()}-text150');
      await t.pumpWidget(MaterialApp(
          theme: ThemeData.light(),
          home:
              const BookingScaffold(body: Text('الوضع النهاري يتبع التطبيق'))));
      await t.pumpAndSettle();
      expect(
          Theme.of(t.element(find.text('الوضع النهاري يتبع التطبيق')))
              .brightness,
          Brightness.light);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('rail keeps a focused middle indicator across a native page jump',
      (t) async {
    await mount(
        t,
        BookingScaffold(
            body: SingleChildScrollView(
                child: BookingVenueRail(venues: venues, onOpen: (_) {}))));
    final pages = find.byType(PageView);
    final controller = t.widget<PageView>(pages).controller!;
    controller.jumpToPage(4);
    await t.pumpAndSettle();
    controller.jumpToPage(9);
    await t.pumpAndSettle();
    expect(controller.page, closeTo(9, 0.01));
    expect(t.takeException(), isNull);
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('narrow real review with text150 at $width', (t) async {
      await mount(
          t,
          BookingRequestScreen(
              venueId: 'fixture-venue',
              venue: checkout.venue,
              call: checkout.reads,
              intentStore: MemoryIntentStore(),
              currentUserId: () => 'fixture-user'),
          width: width,
          scale: 1.5);
      await t.tap(find.byKey(const ValueKey('booking-next')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('الفترة النهارية').last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byTooltip('الشهر التالي'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('الشهر التالي'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('22'));
      await t.pumpAndSettle();
      await t.tap(find.text('22'));
      await t.pumpAndSettle();
      await capture(t, 'calendar-${width.toInt()}-live-text150');
      await t.tap(find.byKey(const ValueKey('booking-next')));
      await t.pumpAndSettle();
      await capture(t, 'request-${width.toInt()}-text150');
    });
  }

  testWidgets('capture final browse and administration after readability fixes',
      (t) async {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      await mount(t, home(), width: width);
      await capture(t, 'home-${width.toInt()}');
    }
    await mount(
        t,
        BookingScreen(
            key: UniqueKey(),
            admin: true,
            currentUserId: () => 'fixture-user',
            records: (_) => Stream.value(fixtures.Records(venues))));
    await capture(t, 'admin');
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('corrected visual audit at $width', (t) async {
      final tx = TextEditingController();
      addTearDown(tx.dispose);
      Widget payment() => BookingScaffold(
              body: ListView(padding: const EdgeInsets.all(16), children: [
            BookingPaymentPanel(
                deposit: 50000,
                accounts: const {
                  'qicard': {'number': '0000000000000000'}
                },
                method: 'qicard',
                transaction: tx,
                busy: false,
                onMethod: (_) {},
                onSubmit: null)
          ]));
      await mount(t, payment(), width: width, scale: 1.5);
      final number = find.text('0000000000000000').last;
      await t.ensureVisible(number);
      await t.pumpAndSettle();
      final context = t.element(number);
      final scheme = Theme.of(context).colorScheme;
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
      }

      expect(contrast(scheme.onSurface, scheme.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5));
      await capture(t, 'payment-${width.toInt()}-dark150');
      await t.pumpWidget(MaterialApp(
          theme: ThemeData.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: RepaintBoundary(
              key: const ValueKey('approved-flutter-capture'),
              child: MediaQuery(
                  data: MediaQueryData(
                      size: Size(width, 1050),
                      textScaler: const TextScaler.linear(1.5)),
                  child: payment()))));
      await t.pumpAndSettle();
      final light =
          Theme.of(t.element(find.text('بيانات المستلم المعتمدة'))).colorScheme;
      expect(contrast(light.onSurface, light.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5));
      await capture(t, 'payment-${width.toInt()}-light150');
      await mount(
          t,
          BookingScaffold(
              body: ListView(padding: const EdgeInsets.all(16), children: [
            BookingCalendar(
                month: DateTime(2030, 1),
                slots: const [],
                intervalForDay: (d) => [d, d.add(const Duration(days: 1))],
                onSelect: (_) {})
          ])),
          width: width,
          scale: 1.5);
      final thursday = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'الخميس');
      expect(thursday, findsOneWidget);
      final texts = find.descendant(of: thursday, matching: find.byType(Text));
      final day = t.widget<Text>(texts.first);
      expect(day.maxLines, 1);
      expect(day.softWrap, false);
      await capture(t, 'calendar-${width.toInt()}-fixed150');
      await mount(t, home(), width: width, scale: 1.5);
      await capture(t, 'home-${width.toInt()}-fixed150');
      final frame = t.getRect(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ReferenceBannerCard'));
      for (final text in [
        'أماكن لمناسبتك في عقارات الأنبار',
        'صورة اصطناعية لاختبار العرض فقط'
      ]) {
        final rect = t.getRect(find.text(text));
        expect(rect.top, greaterThanOrEqualTo(frame.top + 8));
        expect(rect.bottom, lessThanOrEqualTo(frame.bottom - 8));
      }
      await mount(
          t,
          BookingScaffold(
              body: ListView(children: [
            BookingAdminTasks(records: {
              for (final key in bookingTaskCollections.keys)
                key: Stream.value(fixtures.Records([]))
            }, onOpen: (_) {})
          ])),
          width: width,
          scale: 1.5);
      expect(find.text('لا مهام معلقة'), findsNWidgets(5));
      await capture(t, 'admin-empty-${width.toInt()}-150');
      await mount(
          t, const BookingScaffold(body: BookingLedgerContent(entries: [])),
          width: width, scale: 1.5);
      await capture(t, 'finance-empty-${width.toInt()}-150');
      await mount(
          t,
          BookingRequestScreen(
              venueId: 'fixture-venue',
              venue: checkout.venue,
              call: checkout.reads,
              intentStore: MemoryIntentStore(),
              currentUserId: () => 'fixture-user'),
          width: width,
          scale: 1.5);
      await capture(t, 'venue-${width.toInt()}-150');
      await mount(
          t,
          BookingScreen(
              key: UniqueKey(),
              initialTab: 2,
              currentUserId: () => 'fixture-user',
              records: (_) =>
                  Stream.value(fixtures.Records([fixtures.booking]))),
          width: width,
          scale: 1.5);
      await capture(t, 'owner-${width.toInt()}-150');
    });
  }
  testWidgets('image presentation loading and failure are contained',
      (t) async {
    final pending = Completer<String?>();
    t.view.physicalSize = const Size(320, 1050);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await fonts();
    await t.pumpWidget(host(
        BookingScaffold(
            body: Column(children: [
          SizedBox(
              height: 240,
              child: BookingMediaImage(
                  url: 'https://invalid.test/fixture.png',
                  token: pending.future)),
          const BookingMediaGallery(paths: [])
        ])),
        scale: 1.5));
    await t.pump();
    // A pending image must reserve its viewport without an unbounded indicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await capture(t, 'image-loading-320-150');
    pending.complete(null);
    await t.pumpAndSettle();
    expect(find.text('تعذر تحميل الصورة'), findsOneWidget);
    await capture(t, 'image-error-320-150');
  });

  testWidgets('long banner and populated image stay readable', (t) async {
    final bytes = File('assets/images/defaults/farm.png').readAsBytesSync();
    debugNetworkImageHttpClientProvider = () => _FixtureImageClient(bytes);
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    await HttpOverrides.runZoned(() async {
      t.view.physicalSize = const Size(320, 1050);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await fonts();
      await t.pumpWidget(host(
          BookingScaffold(
              body: ListView(children: [
            SizedBox(
                height: 240,
                child: BookingMediaImage(
                    url: 'https://local.test/success.png',
                    token: Future.value(null)))
          ])),
          scale: 1.5));
      await t.pump();
      await t.runAsync(() async {
        await precacheImage(
            const NetworkImage('https://local.test/success.png'),
            t.element(find.byType(BookingMediaImage)));
      });
      await t.pumpAndSettle();
      expect(find.byType(RawImage), findsOneWidget);
      expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(t.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
      await capture(t, 'image-populated-320-150');
    }, createHttpClient: (_) => _FixtureImageClient(bytes));
    debugNetworkImageHttpClientProvider = null;
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      const title =
          'أماكن واسعة للعائلة والمناسبات في أجمل مناطق محافظة الأنبار';
      const subtitle =
          'اطّلع على صور المكان والمرافق والشروط قبل اختيار موعد الحجز المناسب';
      await mount(
          t,
          BookingScreen(
              currentUserId: () => 'fixture-user',
              records: (_) => Stream.value(fixtures.Records(venues)),
              banners: Stream.value([
                BannerModel(
                    id: 'long',
                    title: title,
                    subtitle: subtitle,
                    imageUrl: 'fixture',
                    type: 'chalet',
                    targetId: 'fixture-venue',
                    isActive: true,
                    order: 0)
              ]),
              bannerImageBuilder: (_) => Image.asset(
                  'assets/images/defaults/farm.png',
                  fit: BoxFit.cover)),
          width: width,
          scale: 1.5);
      final frame = t.getRect(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ReferenceBannerCard'));
      final tag = t.getRect(find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_BannerTag'));
      for (final value in [title, subtitle]) {
        final render = t.renderObject<RenderParagraph>(find.text(value));
        expect(render.didExceedMaxLines, isFalse);
        final rect = t.getRect(find.text(value));
        expect(rect.top, greaterThanOrEqualTo(tag.bottom));
        expect(rect.bottom, lessThanOrEqualTo(frame.bottom));
      }
      await capture(t, 'banner-long-${width.toInt()}-150');
    }
  });
}

// All image bytes are local fixtures: this client never opens a socket.
class _FixtureImageClient implements HttpClient {
  _FixtureImageClient(this.bytes);
  final List<int> bytes;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FixtureImageRequest(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixtureImageRequest implements HttpClientRequest {
  _FixtureImageRequest(this.bytes);
  final List<int> bytes;
  @override
  HttpHeaders get headers => _FixtureHeaders();
  @override
  Future<HttpClientResponse> close() async => _FixtureImageResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixtureHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixtureImageResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FixtureImageResponse(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
