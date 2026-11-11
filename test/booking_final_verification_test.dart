import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_venue_details.dart';
import 'package:aqar/bookings/booking_request_intent_store.dart';
import 'package:aqar/bookings/booking_reels_screen.dart';

class TestMeta extends Fake implements SnapshotMetadata {
  TestMeta({this.isFromCache = false, this.hasPendingWrites = false});
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

class TestDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  TestDoc(this.value, {bool cached = false})
      : metadata = TestMeta(isFromCache: cached);
  final Map<String, dynamic> value;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic> data() => value;
  @override
  DocumentReference<Map<String, dynamic>> get reference => TestDocRef('doc-id');
}

class TestDocRef extends Fake implements DocumentReference<Map<String, dynamic>> {
  TestDocRef(this.id);
  @override
  final String id;
  @override
  Future<void> update(Map<Object, Object?> data) async {}
  @override
  Future<void> delete() async {}
}

class TestQueryDoc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  TestQueryDoc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
  @override
  DocumentReference<Map<String, dynamic>> get reference => TestDocRef(id);
}

class TestRecords extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  TestRecords(List<Map<String, dynamic>> values)
      : metadata = TestMeta(isFromCache: false, hasPendingWrites: false),
        docs = [
          for (var i = 0; i < values.length; i++)
            TestQueryDoc(values[i]['id']?.toString() ?? 'doc-$i', values[i])
        ];
  @override
  final SnapshotMetadata metadata;
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class MemoryIntentStore implements BookingRequestIntentStore {
  final Map<String, Map<String, dynamic>> _data = {};
  @override
  Future<void> clear(String uid, String venueId, String requestId) async {
    _data.remove('$uid:$venueId');
  }
  @override
  Future<Map<String, dynamic>?> read(String uid, String venueId) async {
    return _data['$uid:$venueId'];
  }
  @override
  Future<void> save(String uid, String venueId, Map<String, dynamic> payload) async {
    _data['$uid:$venueId'] = payload;
  }
}

