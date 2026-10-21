import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/bookings/booking_experience.dart';

const venue = <String, dynamic>{
  'name': 'شاليه ضفاف الفرات',
  'category': 'chalet',
  'location': 'الرمادي · الأنبار',
  'ownerName': 'مالك تجريبي',
  'capacity': 12,
  'bedrooms': 3,
  'amenities': ['pool', 'parking', 'kitchen'],
  'price': 250000,
  'deposit': 50000,
  'terms': 'احترام وقت الدخول والخروج والمحافظة على مرافق المكان.',
  'pricingMode': 'shifts',
  'shifts': [
    {
      'id': 'day',
      'name': 'الفترة النهارية',
      'price': 250000,
      'checkInMinute': 540,
      'checkOutMinute': 1080
    }
  ],
  'cancellationPolicy': {'freeCancellationHours': 24, 'lateRefundPercent': 25},
};
Future<Map<String, dynamic>> reads(
    String name, Map<String, dynamic> data) async {
  if (name == 'getPublishedBookingReviews')
    return {'count': 0, 'average': 0, 'reviews': []};
  if (name == 'getBookingAvailability') {
    final month =
        DateTime.fromMillisecondsSinceEpoch(data['start'] as int, isUtc: true)
            .add(const Duration(hours: 3));
    return {
      'slots': [
        for (final day in [5, 6, 13])
          {
            'start': DateTime.utc(month.year, month.month, day, 6)
                .millisecondsSinceEpoch,
            'end': DateTime.utc(month.year, month.month, day, 15)
                .millisecondsSinceEpoch,
            'state': day == 13 ? 'pending' : 'confirmed'
          }
      ]
    };
  }
  throw StateError('Unexpected write in rendering fixture: $name');
}

