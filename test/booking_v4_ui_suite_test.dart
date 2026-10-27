import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_bottom_bar.dart';
import 'package:aqar/bookings/booking_search_screen.dart';
import 'package:aqar/bookings/booking_account_screen.dart';
import 'package:aqar/bookings/booking_my_venues_screen.dart';

void main() {
  group('Booking Bottom Bar Tests', () {
    testWidgets('renders all 5 booking tabs in exact required order',
        (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BookingBottomBar(
              currentIndex: selected,
              onTap: (i) => selected = i,
            ),
          ),
        ),
      );

      // Verify the 5 tabs exist in order
      expect(find.text('استكشف'), findsOneWidget);
      expect(find.text('بحث'), findsOneWidget);
      expect(find.text('ريلز'), findsOneWidget);
      expect(find.text('حجوزاتي'), findsOneWidget);
      expect(find.text('حسابي'), findsOneWidget);

      // Verify tap works
      await tester.tap(find.text('بحث'));
      await tester.pump();
      expect(selected, 1);

      await tester.tap(find.text('ريلز'));
      await tester.pump();
      expect(selected, 2);

      await tester.tap(find.text('حجوزاتي'));
      await tester.pump();
      expect(selected, 3);

      await tester.tap(find.text('حسابي'));
      await tester.pump();
      expect(selected, 4);

      await tester.tap(find.text('استكشف'));
      await tester.pump();
      expect(selected, 0);
    });

    testWidgets('displays badge counts and reels indicator accurately',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BookingBottomBar(
              currentIndex: 0,
              pendingBookingsCount: 3,
              hasReelsBadge: true,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Booking Search Screen Tests', () {
    testWidgets('renders search field, filter categories and chips',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingSearchScreen(embedded: true),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('ابحث باسم المكان، المدينة، أو المجمع...'), findsOneWidget);
      expect(find.textContaining('فلاتر البحث المتقدم'), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'شاليه الرمادي');
      await tester.pump();
      expect(find.text('شاليه الرمادي'), findsOneWidget);
    });
  });

  group('Booking Account Screen Tests', () {
    testWidgets('displays Add Venue and Manage Venues hero cards',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingAccountScreen(embedded: true),
          ),
        ),
      );

      // Verify «أضف مكانك» card
      expect(find.textContaining('أضف مكانك'), findsWidgets);
      expect(find.text('تقديم مكان جديد للتوثيق'), findsOneWidget);

      // Verify «إدارة أماكني» card
      expect(find.textContaining('إدارة أماكني'), findsWidgets);
      expect(find.text('فتح لوحة إدارة الأماكن'), findsOneWidget);

      // Verify Quick Services
      expect(find.text('خريطة الأماكن والشاليهات'), findsOneWidget);
      expect(find.text('ريلز الحجوزات المحفوظة'), findsOneWidget);
      expect(find.text('دعم الحجوزات والاستفسارات'), findsOneWidget);
      expect(find.text('شروط وسياسات الحجز'), findsOneWidget);
    });
  });

  group('Booking My Venues Screen Tests', () {
    testWidgets('renders gracefully when user is not logged in',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookingMyVenuesScreen(userId: ''),
        ),
      );

      expect(find.text('يرجى تسجيل الدخول لعرض أماكنك المسجلة'), findsOneWidget);
    });
  });
}