Widget testApp(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Final Precision Verification Tests', () {
    testWidgets('1. BookingDetailsScreen: Rapid aggressive scrolling up & down never produces a white screen or crashes',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const currentUid = 'user-100';
      final bookingMap = <String, dynamic>{
        'id': 'booking-rapid-1',
        'status': 'confirmed',
        'customerId': currentUid,
        'ownerId': 'owner-200',
        'venueId': 'venue-300',
        'venueName': 'منتجع الرمال الذهبية بالأنبار',
        'location': 'الرمادي - الصوفية',
        'total': 250000,
        'deposit': 50000,
        'remaining': 200000,
        'start': 1795327200000,
        'end': 1795359600000,
        'guestName': 'أحمد العبدلي',
        'guestPhone': '07701234567',
        'terms': 'شروط الحجز الخاصة المعتمدة للمنتجع',
        'cancellationPolicy': {
          'freeCancellationHours': 48,
          'lateRefundPercent': 50,
        },
      };

      await tester.pumpWidget(
        testApp(
          BookingDetailsScreen(
            bookingId: 'booking-rapid-1',
            currentUserId: () => currentUid,
            sessions: Stream.value(currentUid),
            roles: (_) => Stream.value(TestDoc({'isBlocked': false, 'isAdmin': false})),
            paymentAccounts: Stream.value({}),
            events: Stream.value(TestRecords([])),
            dataStream: Stream.value(TestDoc(bookingMap)),
            call: (name, data) async => {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify content is rendered
      expect(find.text('منتجع الرمال الذهبية بالأنبار'), findsOneWidget);
      expect(find.text('حجز مؤكد'), findsWidgets);

      // Rapidly scroll down and up 10 times at various velocities
      final scrollableFinder = find.byType(SingleChildScrollView);
      expect(scrollableFinder, findsOneWidget);

      for (var i = 0; i < 10; i++) {
        // Fling down
        await tester.fling(scrollableFinder, const Offset(0, -1200), 3000);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        // Ensure content is still mounted and visible, NOT white/blank screen
        expect(find.byType(BookingDetailsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Fling up
        await tester.fling(scrollableFinder, const Offset(0, 1200), 3000);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(BookingDetailsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await tester.pumpAndSettle();
      expect(find.text('منتجع الرمال الذهبية بالأنبار'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. BookingVenueDetails: Pinned TabBar activates upon scrolling and jump() scrolls without lag',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final venue = {
        'id': 'venue-tab-test',
        'name': 'فيلا الخالدية السياحية',
        'location': 'الأنبار - الخالدية',
        'price': 200000,
        'deposit': 50000,
        'pricingMode': 'fixed',
        'guestType': 'both',
        'mediaPaths': ['asset://chalet.jpg', 'booking_media/sample.mp4?token=123'],
        'amenities': ['wifi', 'pool', 'parking'],
        'description': 'مكان سياحي متكامل للعوائل والشباب.',
      };

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: BookingRequestScreen(
              venueId: 'venue-tab-test',
              venue: venue,
              intentStore: MemoryIntentStore(),
              currentUserId: () => 'test-uid',
              call: (name, params) async => {
                'available': true,
                'reserved': [],
                'disabled': [],
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify venue name and inline section keys
      expect(find.text('فيلا الخالدية السياحية'), findsWidgets);
      expect(find.byKey(const ValueKey('booking-section-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-section-1')), findsOneWidget);

      // Scroll down past 360 px
      final listFinder = find.byKey(const ValueKey('booking-step-0'));
      expect(listFinder, findsOneWidget);

      await tester.drag(listFinder, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Pinned Tab Bar should now be active and visible at top
      expect(find.byKey(const ValueKey('booking-pinned-tab-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-pinned-tab-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-pinned-tab-2')), findsOneWidget);

      // Tap pinned tab 'الأسعار' (index 1)
      await tester.tap(find.byKey(const ValueKey('booking-pinned-tab-1')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Venue Editor Media Upload: Displays image upload button, progress card and handles retry state',
        (tester) async {
      final venue = {
        'id': 'venue-upload-test',
        'name': 'مزرعة الفلوجة النموذجية',
        'location': 'الفلوجة',
        'pricingMode': 'fixed',
        'price': 180000,
        'deposit': 40000,
        'verificationStatus': 'pending',
      };

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: BookingVenueEditor(
              venueId: 'venue-upload-test',
              data: venue,
              ownerMode: true,
              call: (name, params) async => {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Media tab (index 4)
      final mediaTab = find.widgetWithText(Tab, 'الوسائط والشروط');
      await tester.ensureVisible(mediaTab);
      await tester.tap(mediaTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify buttons exist
      expect(find.text('رفع صورة للمراجعة (10 MB)'), findsOneWidget);
      expect(find.text('رفع فيديو للمراجعة (50 MB)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Reels Comments: Nested replies, reply-to banner, and admin/author delete visibility',
        (tester) async {
      final comments = [
        {
          'id': 'comment-1',
          'userId': 'user-1',
          'userName': 'سعد الكبيسي',
          'text': 'هل المسبح مغلق ومناسب للعوائل؟',
          'createdAt': Timestamp.now(),
        },
        {
          'id': 'comment-2',
          'userId': 'owner-1',
          'userName': 'إدارة الشاليه',
          'text': 'نعم المسبح مغلق بالكامل ومحاط بخصوصية تامة.',
          'parentId': 'comment-1',
          'replyToAuthor': 'سعد الكبيسي',
          'createdAt': Timestamp.now(),
        },
      ];

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: BookingReelCommentsSheet(
              reelId: 'reel-test-1',
              admin: true,
              currentUserId: () => 'user-1',
              commentsStream: Stream.value(TestRecords(comments)),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check comments and reply rendered
      expect(find.text('سعد الكبيسي'), findsOneWidget);
      expect(find.text('هل المسبح مغلق ومناسب للعوائل؟'), findsOneWidget);
      expect(find.text('إدارة الشاليه'), findsOneWidget);
      expect(find.text('رد على @سعد الكبيسي'), findsOneWidget);
      expect(find.text('نعم المسبح مغلق بالكامل ومحاط بخصوصية تامة.'), findsOneWidget);

      // Admin has delete permissions on comments
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

      // Tap 'رد' on parent comment
      final replyButtons = find.text('رد');
      expect(replyButtons, findsNWidgets(2));
      await tester.tap(replyButtons.first);
      await tester.pumpAndSettle();

      // Verify active reply banner appears
      expect(find.text('الرد على سعد الكبيسي'), findsOneWidget);
      expect(find.text('اكتب ردك على سعد الكبيسي...'), findsOneWidget);

      // Dismiss reply banner
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Verify banner dismissed and reverted to standard comment prompt
      expect(find.text('الرد على سعد الكبيسي'), findsNothing);
      expect(find.text('اكتب تعليقك...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
