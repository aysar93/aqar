import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/bookings/booking_operations.dart';
import 'package:aqar/bookings/booking_map.dart';
import 'package:aqar/bookings/booking_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MetadataFixture extends Fake implements SnapshotMetadata {
  MetadataFixture({this.isFromCache = false, this.hasPendingWrites = false});
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

class MediaDocumentFixture extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => 'synthetic-review';
  @override
  Map<String, dynamic> data() =>
      {'venueId': 'PRIVATE-VENUE', 'path': 'synthetic.mp4', 'schemaVersion': 3};
}

class MediaSnapshotFixture extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  MediaSnapshotFixture(
      {bool cached = false, bool pending = false, bool empty = false})
      : metadata =
            MetadataFixture(isFromCache: cached, hasPendingWrites: pending),
        docs = empty ? [] : [MediaDocumentFixture()];
  @override
  final SnapshotMetadata metadata;
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

const fixture = <String, dynamic>{
  'name': 'شاليه ضفاف الفرات',
  'category': 'chalet',
  'location': 'الرمادي · الأنبار',
  'latitude': 33.42,
  'longitude': 43.30,
  'capacity': 12,
  'bedrooms': 3,
  'deposit': 50000,
  'price': 250000,
  'hourlyPrice': 25000,
  'terms': 'احترام مواعيد الدخول والخروج والمحافظة على مرافق المكان.',
  'pricingMode': 'shifts',
  'amenities': ['pool', 'parking'],
  'shifts': [
    {
      'id': 'night',
      'name': 'الفترة المسائية',
      'checkInMinute': 1200,
      'checkOutMinute': 480,
      'price': 300000
    }
  ],
  'cancellationPolicy': {'freeCancellationHours': 24, 'lateRefundPercent': 25},
};
Widget app(Widget child, {double scale = 1}) => MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, body) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: body!),
    home: RepaintBoundary(
        key: const ValueKey('operations-capture'), child: child));

