import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_experience.dart';
import 'package:aqar/bookings/booking_management.dart';
import 'support/booking_intent_store_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final venue = <String, dynamic>{
    'name': 'شاليه النخيل التجريبي UAT',
    'location': 'الرمادي — الصوفية',
    'description': 'شاليه فاخر ونظيف مجهز بكافة الخدمات والمرافق.',
    'guestType': 'families_only',
    'latitude': 33.4350,
    'longitude': 43.3150,
    'images': <String>[],
    'price': 100000,
    'deposit': 50000,
    'terms': 'احترام أوقات الدخول والخروج والمحافظة على النظافة.',
    'pricingMode': 'shifts',
    'shifts': [
      {
        'id': 'morning',
        'name': 'الفترة الصباحية',
        'price': 100000,
        'checkInMinute': 540,
        'checkOutMinute': 1080,
      },
    ],
  };

  Future<Map<String, dynamic>> mockCall(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (name == 'getPublishedBookingReviews') {
      return {'count': 0, 'average': 0, 'reviews': []};
    }
    if (name == 'getBookingAvailability') {
      return {'slots': []};
    }
    return {};
  }

  Widget createTestWidget() {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: BookingRequestScreen(
          venueId: 'test-venue-steps',
          venue: venue,
          call: mockCall,
          intentStore: MemoryIntentStore(),
          currentUserId: () => 'test-user-123',
        ),
      ),
    );
  }

  testWidgets(
    'BookingCheckoutHeader does NOT show on venue details (step 0) and appears ONLY after "احجز الآن"',
    (tester) async {
      tester.view.physicalSize = const Size(430, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 1. On Venue Details (step 0), BookingCheckoutHeader MUST NOT appear
      expect(
        find.byType(BookingCheckoutHeader),
        findsNothing,
        reason: 'مؤشر خطوات الحجز يجب ألا يظهر في صفحة تفاصيل المكان',
      );
      expect(find.text('احجز الآن'), findsOneWidget);
      expect(find.text('شاليه النخيل التجريبي UAT'), findsAtLeastNWidgets(1));

      // 2. Tap "احجز الآن" to enter booking process (step 1)
      await tester.tap(find.byKey(const ValueKey('booking-next')));
      await tester.pumpAndSettle();

      // 3. Now in Booking Step 1 (Date Selection), BookingCheckoutHeader MUST appear
      expect(
        find.byType(BookingCheckoutHeader),
        findsOneWidget,
        reason: 'مؤشر خطوات الحجز يجب أن يظهر بعد الضغط على احجز الآن',
      );
      expect(
        find.descendant(
          of: find.byType(BookingCheckoutHeader),
          matching: find.text('اختيار الموعد'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BookingCheckoutHeader),
          matching: find.text('بيانات الحجز'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BookingCheckoutHeader),
          matching: find.text('التأكيد'),
        ),
        findsOneWidget,
      );

      // Active node is step 1, while check icon is not visible yet (no completed steps)
      expect(find.byIcon(Icons.check), findsNothing);

      // Verify Next button is disabled until requirements (selecting day) are met
      final nextBtn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('booking-next')),
      );
      expect(
        nextBtn.onPressed,
        isNull,
        reason:
            'لا يجوز نقل المستخدم إلى الخطوة التالية قبل إكمال متطلبات الخطوة الحالية',
      );

      // 4. Select a day in the calendar (day 15 of current month)
      final dayCell = find.text('15');
      if (dayCell.evaluate().isNotEmpty) {
        await tester.tap(dayCell.first);
        await tester.pumpAndSettle();

        // Next button is now enabled
        final enabledNextBtn = tester.widget<FilledButton>(
          find.byKey(const ValueKey('booking-next')),
        );
        expect(enabledNextBtn.onPressed, isNotNull);

        // Advance to Step 2 (Review & Terms)
        await tester.tap(find.byKey(const ValueKey('booking-next')));
        await tester.pumpAndSettle();

        // In Step 2, BookingCheckoutHeader is still visible
        expect(find.byType(BookingCheckoutHeader), findsOneWidget);
        // Step 1 now displays the completed checkmark icon
        expect(
          find.byIcon(Icons.check),
          findsOneWidget,
          reason: 'الخطوة الأولى المكتملة يجب أن تعرض أيقونة التحقق الخضراء',
        );

        // Go back to Step 1 using back button
        final backBtn = find.byTooltip('الخطوة السابقة');
        expect(backBtn, findsOneWidget);
        await tester.tap(backBtn);
        await tester.pumpAndSettle();

        // Still in booking flow, header remains
        expect(find.byType(BookingCheckoutHeader), findsOneWidget);

        // Go back to Step 0 (Venue Details)
        await tester.tap(backBtn);
        await tester.pumpAndSettle();

        // Back on Venue Details: header disappears again!
        expect(
          find.byType(BookingCheckoutHeader),
          findsNothing,
          reason: 'عند الرجوع إلى تفاصيل المكان يختفي مؤشر خطوات الحجز',
        );
      }
    },
  );

  testWidgets('Booking flow advances through all 3 steps: Step 1 -> Step 2 -> Step 3', (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Step 0 -> Step 1
    await tester.tap(find.byKey(const ValueKey('booking-next')));
    await tester.pumpAndSettle();
    expect(find.text('اختيار الموعد'), findsAtLeastNWidgets(1));

    // Select day 15
    final dayCell = find.text('15');
    if (dayCell.evaluate().isNotEmpty) {
      await tester.tap(dayCell.first);
      await tester.pumpAndSettle();

      // Tap "متابعة لبيانات الحجز" -> enters Step 2
      expect(find.text('متابعة لبيانات الحجز'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('booking-next')));
      await tester.pumpAndSettle();

      // Verify Step 2 (Guest Data)
      expect(find.text('بيانات الحجز'), findsAtLeastNWidgets(1));
      expect(find.text('عدد الضيوف المتوقع:'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget); // Step 1 is checked

      // Tap "متابعة لمراجعة الحجز" -> enters Step 3
      expect(find.text('متابعة لمراجعة الحجز'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('booking-next')));
      await tester.pumpAndSettle();

      // Verify Step 3 (Review & Confirmation)
      expect(find.text('مراجعة وتأكيد الحجز'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2)); // Steps 1 and 2 are checked
      expect(find.byKey(const ValueKey('booking-submit-request')), findsOneWidget);
    }
  });
}
