import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_workspace.dart';
import 'package:aqar/bookings/booking_widgets.dart';

const valid = {
  'depositCollected': 50000,
  'refundPaid': 0,
  'ownerPaid': 0,
  'platformCommission': 0,
  'action': 'confirmPayment',
  'bookingId': 'SYNTHETIC-BOOKING',
  'reference': 'SYNTHETIC-REFERENCE'
};
void main() {
  test('ledger keeps explicit zero and sums whole integer amounts exactly', () {
    expect(
        bookingLedgerTotals([
          valid,
          {...valid, 'depositCollected': 1000.0}
        ]),
        {
          'depositCollected': 51000,
          'refundPaid': 0,
          'ownerPaid': 0,
          'platformCommission': 0
        });
    expect(bookingLedgerTotals([])['depositCollected'], 0);
  });
  test(
      'legacy unknown, strings, negative, fractional and unsafe amounts never become zero',
      () {
    for (final value in [
      null,
      '50000',
      -1,
      0.5,
      double.nan,
      double.infinity,
      9007199254740992
    ]) {
      final totals = bookingLedgerTotals([
        {...valid, 'depositCollected': value}
      ]);
      expect(totals['depositCollected'], isNull);
      expect(totals['refundPaid'], 0);
    }
    expect(
        bookingLedgerTotals([
          {...valid, 'depositCollected': 9007199254740991},
          valid
        ])['depositCollected'],
        isNull);
  });
  testWidgets(
      'live ledger content renders valid, legacy and empty states at phone width',
      (tester) async {
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
    for (final state in ['valid', 'legacy', 'empty']) {
      final entries = state == 'empty'
          ? <Map<String, dynamic>>[]
          : [
              state == 'legacy' ? {...valid, 'depositCollected': null} : valid
            ];
      await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
              key: const ValueKey('workspace-capture'),
              child: BookingScaffold(
                  appBar: AppBar(title: const Text('دفتر مالية الحجوزات')),
                  body: BookingLedgerContent(entries: entries)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (state == 'legacy') {
        expect(find.text('توجد مبالغ غير مكتملة'), findsOneWidget);
        expect(find.text('غير متوفر'), findsOneWidget);
      }
      if (const bool.fromEnvironment('BOOKING_CAPTURE_UI'))
        await expectLater(find.byKey(const ValueKey('workspace-capture')),
            matchesGoldenFile('live_captures/06-ledger-$state.png'));
    }
  });
  testWidgets('actual owner query content supports narrow RTL and large text',
      (tester) async {
    for (final scale in [1.0, 2.0]) {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: const ValueKey('owner-capture'),
              child: BookingScaffold(
                  appBar: AppBar(title: const Text('لوحة المالك')),
                  body: SingleChildScrollView(
                      child: Column(children: [
                    const BookingOwnerPanel(onOpen: null, bookings: [
                      {
                        'id': 'SYNTHETIC-1',
                        'status': 'requested',
                        'venueName': 'شاليه ضفاف الفرات',
                        'customerName': 'ضيف تجريبي',
                        'total': 250000,
                        'start': 1795327200000
                      },
                      {
                        'id': 'SYNTHETIC-2',
                        'status': 'confirmed',
                        'venueName': 'قاعة تجريبية',
                        'customerName': 'ضيف تجريبي',
                        'total': 500000,
                        'start': 1795413600000
                      }
                    ]),
                  ]))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scale == 1 && const bool.fromEnvironment('BOOKING_CAPTURE_UI'))
        await expectLater(find.byKey(const ValueKey('owner-capture')),
            matchesGoldenFile('live_captures/07-owner-content.png'));
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('owner booking cards open the selected document id',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: BookingScaffold(
            body: SingleChildScrollView(
                child: BookingOwnerPanel(bookings: const [
      {
        'id': 'booking-1',
        'status': 'requested',
        'venueName': 'Test venue',
        'total': 1000
      }
    ], onOpen: (id) => selected = id)))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test venue'));
    await tester.tap(find.text('Test venue'));
    expect(selected, 'booking-1');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'management action tiles wrap at narrow width with large Arabic text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: BookingScaffold(
            body: SingleChildScrollView(
                child: Wrap(spacing: 12, runSpacing: 12, children: [
          BookingWorkspaceAction(
              onPressed: () {}, child: const Text('مراجعة الوسائط')),
          BookingWorkspaceAction(
              onPressed: () {}, child: const Text('توثيق الملكية'))
        ])))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
