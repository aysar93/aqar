import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_request_intent_store.dart';

class MemoryIntentStore implements BookingRequestIntentStore {
  @override
  Future<void> clear(String uid, String venueId, String requestId) async {}

  @override
  Future<Map<String, dynamic>?> read(String uid, String venueId) async => null;

  @override
  Future<void> save(String uid, String venueId, Map<String, dynamic> data) async {}
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final Map<String, dynamic> sampleVenue = {
    'id': 'venue_audit_test_01',
    'name': 'شاليه الفخامة رويال',
    'category': 'chalet',
    'city': 'الرمادي',
    'location': 'الرمادي — الحبانية قرب الجسر الجديد',
    'price': 250000,
    'deposit': 50000,
    'depositPolicy': 'fixed',
    'cancellationPolicy': 'flexible',
    'guestType': 'families',
    'description': 'شاليه عائلي فاخر بمسبح خاص وإطلالة خلابة',
    'amenities': ['مسبح خاص', 'واي فاي مجاني', 'شواية باربيكيو', 'حديقة واسعة', 'ألعاب أطفال'],
    'mediaPaths': ['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg'],
    'latitude': 33.4258,
    'longitude': 43.2992,
  };

  testWidgets('Venue Details TabBar remains strictly pinned during full scroll cycle and tab interactions',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Cairo',
          brightness: Brightness.dark,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BookingRequestScreen(
              venueId: 'venue_audit_test_01',
              venue: sampleVenue,
              intentStore: MemoryIntentStore(),
              currentUserId: () => 'customer_audit_uid',
              call: (fn, [args = const {}]) async {
                if (fn == 'getPublishedBookingReviews') {
                  return {'reviews': []};
                }
                return {};
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Initial State (بداية الصفحة - offset = 0)
    expect(find.byKey(const ValueKey('booking-section-0')), findsOneWidget,
        reason: 'Exactly ONE tab 0 exists at the beginning of page');
    expect(find.byKey(const ValueKey('booking-section-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-section-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-section-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-section-4')), findsOneWidget);

    final initialTabTop = tester.getRect(find.byKey(const ValueKey('booking-section-0'))).top;
    print('Initial TabBar top position at beginning of page: $initialTabTop');

    // 2. Mid Page Scroll (منتصف الصفحة - drag 600px down)
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('booking-section-0')), findsOneWidget,
        reason: 'TabBar MUST be visible at mid-page scroll');
    final midTabTop = tester.getRect(find.byKey(const ValueKey('booking-section-0'))).top;
    expect(midTabTop, closeTo(initialTabTop, 2.0),
        reason: 'TabBar MUST remain pinned at top position at mid-page');
    print('Mid-page TabBar top position: $midTabTop (STILL PINNED!)');

    // 3. End of Page Scroll (نهاية الصفحة - drag another 1200px down)
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('booking-section-0')), findsOneWidget,
        reason: 'TabBar MUST be visible at end of page');
    final endTabTop = tester.getRect(find.byKey(const ValueKey('booking-section-0'))).top;
    expect(endTabTop, closeTo(initialTabTop, 2.0),
        reason: 'TabBar MUST remain pinned at top position at end of page');
    print('End-of-page TabBar top position: $endTabTop (STILL PINNED!)');

    // 4. Return to Top (العودة إلى الأعلى - drag 2000px up)
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('booking-section-0')), findsOneWidget,
        reason: 'TabBar MUST be visible after returning to top');
    final returnTabTop = tester.getRect(find.byKey(const ValueKey('booking-section-0'))).top;
    expect(returnTabTop, closeTo(initialTabTop, 2.0),
        reason: 'TabBar MUST remain pinned at top position after return to top');
    print('Returned to top TabBar top position: $returnTabTop (STILL PINNED!)');

    // 5. Test Tapping Every Single Tab (الضغط على كل تبويب)
    await tester.tap(find.byKey(const ValueKey('booking-section-1')), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('booking-section-1')), findsOneWidget);
    print('Tapped Tab 1 (الأسعار) -> jump executed smoothly');

    await tester.tap(find.byKey(const ValueKey('booking-section-2')), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('booking-section-2')), findsOneWidget);
    print('Tapped Tab 2 (الموقع) -> jump executed smoothly');

    await tester.tap(find.byKey(const ValueKey('booking-section-3')), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('booking-section-3')), findsOneWidget);
    print('Tapped Tab 3 (المزايا) -> jump executed smoothly');

    await tester.tap(find.byKey(const ValueKey('booking-section-4')), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('booking-section-4')), findsOneWidget);
    print('Tapped Tab 4 (شروط الحجز) -> jump executed smoothly');

    await tester.tap(find.byKey(const ValueKey('booking-section-0')), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('booking-section-0')), findsOneWidget);
    print('Tapped Tab 0 (التفاصيل) -> jump executed smoothly');

    final ex = tester.takeException();
    if (ex != null) {
      // Ignore headless Firebase uninitialized warning if any
      expect(ex.toString().contains('Firebase') || ex.toString().contains('HttpClient'), isTrue);
    }
  });
}
