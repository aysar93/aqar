import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_services_ui.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/bookings/booking_management.dart';
import 'package:aqar/bookings/booking_extras.dart';
import 'package:aqar/bookings/booking_experience.dart';

class Meta extends Fake implements SnapshotMetadata {
  Meta({this.isFromCache = false, this.hasPendingWrites = false});
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

class Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  Doc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class Records extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  Records(List<Map<String, dynamic>> values,
      {bool cached = false, bool pending = false})
      : metadata = Meta(isFromCache: cached, hasPendingWrites: pending),
        docs = [
          for (var i = 0; i < values.length; i++) Doc('synthetic-$i', values[i])
        ];
  @override
  final SnapshotMetadata metadata;
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class Document extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  Document(this.value, {bool cached = false})
      : metadata = Meta(isFromCache: cached);
  final Map<String, dynamic> value;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic> data() => value;
}

const venue = {
  'name': 'شاليه ضفاف الفرات',
  'category': 'chalet',
  'location': 'الرمادي · الأنبار',
  'capacity': 12,
  'bedrooms': 3,
  'price': 250000,
  'deposit': 50000,
  'terms': 'احترام أوقات الدخول والخروج',
  'amenities': ['pool', 'parking']
};
const booking = {
  'venueName': 'شاليه ضفاف الفرات',
  'customerName': 'ضيف تجريبي',
  'status': 'confirmed',
  'start': 1795327200000,
  'end': 1795359600000,
  'total': 250000,
  'deposit': 50000
};
const transfer = {
  'venueId': 'SYNTHETIC-VENUE',
  'ownerId': 'SYNTHETIC-OWNER',
  'newOwnerId': 'SYNTHETIC-NEW-OWNER',
  'reason': 'نقل الملكية وفق طلب الطرفين',
  'status': 'pending_admin'
};
Widget app(Widget child, {double scale = 1}) => MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (c, body) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: body!),
    home:
        RepaintBoundary(key: const ValueKey('services-capture'), child: child));
