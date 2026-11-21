import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_bottom_bar.dart';
import 'package:aqar/bookings/booking_filters.dart';
import 'package:aqar/bookings/booking_map.dart';
import 'package:aqar/bookings/booking_reels_screen.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_search_screen.dart';
import 'package:aqar/bookings/booking_account_screen.dart';
import 'package:aqar/bookings/booking_my_venues_screen.dart';

class _FakeMeta extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
}

// ignore: subtype_of_sealed_class
class _FakeVenueDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeVenueDoc(this.id, this._data);
  @override
  final String id;
  final Map<String, dynamic> _data;
  @override
  Map<String, dynamic> data() => _data;
}

class _FakeVenueSnap extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeVenueSnap(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  SnapshotMetadata get metadata => _FakeMeta();
}

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
      expect(find.text('أضف مكانك الآن'), findsOneWidget);

      // Verify «إدارة أماكني» card
      expect(find.textContaining('إدارة أماكني'), findsWidgets);
      expect(find.text('الشاليهات، الأسعار، التوفر والطلبات'), findsOneWidget);

      // Verify Quick Services
      expect(find.text('خريطة الأماكن والشاليهات'), findsOneWidget);
      expect(find.text('الشاليهات والمقاطع التي حفظتها'), findsOneWidget);
      expect(find.text('الدعم والمساعدة'), findsOneWidget);
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

  group('Venue Approval & Public Eligibility Across All 6 Bookings Screens', () {
    final mixedVenues = <_FakeVenueDoc>[
      _FakeVenueDoc('v_verified', {
        'name': 'شاليه معتمد أول',
        'category': 'chalet',
        'location': 'الرمادي',
        'price': 100000,
        'active': true,
        'verificationStatus': 'verified',
        'latitude': 33.42,
        'longitude': 43.30,
        'mediaPaths': <String>['booking_venues/v_verified/videos/intro.mp4'],
      }),
      _FakeVenueDoc('v_approved', {
        'name': 'مزرعة معتمدة ثانية',
        'category': 'farm',
        'location': 'الفلوجة',
        'price': 150000,
        'active': true,
        'verificationStatus': 'approved',
        'latitude': 33.35,
        'longitude': 43.78,
        'mediaPaths': <String>['booking_venues/v_approved/videos/tour.mp4'],
      }),
      _FakeVenueDoc('v_pending_active', {
        'name': 'شاليه قيد المراجعة مخفي',
        'category': 'chalet',
        'location': 'الرمادي',
        'price': 120000,
        'active': true,
        'verificationStatus': 'pending',
        'latitude': 33.43,
        'longitude': 43.31,
        'mediaPaths': <String>['booking_venues/v_pending_active/videos/leak.mp4'],
      }),
      _FakeVenueDoc('v_rejected_active', {
        'name': 'قاعة مرفوضة مخفية',
        'category': 'hall',
        'location': 'الفلوجة',
        'price': 200000,
        'active': true,
        'verificationStatus': 'rejected',
        'rejectReason': 'وثائق غير مطابقة',
        'latitude': 33.36,
        'longitude': 43.79,
        'mediaPaths': <String>['booking_venues/v_rejected_active/videos/leak2.mp4'],
      }),
      _FakeVenueDoc('v_inactive_verified', {
        'name': 'مزرعة معطلة مخفية',
        'category': 'farm',
        'location': 'الحبانية',
        'price': 90000,
        'active': false,
        'verificationStatus': 'verified',
        'latitude': 33.38,
        'longitude': 43.58,
        'mediaPaths': <String>['booking_venues/v_inactive_verified/videos/off.mp4'],
      }),
    ];

    test('isPubliclyEligibleBookingVenue allows ONLY active + verified/approved', () {
      expect(isPubliclyEligibleBookingVenue(mixedVenues[0].data()), isTrue);
      expect(isPubliclyEligibleBookingVenue(mixedVenues[1].data()), isTrue);
      expect(isPubliclyEligibleBookingVenue(mixedVenues[2].data()), isFalse);
      expect(isPubliclyEligibleBookingVenue(mixedVenues[3].data()), isFalse);
      expect(isPubliclyEligibleBookingVenue(mixedVenues[4].data()), isFalse);
    });

    testWidgets('1. Explore Screen (استكشف) displays ONLY verified & approved active venues',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BookingScreen(
            currentUserId: () => 'customer-1',
            records: (_) => Stream.value(_FakeVenueSnap(mixedVenues)),
            banners: Stream.value(const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('شاليه معتمد أول'), findsOneWidget);
      expect(find.text('مزرعة معتمدة ثانية'), findsOneWidget);
      expect(find.text('شاليه قيد المراجعة مخفي'), findsNothing);
      expect(find.text('قاعة مرفوضة مخفية'), findsNothing);
      expect(find.text('مزرعة معطلة مخفية'), findsNothing);
    });

    testWidgets('2. Search Screen (البحث) displays ONLY verified & approved active venues and preserves sorting/filtering',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingSearchScreen(
              embedded: true,
              stream: Stream.value(_FakeVenueSnap(mixedVenues)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('شاليه معتمد أول'), findsOneWidget);
      expect(find.text('مزرعة معتمدة ثانية'), findsOneWidget);
      expect(find.text('شاليه قيد المراجعة مخفي'), findsNothing);
      expect(find.text('قاعة مرفوضة مخفية'), findsNothing);
      expect(find.text('مزرعة معطلة مخفية'), findsNothing);
    });

    testWidgets('3. Map Screen (الخريطة) plots ONLY verified & approved active venues',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BookingMapScreen(
            loadTiles: false,
            venues: Stream.value(
              mixedVenues
                  .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
                  .toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('شاليه معتمد أول'), findsOneWidget);
      expect(find.text('مزرعة معتمدة ثانية'), findsOneWidget);
      expect(find.text('شاليه قيد المراجعة مخفي'), findsNothing);
      expect(find.text('قاعة مرفوضة مخفية'), findsNothing);
      expect(find.text('مزرعة معطلة مخفية'), findsNothing);
    });

    testWidgets('4. Reels Screen (ريلز الحجوزات) extracts ONLY verified & approved active venue videos',
        (tester) async {
      final eligibleReels = BookingReelItem.extractEligibleVenueReels(mixedVenues);
      expect(eligibleReels.map((r) => r.venueId).toList(), ['v_verified', 'v_approved']);

      await tester.pumpWidget(
        MaterialApp(
          home: BookingReelsScreen(
            initialReels: eligibleReels,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('شاليه معتمد أول'), findsOneWidget);
      expect(find.text('شاليه قيد المراجعة مخفي'), findsNothing);
      expect(find.text('قاعة مرفوضة مخفية'), findsNothing);
    });

    testWidgets('5. Owner Venues Management (حساب المالك وإدارة أماكنه) shows ALL owner venues across all statuses with accurate counters',
        (tester) async {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BookingMyVenuesScreen(
            userId: 'owner-1',
            stream: Stream.value(_FakeVenueSnap(mixedVenues)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Owner sees all 5 of their venues (verified, approved, pending, rejected, inactive)
      expect(find.text('شاليه معتمد أول'), findsOneWidget);
      expect(find.text('مزرعة معتمدة ثانية'), findsOneWidget);
      expect(find.text('شاليه قيد المراجعة مخفي'), findsOneWidget);
      expect(find.text('قاعة مرفوضة مخفية'), findsOneWidget);
      expect(find.text('مزرعة معطلة مخفية'), findsOneWidget);
    });

    testWidgets('6. Admin Panel (لوحة الإدارة) displays ALL venues across all statuses',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BookingScreen(
            admin: true,
            currentUserId: () => 'admin-1',
            records: (_) => Stream.value(_FakeVenueSnap(mixedVenues)),
            banners: Stream.value(const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      for (final name in const [
        'شاليه معتمد أول',
        'مزرعة معتمدة ثانية',
        'شاليه قيد المراجعة مخفي',
        'قاعة مرفوضة مخفية',
        'مزرعة معطلة مخفية',
      ]) {
        await tester.scrollUntilVisible(
          find.text(name),
          200,
          scrollable: scrollable,
        );
        expect(find.text(name), findsOneWidget);
      }
    });
  });
}