void main() {
  Future<void> mount(WidgetTester tester, Widget child,
      {double scale = 1}) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('SplashTajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await tester.pumpWidget(app(child, scale: scale));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('BOOKING_CAPTURE_UI')) {
      await expectLater(find.byKey(const ValueKey('operations-capture')),
          matchesGoldenFile('operations_captures/$name.png'));
    }
  }

  Future<void> tab(WidgetTester tester, String text) async {
    final f = find.widgetWithText(Tab, text);
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'actual media inbox hides cached and pending private content and revocation, routes verified moderation',
      (tester) async {
    final stream = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    addTearDown(stream.close);
    final calls = <Map<String, dynamic>>[];
    final gate = Completer<void>();
    await tester.pumpWidget(app(BookingMediaInbox(
        reviews: stream.stream,
        call: (name, data) async {
          expect(name, 'reviewBookingExternalMedia');
          calls.add(data);
          await gate.future;
          return {};
        })));
    await tester.pump();
    stream.add(MediaSnapshotFixture(cached: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE-VENUE'), findsNothing);
    stream.add(MediaSnapshotFixture(pending: true));
    await tester.pumpAndSettle();
    expect(find.text('اعتماد وعرض الملف'), findsNothing);
    stream.add(MediaSnapshotFixture());
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE-VENUE'), findsOneWidget);
    await tester.ensureVisible(find.text('اعتماد وعرض الملف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعتماد وعرض الملف'));
    await tester.tap(find.text('رفض الملف'));
    gate.complete();
    await tester.pumpAndSettle();
    expect(calls.single, {'mediaId': 'synthetic-review', 'approved': true});
    stream.addError(StateError('permission revoked'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE-VENUE'), findsNothing);
    expect(find.text('اعتماد وعرض الملف'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'actual media review component renders unavailable media honestly',
      (tester) async {
    await mount(
        tester,
        BookingScaffold(
            appBar: AppBar(title: const Text('مراجعة الوسائط')),
            body: ListView(padding: const EdgeInsets.all(20), children: const [
              BookingMediaReviewCard(
                  venueId: 'SYNTHETIC-VENUE',
                  preview: BookingMediaGallery(paths: []),
                  onReview: null),
            ])));
    await capture(tester, '09-media-review');
    expect(find.text('اعتماد وعرض الملف'), findsOneWidget);
  });

  testWidgets(
      'live venue editor preserves overnight shifts, coordinates and policy across sections and double save',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final calls = <Map<String, dynamic>>[];
    var saved = 0;
    await mount(
        tester,
        BookingVenueEditor(
            ownerMode: true,
            data: fixture,
            call: (name, data) {
              expect(name, 'saveBookingVenue');
              calls.add(data);
              return pending.future;
            },
            onSaved: () => saved++));
    await capture(tester, '01-editor-identity');
    await tester.enterText(
        find.widgetWithText(TextField, 'اسم المكان'), 'شاليه الفرات الجديد');
    await tab(tester, 'الموقع والمرافق');
    await capture(tester, '02-editor-location');
    await tab(tester, 'الأسعار والفترات');
    await tester.ensureVisible(find.text('الفترة المسائية'));
    await capture(tester, '03-editor-pricing');
    await tab(tester, 'الوسائط');
    await capture(tester, '04-editor-media-unsaved');
    expect(find.textContaining('احفظ المكان أولًا'), findsOneWidget);
    await tab(tester, 'المراجعة والحفظ');
    await tester.tap(find.text('حفظ بيانات المكان'));
    await tester.tap(find.text('حفظ بيانات المكان'));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.single['name'], 'شاليه الفرات الجديد');
    expect(calls.single['latitude'], 33.42);
    expect(calls.single['pricingMode'], 'shifts');
    expect(calls.single['shifts'], fixture['shifts']);
    expect(calls.single['cancellationPolicy'], fixture['cancellationPolicy']);
    pending.complete({});
    await tester.pumpAndSettle();
    expect(saved, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'live editor fixed and hourly fields do not lose changes between tabs',
      (tester) async {
    Map<String, dynamic>? payload;
    await mount(
        tester,
        BookingVenueEditor(
            ownerMode: true,
            data: {...fixture, 'pricingMode': 'fixed'},
            call: (n, d) async {
              payload = d;
              return {};
            },
            onSaved: () {}));
    await tab(tester, 'الأسعار والفترات');
    await tester.enterText(
        find.widgetWithText(TextField, 'السعر الثابت لكل حجز بالدينار'),
        '275000');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بالساعة').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(
            TextField, 'سعر الساعة بالدينار (عند اختيار التسعير بالساعة)'),
        '35000');
    await tab(tester, 'المراجعة والحفظ');
    await tester.tap(find.text('حفظ بيانات المكان'));
    await tester.pumpAndSettle();
    expect(payload!['pricingMode'], 'hourly');
    expect(payload!['price'], 275000);
    expect(payload!['hourlyPrice'], 35000);
  });
  testWidgets('support real form retains subject and blocks sending while busy',
      (tester) async {
    final subject = TextEditingController(text: 'طلب متابعة حجز'),
        message =
            TextEditingController(text: 'أحتاج مساعدة في مراجعة حالة الطلب.');
    addTearDown(subject.dispose);
    addTearDown(message.dispose);
    var submits = 0;
    await mount(
        tester,
        BookingScaffold(
            appBar: AppBar(title: const Text('دعم الحجوزات')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingSupportForm(
                  subject: subject,
                  message: message,
                  busy: true,
                  onSubmit: () => submits++),
              const BookingSupportTicket(data: {
                'subject': 'استفسار عن موعد الزيارة',
                'status': 'in_progress',
                'message': 'هل يمكنني تعديل الفترة؟',
                'response': 'نراجع طلبك مع المالك.'
              }),
            ])));
    await capture(tester, '05-support');
    await tester.tap(find.text('جارٍ الإرسال'));
    expect(submits, 0);
    expect(subject.text, 'طلب متابعة حجز');
  });
  testWidgets(
      'staff actual component changes exact scopes and saves, with financial exclusion',
      (tester) async {
    final staff = TextEditingController(text: 'SYNTHETIC-STAFF');
    addTearDown(staff.dispose);
    final scopes = <String>{'calendar'};
    Set<String>? saved;
    await mount(
        tester,
        StatefulBuilder(
            builder: (c, set) => BookingScaffold(
                appBar: AppBar(title: const Text('فريق المكان')),
                body: ListView(padding: const EdgeInsets.all(20), children: [
                  BookingStaffPermissions(
                      controller: staff,
                      scopes: scopes,
                      busy: false,
                      onChanged: (k, v) => set(() {
                            if (v) {
                              scopes.add(k);
                            } else {
                              scopes.remove(k);
                            }
                          }),
                      onSave: () => saved = {...scopes}),
                ]))));
    await tester.tap(find.text('قبول ورفض الطلبات'));
    await tester.pumpAndSettle();
    await capture(tester, '06-staff');
    await tester.tap(find.text('حفظ الصلاحيات'));
    expect(saved, {'calendar', 'bookings'});
  });
  testWidgets(
      'review and report actual cards route independent actions at large Arabic scale',
      (tester) async {
    var opened = 0, resolved = 0, approved = 0;
    await mount(
        tester,
        BookingScaffold(
            appBar: AppBar(title: const Text('مركز المراجعة')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingReviewCard(
                  rating: 5,
                  comment: 'مكان جميل وخدمة منظمة وتجربة تستحق التكرار.',
                  actions: [
                    TextButton(
                        onPressed: () => approved++,
                        child: const Text('نشر التقييم'))
                  ]),
              BookingReportCard(data: const {
                'reason': 'طلب مراجعة اختلاف في موعد الدخول',
                'userName': 'ضيف تجريبي',
                'status': 'open'
              }, onOpen: () => opened++, onResolve: () => resolved++),
            ])),
        scale: 1.25);
    await capture(tester, '07-reviews-reports');
    await tester.tap(find.text('نشر التقييم'));
    await tester.ensureVisible(find.text('فتح الحجز'));
    await tester.tap(find.text('فتح الحجز'));
    await tester.tap(find.text('تحديد كمعالج'));
    expect([approved, opened, resolved], [1, 1, 1]);
  });
  testWidgets(
      'actual map header and markers use synthetic venue with tiles intentionally disabled',
      (tester) async {
    await mount(
        tester,
        BookingMapScreen(
            loadTiles: false,
            venues: Stream.value([
              {...fixture, 'id': 'synthetic-map'}
            ])));
    await capture(tester, '08-map-no-tiles');
    expect(find.text('اكتشف أماكن الأنبار'), findsOneWidget);
  });
  testWidgets(
      'actual map search expands and filters markers while keeping public offline state',
      (tester) async {
    await mount(
        tester,
        BookingMapScreen(
            loadTiles: false,
            venues: Stream.value([
              {...fixture, 'id': 'synthetic-map', '_fromCache': true}
            ])));
    await tester.tap(find.text('تخصيص البحث'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'قاعة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'قاعة'));
    await tester.pumpAndSettle();
    expect(find.text('شاليه ضفاف الفرات'), findsNothing);
    expect(find.text('0 مكانًا يطابق البحث'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'الكل'));
    await tester.pumpAndSettle();
    expect(find.text('شاليه ضفاف الفرات'), findsOneWidget);
    expect(find.textContaining('بيانات محلية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