Widget app(Widget body, {double scale = 1}) => MaterialApp(
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: RepaintBoundary(key: const ValueKey('live-capture'), child: body));
void main() {
  Future<void> mount(WidgetTester tester,
      {Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
          call = reads,
      ValueChanged<String>? onRequested,
      double scale = 1,
      String? Function()? currentUserId}) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('SplashTajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await tester.pumpWidget(app(
        BookingRequestScreen(
            venueId: 'synthetic-venue',
            venue: venue,
            call: call,
            onRequested: onRequested,
            currentUserId: currentUserId ?? () => 'synthetic-customer'),
        scale: scale));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('BOOKING_CAPTURE_UI'))
      await expectLater(find.byKey(const ValueKey('live-capture')),
          matchesGoldenFile('live_captures/$name.png'));
  }

  Future<void> dates(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('booking-next')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('الفترة النهارية').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('الشهر التالي'));
    await tester.tap(find.byTooltip('الشهر التالي'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('22'));
    await tester.tap(find.text('22'));
    await tester.pumpAndSettle();
  }

  test('fixed and hourly input uses Baghdad even across UTC date boundaries',
      () {
    expect(
        bookingBaghdadInput(
            DateTime(2030, 2, 1), const TimeOfDay(hour: 1, minute: 30)),
        DateTime.utc(2030, 1, 31, 22, 30));
    expect(bookingBaghdadDate(DateTime.utc(2030, 1, 31, 22)),
        DateTime(2030, 2, 1));
    expect(
        bookingBaghdadInput(
            DateTime(2030, 2, 1), const TimeOfDay(hour: 9, minute: 0)),
        DateTime.utc(2030, 2, 1, 6));
  });
  test(
      'legacy invalid hold deadlines fail closed instead of opening payment or crashing',
      () {
    for (final value in [null, '123', double.infinity, double.nan, 0.5, 1e30]) {
      expect(bookingHoldDeadline(value), isNull);
    }
    final valid = DateTime.utc(2030, 1, 1);
    expect(bookingHoldDeadline(valid.millisecondsSinceEpoch), valid);
  });
  testWidgets(
      'actual request screen renders details, calendar and review without a separate demo UI',
      (tester) async {
    await mount(tester);
    await capture(tester, '01-venue');
    await tester.drag(find.byType(ListView).first, const Offset(0, -470));
    await tester.pumpAndSettle();
    await capture(tester, '02-venue-information');
    await dates(tester);
    await tester
        .ensureVisible(find.byKey(const ValueKey('booking-calendar-section')));
    await tester.pumpAndSettle();
    await capture(tester, '03-calendar');
    await tester.tap(find.byKey(const ValueKey('booking-next')));
    await tester.pumpAndSettle();
    await capture(tester, '04-review');
    expect(find.byType(BookingVenueOverview), findsOneWidget);
  });
  testWidgets(
      'double tap and lost response retry preserve one immutable request intent',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final payloads = <Map<String, dynamic>>[];
    String? destination;
    Future<Map<String, dynamic>> call(
        String name, Map<String, dynamic> data) async {
      if (name != 'requestBooking') return reads(name, data);
      payloads.add(Map.of(data));
      if (payloads.length == 1) return pending.future;
      return {'id': 'synthetic-booking'};
    }

    await mount(tester, call: call, onRequested: (id) => destination = id);
    await dates(tester);
    await tester.tap(find.byKey(const ValueKey('booking-next')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final submit = find.text('إرسال طلب الحجز');
    await tester.tap(submit);
    await tester.tap(submit);
    expect(payloads.length, 1);
    pending
        .completeError(TimeoutException('response lost after server commit'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'الخطوة السابقة'))
            .onPressed,
        isNull);
    await tester.tap(find.text('إعادة المحاولة بنفس الطلب'));
    await tester.pumpAndSettle();
    expect(payloads.length, 2);
    expect(payloads[1], payloads[0]);
    expect(destination, 'synthetic-booking');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'hold timer expires an open view exactly once and disposes safely',
      (tester) async {
    var now = DateTime.utc(2030, 1, 1);
    final end = now.add(const Duration(seconds: 2));
    var expired = 0;
    await tester.pumpWidget(app(BookingScaffold(
        body: BookingHoldNotice(
            until: end, now: () => now, onExpired: () => expired++))));
    await tester.pump();
    expect(expired, 0);
    now = now.add(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(seconds: 1));
    expect(expired, 0);
    expect(find.textContaining('00:00:01'), findsOneWidget);
    now = end;
    await tester.pump(const Duration(seconds: 1));
    expect(expired, 1);
    expect(find.text('انتهت مهلة العربون'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(expired, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'live payment panel preserves recipient selection and busy controls',
      (tester) async {
    final text = TextEditingController();
    addTearDown(text.dispose);
    var method = 'qicard';
    var busy = false;
    var submits = 0;
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    StateSetter? change;
    await tester.pumpWidget(app(BookingScaffold(
        appBar: AppBar(title: const Text('عربون الحجز')),
        body: SingleChildScrollView(
            child: StatefulBuilder(builder: (context, setState) {
          change = setState;
          return Padding(
              padding: const EdgeInsets.all(20),
              child: BookingPaymentPanel(
                  deposit: 50000,
                  accounts: const {
                    'qicard': {'number': 'SYNTHETIC-QI'},
                    'zaincash': {'number': 'SYNTHETIC-ZAIN'}
                  },
                  method: method,
                  transaction: text,
                  busy: busy,
                  onMethod: (v) => setState(() => method = v),
                  onSubmit: () => submits++));
        })))));
    await tester.pumpAndSettle();
    await capture(tester, '05-payment');
    final semantics = tester.ensureSemantics();
    try {
      final recipient = tester
          .getSemantics(find.byType(RadioListTile<String>).first)
          .getSemanticsData();
      expect(recipient.label, contains('Ki / Qi'));
      expect(recipient.label, contains('SYNTHETIC-QI'));
    } finally {
      semantics.dispose();
    }
    await tester.tap(find.text('Zain Cash'));
    await tester.pumpAndSettle();
    expect(method, 'zaincash');
    change!(() => busy = true);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(submits, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('actual checkout remains usable with large Arabic text',
      (tester) async {
    await mount(tester, scale: 2);
    await dates(tester);
    await tester.tap(find.byKey(const ValueKey('booking-next')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('media gallery pages videos without loading or opening them',
      (tester) async {
    await tester.pumpWidget(app(const BookingScaffold(
        body: BookingMediaGallery(paths: ['first.mp4', 'second.mp4']))));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('الوسيط التالي'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('persistent compact deadline hides payment after scrolling',
      (tester) async {
    var now = DateTime.utc(2030, 1, 1);
    final end = now.add(const Duration(seconds: 2));
    var active = true;
    await tester.pumpWidget(app(BookingScaffold(
        body: StatefulBuilder(
            builder: (context, setState) => Column(children: [
                  BookingHoldNotice(
                      compact: true,
                      until: end,
                      now: () => now,
                      onExpired: () => setState(() => active = false)),
                  Expanded(
                      child: ListView(children: [
                    const SizedBox(height: 1400),
                    if (active) const Text('PAYMENT_FORM_VISIBLE')
                  ])),
                ])))));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();
    expect(find.text('PAYMENT_FORM_VISIBLE'), findsOneWidget);
    now = end;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PAYMENT_FORM_VISIBLE'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'account change while request response is pending hides form and prevents old-account navigation',
      (tester) async {
    var uid = 'first-customer';
    final pending = Completer<Map<String, dynamic>>();
    String? destination;
    Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) =>
        name == 'requestBooking' ? pending.future : reads(name, data);
    await mount(tester,
        currentUserId: () => uid,
        call: call,
        onRequested: (id) => destination = id);
    await dates(tester);
    await tester.tap(find.byKey(const ValueKey('booking-next')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرسال طلب الحجز'));
    await tester.pump();
    uid = 'second-customer';
    pending.complete({'id': 'first-customer-private-booking'});
    await tester.pumpAndSettle();
    expect(destination, isNull);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('تغيّر الحساب أثناء الطلب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  Future<void> acceptAndSend(WidgetTester tester) async {
    await dates(tester);
    await tester.tap(find.byKey(const ValueKey('booking-next')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرسال طلب الحجز'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'definitive first rejection unlocks editing without inventing a booking',
      (tester) async {
    Future<Map<String, dynamic>> call(
        String name, Map<String, dynamic> data) async {
      if (name != 'requestBooking') return reads(name, data);
      throw FirebaseFunctionsException(
          code: 'failed-precondition', message: 'price changed');
    }

    await mount(tester, call: call);
    await acceptAndSend(tester);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'الخطوة السابقة'))
            .onPressed,
        isNotNull);
    expect(find.text('إرسال طلب الحجز'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'a rejection after an uncertain attempt cannot silently replace its intent',
      (tester) async {
    final payloads = <Map<String, dynamic>>[];
    Future<Map<String, dynamic>> call(
        String name, Map<String, dynamic> data) async {
      if (name != 'requestBooking') return reads(name, data);
      payloads.add(Map.of(data));
      if (payloads.length == 1) throw TimeoutException('reply lost');
      throw FirebaseFunctionsException(
          code: 'failed-precondition', message: 'date now past');
    }

    await mount(tester, call: call);
    await acceptAndSend(tester);
    await tester.tap(find.text('إعادة المحاولة بنفس الطلب'));
    await tester.pumpAndSettle();
    expect(payloads.length, 2);
    expect(payloads[1], payloads[0]);
    expect(find.text('إعادة المحاولة بنفس الطلب'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'الخطوة السابقة'))
            .onPressed,
        isNull);
    expect(find.text('العودة للتحقق من حجوزاتي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
