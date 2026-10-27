import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_decision_ui.dart';
import 'package:aqar/bookings/booking_experience.dart';
import 'package:aqar/bookings/booking_services_ui.dart';
import 'package:aqar/bookings/booking_admin_tasks.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/screens/admin/payment_account_settings_screen.dart';
import 'package:aqar/screens/admin/banner_management_screen.dart';
import 'package:aqar/screens/admin/add_banner_screen.dart';
import 'package:aqar/banners/banner_model.dart';
import 'package:aqar/banners/banner_service.dart';
import 'booking_services_ui_test.dart' show Records;

const preview = {
  'bookingId': 'synthetic-booking',
  'action': 'settleOwner',
  'amount': 47500,
  'currency': 'IQD',
  'version': 3,
  'beneficiary': {'id': 'SYNTHETIC-OWNER', 'name': 'مالك تجريبي'},
  'reason': 'completed_booking'
};
Widget app(Widget child, {double scale = 1}) => RepaintBoundary(
    key: const ValueKey('polish-capture'),
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'SplashTajawal'),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, body) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: body!),
        home: child));
void main() {
  Future<void> mount(WidgetTester t, Widget child,
      {double scale = 1, Size size = const Size(430, 1100)}) async {
    t.view.physicalSize = size;
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
      await expectLater(find.byKey(const ValueKey('polish-capture')),
          matchesGoldenFile('polish_captures/$name.png'));
  }

  Future<Uint8List> receipt() async {
    final recorder = ui.PictureRecorder(),
        paint = Paint()..color = Colors.white;
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 150), paint);
    final text = TextPainter(
        text: const TextSpan(
            text: 'SYNTHETIC RECEIPT\nTEST ONLY — 50,000 IQD',
            style: TextStyle(
                color: Colors.black,
                fontSize: 19,
                fontFamily: 'SplashTajawal')),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 280);
    text.paint(canvas, const Offset(10, 30));
    final image = await recorder.endRecording().toImage(300, 150);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  testWidgets(
      'payment exposes verified recipient copy and requires receipt plus reference before send',
      (t) async {
    final transaction = TextEditingController();
    addTearDown(transaction.dispose);
    Uint8List? bytes;
    StateSetter? update;
    var sent = 0;
    String? copied;
    t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        copied = (call.arguments as Map)['text'];
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await mount(t, StatefulBuilder(builder: (context, set) {
      update = set;
      return BookingScaffold(
          appBar: AppBar(title: const Text('العربون والإيصال')),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            BookingPaymentPanel(
                deposit: 50000,
                accounts: const {
                  'qicard': {'number': '00000000000000'}
                },
                method: 'qicard',
                transaction: transaction,
                busy: false,
                onMethod: (_) {},
                receiptBytes: bytes,
                onPickReceipt: () {},
                onSubmit: () => sent++)
          ]));
    }));
    await capture(t, '01-payment-before-receipt');
    await t.tap(find.text('نسخ رقم المستلم'));
    await t.pumpAndSettle();
    expect(copied, '00000000000000');
    ScaffoldMessenger.of(t.element(find.byType(BookingPaymentPanel)))
        .clearSnackBars();
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'SYNTHETIC-TRANSFER');
    await t.ensureVisible(find.text('إرسال الإيصال للمراجعة'));
    await t.pumpAndSettle();
    await t.tap(find.text('إرسال الإيصال للمراجعة'));
    expect(sent, 0);
    final data = (await t.runAsync(receipt))!;
    await t.runAsync(() => precacheImage(
        MemoryImage(data), t.element(find.byType(BookingPaymentPanel))));
    update!(() => bytes = data);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('معاينة الإيصال قبل الإرسال'));
    await t.pumpAndSettle();
    await capture(t, '02-payment-receipt-preview');
    await t.ensureVisible(find.text('إرسال الإيصال للمراجعة'));
    await t.pumpAndSettle();
    await t.tap(find.text('إرسال الإيصال للمراجعة'));
    expect(sent, 1);
  });
  testWidgets(
      'finance context is verified then confirmed and rechecked before recording',
      (t) async {
    final reference = TextEditingController(text: 'SYNTHETIC-SETTLEMENT');
    addTearDown(reference.dispose);
    var reads = 0, writes = 0;
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('مراجعة التسوية')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingManualSettlement(
                  title: 'تسوية مستحقات المالك',
                  reference: reference,
                  busy: false,
                  onSubmit: () => writes++,
                  label: 'مراجعة تسجيل التسوية',
                  bookingId: 'synthetic-booking',
                  action: 'settleOwner',
                  version: 3,
                  loadPreview: () async {
                    reads++;
                    return preview;
                  })
            ])));
    await capture(t, '03-owner-settlement-context');
    expect(writes, 0);
    await t.tap(find.text('مراجعة تسجيل التسوية'));
    await t.pumpAndSettle();
    await capture(t, '04-settlement-confirmation');
    expect(find.text('معرف المستفيد: SYNTHETIC-OWNER'), findsWidgets);
    await t.tap(find.text('تأكيد التسجيل'));
    await t.pumpAndSettle();
    expect(writes, 1);
    expect(reads, 2);
  });
  testWidgets(
      'changed preview and malformed old amounts cannot silently record a settlement',
      (t) async {
    final reference = TextEditingController(text: 'REF');
    addTearDown(reference.dispose);
    var reads = 0, writes = 0;
    await mount(
        t,
        BookingScaffold(
            body: ListView(children: [
          BookingManualSettlement(
              title: 'تسوية',
              reference: reference,
              busy: false,
              onSubmit: () => writes++,
              label: 'راجع',
              bookingId: 'synthetic-booking',
              action: 'settleOwner',
              loadPreview: () async => ++reads == 1
                  ? preview
                  : {...preview, 'version': 4, 'amount': 47000})
        ])));
    await t.tap(find.text('راجع'));
    await t.pumpAndSettle();
    await t.tap(find.text('تأكيد التسجيل'));
    await t.pumpAndSettle();
    expect(writes, 0);
    expect(find.textContaining('تغيرت بيانات الاستحقاق'), findsOneWidget);
    await mount(
        t,
        BookingScaffold(
            body: ListView(children: [
          BookingManualSettlement(
              key: UniqueKey(),
              title: 'تسوية',
              reference: reference,
              busy: false,
              onSubmit: () => writes++,
              label: 'راجع',
              bookingId: 'synthetic-booking',
              action: 'settleOwner',
              loadPreview: () async => {...preview, 'amount': '47500'})
        ])));
    await capture(t, '05-settlement-unverified');
    expect(find.text('راجع'), findsNothing);
    expect(writes, 0);
  });
  testWidgets(
      'refund identifies customer amount cause and exact booking before recording',
      (t) async {
    final reference = TextEditingController();
    addTearDown(reference.dispose);
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('الاسترداد')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingManualSettlement(
                  title: 'إعادة العربون المستحق',
                  reference: reference,
                  busy: false,
                  onSubmit: () {},
                  label: 'مراجعة الاسترداد',
                  bookingId: 'synthetic-booking',
                  action: 'settleRefund',
                  version: 3,
                  loadPreview: () async => {
                        ...preview,
                        'action': 'settleRefund',
                        'amount': 20000,
                        'reason': 'cancelled_booking_refund',
                        'beneficiary': {
                          'id': 'SYNTHETIC-CUSTOMER',
                          'name': 'ضيف تجريبي'
                        }
                      })
            ])));
    await capture(t, '06-refund-context');
    expect(find.textContaining('SYNTHETIC-CUSTOMER'), findsOneWidget);
    expect(find.textContaining('أدخل مرجع التحويل'), findsOneWidget);
  });
  testWidgets(
      'stored conditions never fill missing history or financial fields from defaults',
      (t) async {
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('شروط الحجز')),
            body: ListView(padding: const EdgeInsets.all(20), children: const [
              BookingAgreedPolicy(booking: {
                'terms': 'الشروط الأصلية المحفوظة وقت الطلب',
                'cancellationPolicy': {
                  'freeCancellationHours': 24,
                  'lateRefundPercent': 25
                }
              })
            ])));
    await capture(t, '07-agreed-policy');
    expect(find.textContaining('الشروط الأصلية المحفوظة'), findsOneWidget);
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('حجز قديم')),
            body: ListView(padding: const EdgeInsets.all(20), children: const [
              BookingAgreedPolicy(booking: {}),
              BookingRecordedMoney(booking: {'refundDue': null, 'paid': 0})
            ])));
    await capture(t, '08-legacy-unknown');
    expect(find.textContaining('سياسة الإلغاء الأصلية غير مكتملة'),
        findsOneWidget);
    expect(find.text('المبلغ المعاد: غير متوفر'), findsOneWidget);
    expect(find.textContaining('0٪'), findsNothing);
  });
  testWidgets(
      'shared payment settings preserve revision and methods and block duplicate save',
      (t) async {
    final pending = Completer<Map<String, dynamic>>();
    final writes = <Map<String, dynamic>>[];
    await mount(t, PaymentAccountSettingsScreen(call: (name, data) async {
      if (name == 'getPaymentAccountSettings')
        return {
          'revision': 7,
          'methods': {
            'qicard': {'enabled': true, 'number': '00000000000000'},
            'zaincash': {'enabled': false, 'number': ''}
          }
        };
      writes.add(data);
      return pending.future;
    }));
    await capture(t, '09-shared-payment-accounts');
    await t.ensureVisible(find.text('حفظ حسابات الدفع'));
    await t.pumpAndSettle();
    await t.tap(find.text('حفظ حسابات الدفع'));
    await t.tap(find.text('حفظ حسابات الدفع'));
    await t.pump();
    expect(writes, hasLength(1));
    expect(writes.single['revision'], 7);
    expect((writes.single['methods'] as Map).keys,
        containsAll(['qicard', 'zaincash']));
    pending.complete({});
    await t.pumpAndSettle();
  });
  testWidgets(
      'booking banner list and editor keep the venue target and shared external editor',
      (t) async {
    final banner = BannerModel(
        id: 'synthetic-banner',
        title: 'وجهتك ليوم مميز',
        subtitle: 'شاليهات الأنبار',
        imageUrl: 'https://example.invalid/synthetic.png',
        type: 'chalet',
        targetId: 'synthetic-0',
        isActive: true,
        order: 1);
    await mount(
        t,
        BannerManagementScreen(
            placement: BannerPlacement.bookings,
            banners: Stream.value([banner])));
    await capture(t, '10-booking-banner-management');
    expect(find.text('معرف المكان: synthetic-0'), findsOneWidget);
    await mount(
        t,
        AddBannerScreen(
            placement: BannerPlacement.bookings,
            banner: banner,
            venues: Stream.value(Records([
              {'name': 'شاليه اصطناعي', 'category': 'chalet'}
            ]))));
    final mediaError = t.takeException();
    if (mediaError != null)
      expect(mediaError, isA<NetworkImageLoadException>());
    await capture(t, '11-booking-banner-editor');
    await mount(
        t,
        AddBannerScreen(
            key: UniqueKey(),
            banner: BannerModel(
                id: 'shared',
                title: 'بنر مشترك',
                subtitle: 'وصف اصطناعي',
                imageUrl: 'https://example.invalid/synthetic.png',
                type: 'external',
                targetId: 'https://example.com',
                isActive: false,
                order: 2)));
    final sharedMediaError = t.takeException();
    if (sharedMediaError != null)
      expect(sharedMediaError, isA<NetworkImageLoadException>());
    await capture(t, '12-shared-banner-editor');
  });
  testWidgets(
      'admin tasks use only verified pending counts and support large text',
      (t) async {
    final opened = <String>[];
    await mount(
        t,
        BookingScaffold(
            appBar: AppBar(title: const Text('مهام الإدارة')),
            body: ListView(children: [
              BookingAdminTasks(records: {
                for (final key in bookingTaskCollections.keys)
                  key: Stream.value(Records([{}], cached: key == 'reports'))
              }, onOpen: opened.add)
            ])));
    await capture(t, '13-admin-pending-tasks');
    expect(find.text('غير متاح'), findsOneWidget);
    await t.tap(find.text('طلبات الحجز'));
    expect(opened, ['requests']);
    await mount(
        t,
        BookingScaffold(
            body: ListView(children: [
          BookingAdminTasks(records: const {}, onOpen: opened.add)
        ])),
        scale: 1.8,
        size: const Size(360, 640));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'editor save stays available across tabs with keyboard and large Arabic text',
      (t) async {
    var saves = 0;
    await mount(
        t,
        BookingVenueEditor(
            ownerMode: true,
            data: const {
              'name': 'شاليه اصطناعي',
              'category': 'chalet',
              'price': 250000,
              'deposit': 50000,
              'capacity': 8,
              'bedrooms': 2,
              'terms': 'شروط محفوظة'
            },
            call: (n, d) async {
              saves++;
              return {};
            },
            onSaved: () {}));
    await capture(t, '14-editor-sticky-save');
    expect(find.text('حفظ بيانات المكان'), findsOneWidget);
    await t.tap(find.text('حفظ بيانات المكان'));
    await t.pumpAndSettle();
    expect(saves, 1);
    await mount(
        t, BookingVenueEditor(ownerMode: true, call: (n, d) async => {}),
        scale: 1.6, size: const Size(360, 640));
    await t.drag(find.byType(ListView).first, const Offset(0, -200));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextField, 'اسم المكان'));
    t.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(t.view.resetViewInsets);
    await t.pump();
    expect(t.takeException(), isNull);
    await capture(t, '15-large-text-keyboard');
  });
}