void main() {
  Future<void> mount(WidgetTester t, Widget child, {double scale = 1}) async {
    t.view.physicalSize = const Size(430, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await (FontLoader('SplashTajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await t.pumpWidget(app(child, scale: scale));
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    expect(t.takeException(), isNull);
    if (const bool.fromEnvironment('BOOKING_CAPTURE_UI'))
      await expectLater(find.byKey(const ValueKey('services-capture')),
          matchesGoldenFile('services_captures/$name.png'));
  }

  testWidgets(
      'actual details cannot issue concurrent QR codes or retain a credential after account switch',
      (t) async {
    String? uid = 'synthetic-customer';
    final sessions = StreamController<String?>.broadcast();
    addTearDown(sessions.close);
    final result = Completer<Map<String, dynamic>>();
    var issued = 0;
    await mount(
        t,
        BookingDetailsScreen(
            bookingId: 'synthetic',
            currentUserId: () => uid,
            sessions: sessions.stream,
            roles: (_) => Stream.value(Document({'isBlocked': false})),
            paymentAccounts: Stream.value({}),
            events: Stream.value(Records([])),
            dataStream: Stream.value(Document({
              ...booking,
              'customerId': uid,
              'ownerId': 'synthetic-owner',
              'paid': 50000,
              'remaining': 200000
            })),
            call: (name, data) {
              expect(name, 'issueBookingCheckInCode');
              issued++;
              return result.future;
            }));
    await t.scrollUntilVisible(find.text('رمز الوصول — صالح 10 دقائق'), 300,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('رمز الوصول — صالح 10 دقائق'));
    await t.tap(find.text('رمز الوصول — صالح 10 دقائق'));
    await t.pump();
    expect(issued, 1);
    result.complete({
      'code': 'aqar-booking:synthetic:${List.filled(64, '0').join()}',
      'expiresAt':
          DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch
    });
    await t.pumpAndSettle();
    expect(find.text('نسخ الرمز نصيًا'), findsOneWidget);
    uid = 'other';
    sessions.add(uid);
    await t.pumpAndSettle();
    expect(find.text('نسخ الرمز نصيًا'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('capture actual incoming ownership transfer and empty state',
      (t) async {
    await mount(
        t,
        BookingTransferInbox(
            transfers: Stream.value(Records([
          {...transfer, 'status': 'pending_acceptance'}
        ]))));
    await capture(t, '24-transfer-new-owner');
    await mount(t, BookingTransferInbox(transfers: Stream.value(Records([]))));
    await capture(t, '25-transfer-empty');
  });

  testWidgets(
      'capture actual details for customer owner and finance without bypassing live role checks',
      (t) async {
    final fixed = {
      ...booking,
      'customerId': 'synthetic-customer',
      'ownerId': 'synthetic-owner',
      'customerPhone': 'SYNTHETIC-PHONE',
      'ownerName': 'مالك تجريبي',
      'venueLocation': 'الرمادي · الأنبار',
      'paid': 50000,
      'remaining': 200000,
      'cancellationPolicy': {
        'freeCancellationHours': 24,
        'lateRefundPercent': 25
      }
    };
    for (final role in ['customer', 'owner', 'finance']) {
      final uid = 'synthetic-$role';
      await mount(
          t,
          BookingDetailsScreen(
              key: ValueKey(role),
              bookingId: 'synthetic',
              currentUserId: () => uid,
              sessions: Stream.value(uid),
              roles: (_) => Stream.value(Document({
                    'isBlocked': false,
                    'canReviewBookingPayments': role == 'finance'
                  })),
              paymentAccounts: Stream.value({}),
              events: Stream.value(Records([])),
              dataStream: Stream.value(Document({
                ...fixed,
                'status': role == 'finance' ? 'completed' : 'confirmed'
              }))));
      await capture(t, '21-details-$role');
      if (role == 'finance') {
        await t.scrollUntilVisible(find.text('تسوية مستحقات المالك'), 400,
            scrollable: find.byType(Scrollable).first);
        await t.pumpAndSettle();
        await capture(t, '22-finance-settlement');
      }
    }
  });
  testWidgets('QR pass hides immediately when its issuing account changes',
      (t) async {
    final sessions = StreamController<String?>.broadcast();
    addTearDown(sessions.close);
    String? uid = 'customer';
    await mount(
        t,
        BookingScaffold(
            body: SingleChildScrollView(
                child: BookingQrPass(
                    code:
                        'aqar-booking:SYNTHETIC:${List.filled(64, '0').join()}',
                    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
                    sessions: sessions.stream,
                    currentUserId: () => uid,
                    issuedUid: 'customer'))));
    expect(find.text('نسخ الرمز نصيًا'), findsOneWidget);
    uid = 'other';
    sessions.add(uid);
    await t.pumpAndSettle();
    expect(find.text('نسخ الرمز نصيًا'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'manual refund component preserves the exact reference and busy blocks recording',
      (t) async {
    final ref = TextEditingController(text: 'SYNTHETIC-REFUND');
    addTearDown(ref.dispose);
    var writes = 0;
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('استرداد العربون')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingManualSettlement(
                  title: 'إعادة العربون المستحق',
                  bookingId: 'synthetic',
                  action: 'settleRefund',
                  loadPreview: () async => {
                        'bookingId': 'synthetic',
                        'action': 'settleRefund',
                        'amount': 50000,
                        'currency': 'IQD',
                        'version': 1,
                        'beneficiary': {'id': 'synthetic-customer'},
                        'reason': 'cancelled_booking_refund'
                      },
                  reference: ref,
                  busy: true,
                  label: 'تسجيل إعادة المبلغ يدوياً',
                  onSubmit: () => writes++)
            ])));
    await capture(t, '23-refund-recording');
    await t.tap(find.text('تسجيل إعادة المبلغ يدوياً'));
    expect(writes, 0);
    expect(ref.text, 'SYNTHETIC-REFUND');
  });

  testWidgets(
      'real settings loads values, rejects invalid duration and routes reviewer toggle without changing deadlines',
      (t) async {
    var saves = 0;
    final calls = <Map<String, dynamic>>[];
    await mount(
        t,
        BookingSettingsScreen(
            loadSettings: () async => {'holdMinutes': 120},
            loadUsers: () async => [
                  {
                    'id': 'synthetic-reviewer',
                    'name': 'مراجع تجريبي',
                    'canReviewBookingPayments': true
                  }
                ],
            saveSettings: (value) async {
              saves++;
            },
            call: (name, data) async {
              expect(name, 'setBookingPaymentReviewer');
              calls.add(data);
              return {};
            }));
    await capture(t, '01-settings');
    expect(saves, 0);
    await t.enterText(find.widgetWithText(TextField, 'المدة بالدقائق'), '4');
    await t.tap(find.text('حفظ الإعدادات'));
    await t.pumpAndSettle();
    expect(saves, 0);
    await t.drag(find.byType(ListView), const Offset(0, -400));
    await t.pumpAndSettle();
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(calls.single, {'userId': 'synthetic-reviewer', 'enabled': false});
  });
  testWidgets(
      'settings error cannot save defaults and late completion after dispose is safe',
      (t) async {
    await mount(
        t,
        BookingSettingsScreen(
            loadSettings: () async => throw StateError('offline'),
            loadUsers: () async => []));
    expect(find.text('الإعدادات غير متاحة'), findsOneWidget);
    expect(find.text('حفظ الإعدادات'), findsNothing);
    await capture(t, '02-settings-offline');
    final pending = Completer<Map<String, dynamic>>();
    await t.pumpWidget(app(BookingSettingsScreen(
        key: UniqueKey(),
        loadSettings: () => pending.future,
        loadUsers: () async => [])));
    await t.pumpWidget(const SizedBox());
    pending.complete({'holdMinutes': 120});
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'live chat retries exact message after lost response and rejects double send',
      (t) async {
    final sessions = StreamController<String?>.broadcast();
    addTearDown(sessions.close);
    final pending = Completer<Map<String, dynamic>>();
    final calls = <Map<String, dynamic>>[];
    await mount(
        t,
        BookingChatScreen(
            bookingId: 'synthetic-booking',
            sessions: sessions.stream,
            currentUserId: () => 'customer',
            messages: (_) => Stream.value(Records([
                  {
                    'senderId': 'owner',
                    'message': 'أهلًا بك، نتطلع لاستقبالكم في الموعد المحدد.'
                  },
                  {
                    'senderId': 'customer',
                    'message': 'شكرًا لكم، سنصل في الموعد المتفق عليه.'
                  }
                ])),
            call: (name, data) {
              expect(name, 'sendBookingMessage');
              calls.add(data);
              return calls.length == 1 ? pending.future : Future.value({});
            }));
    await capture(t, '03-chat');
    await t.enterText(find.byType(TextField), 'رسالة جديدة');
    await t.tap(find.text('إرسال الرسالة'));
    await t.tap(find.text('إرسال الرسالة'));
    await t.pump();
    expect(calls, hasLength(1));
    pending.completeError(FirebaseFunctionsException(
        code: 'unavailable', message: 'تعذر تأكيد الإرسال'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(find.byType(TextField)).enabled, false);
    await capture(t, '04-chat-retry');
    await t.tap(find.text('إعادة إرسال الرسالة نفسها'));
    await t.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(calls[0], calls[1]);
    expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });
  testWidgets(
      'live chat hides cached private messages and clears old account intent during pending reply',
      (t) async {
    String? uid = 'first';
    final sessions = StreamController<String?>.broadcast(),
        first = StreamController<QuerySnapshot<Map<String, dynamic>>>(),
        second = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    addTearDown(sessions.close);
    addTearDown(first.close);
    addTearDown(second.close);
    final response = Completer<Map<String, dynamic>>();
    await t.pumpWidget(app(BookingChatScreen(
        bookingId: 'synthetic',
        sessions: sessions.stream,
        currentUserId: () => uid,
        messages: (u) => u == 'first' ? first.stream : second.stream,
        call: (n, d) => response.future)));
    first.add(Records([
      {'message': 'PRIVATE-FIRST', 'senderId': 'first'}
    ], cached: true));
    await t.pumpAndSettle();
    expect(find.text('PRIVATE-FIRST'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    first.add(Records([
      {'message': 'PRIVATE-FIRST', 'senderId': 'first'}
    ]));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'PRIVATE-DRAFT');
    await t.tap(find.text('إرسال الرسالة'));
    await t.pump();
    uid = 'second';
    sessions.add(uid);
    await t.pump();
    second.add(Records([]));
    await t.pumpAndSettle();
    response.complete({});
    await t.pumpAndSettle();
    expect(find.text('PRIVATE-FIRST'), findsNothing);
    expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    second.addError(StateError('revoked'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'real transfer card enforces stage and does not issue two actions',
      (t) async {
    final pending = Completer<void>();
    final actions = <String>[];
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('نقل الملكية')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingTransferCard(
                  data: transfer,
                  admin: true,
                  onAction: (action) {
                    actions.add(action);
                    return pending.future;
                  })
            ])));
    await capture(t, '05-transfer-admin');
    await t.tap(find.text('اعتماد النقل'));
    await t.tap(find.text('اعتماد النقل'));
    await t.pump();
    expect(actions, ['approve']);
    pending.complete();
    await t.pumpAndSettle();
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('نقل الملكية')),
            body: ListView(children: [
              BookingTransferCard(
                  data: {...transfer, 'status': 'pending_acceptance'},
                  admin: true,
                  onAction: (a) async {
                    actions.add(a);
                  })
            ])));
    expect(find.text('اعتماد النقل'), findsNothing);
  });
  testWidgets(
      'QR pass hides credential at server expiry and invalid expiry fails closed',
      (t) async {
    var now = DateTime.utc(2026, 10, 21, 12);
    final expiry = now.add(const Duration(minutes: 10));
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('رمز الوصول')),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: BookingQrPass(
                    code:
                        'aqar-booking:SYNTHETIC:${List.filled(64, '0').join()}',
                    expiresAt: expiry,
                    now: () => now))));
    await capture(t, '06-qr-pass');
    now = expiry;
    await t.pump(const Duration(seconds: 1));
    expect(find.text('انتهت صلاحية رمز الوصول'), findsOneWidget);
    expect(find.text('نسخ الرمز نصيًا'), findsNothing);
    await capture(t, '07-qr-expired');
    await t.pumpWidget(app(const BookingScaffold(
        body: BookingQrPass(code: 'invalid', expiresAt: null))));
    await t.pump();
    expect(find.text('انتهت صلاحية رمز الوصول'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'scanner real layout exposes camera failure and retry at large text',
      (t) async {
    var retries = 0;
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('مسح رمز الوصول')),
            body: BookingScannerPanel(
                busy: false,
                camera: const ColoredBox(
                    color: bookingNavy,
                    child: Center(
                        child: Text('تعذر فتح الكاميرا',
                            style: TextStyle(color: Colors.white)))),
                error: 'تحقق من إذن الكاميرا ثم أعد المحاولة.',
                onRetry: () => retries++)),
        scale: 1.3);
    await capture(t, '08-scanner-camera-error');
    await t.tap(find.text('إعادة المسح'));
    expect(retries, 1);
  });
  testWidgets(
      'capture real home, admin and private queue routes with synthetic verified snapshots',
      (t) async {
    for (final entry in {
      0: '09-home',
      1: '10-my-bookings',
      3: '11-admin-reports',
      4: '12-finance-queue',
      5: '13-owner-venues',
      6: '14-staff-venues'
    }.entries) {
      final data = entry.key == 0 || entry.key == 5
          ? venue
          : entry.key == 3
              ? {
                  'bookingId': 'synthetic',
                  'userName': 'ضيف تجريبي',
                  'reason': 'مراجعة وقت الدخول',
                  'status': 'resolved'
                }
              : entry.key == 6
                  ? {
                      'venueId': 'synthetic-venue',
                      'scopes': ['calendar']
                    }
                  : booking;
      await mount(
          t,
          BookingScreen(
              key: ValueKey(entry.key),
              admin: [3, 4].contains(entry.key),
              initialTab: entry.key,
              currentUserId: () => 'synthetic-user',
              records: (_) => Stream.value(Records([data]))));
      await capture(t, entry.value);
    }
    await mount(
        t,
        BookingScreen(
            key: UniqueKey(),
            admin: true,
            currentUserId: () => 'synthetic-admin',
            records: (_) => Stream.value(Records([venue]))));
    await t.tap(find.text('أدوات الإدارة'));
    await t.pumpAndSettle();
    await capture(t, '15-admin-tools');
  });
  testWidgets(
      'capture actual ownership proof, owner tools, staff and availability routes',
      (t) async {
    await mount(
        t,
        BookingProofInbox(
            proofs: Stream.value(Records([
          {'ownerId': 'SYNTHETIC-OWNER'}
        ]))));
    await capture(t, '16-ownership-proof');
    await mount(
        t,
        BookingOwnerTools(
            venueId: 'SYNTHETIC-VENUE', closures: Stream.value(Records([]))));
    await capture(t, '17-owner-tools');
    await t.scrollUntilVisible(find.text('نقل الملكية'), 400,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await capture(t, '18-owner-transfer-request');
    await mount(
        t,
        BookingStaffScreen(
            venueId: 'synthetic',
            scopes: const ['bookings', 'checkin', 'calendar'],
            call: (name, data) async => {
                  'bookings': [
                    {...booking, 'id': 'synthetic', 'status': 'requested'}
                  ]
                }));
    await capture(t, '19-staff-requests');
    await mount(t, const BookingAvailabilitySearchScreen());
    await capture(t, '20-availability-search');
  });
}
