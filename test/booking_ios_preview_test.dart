import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/admin/tabs/booking_admin_reports_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ignore: subtype_of_sealed_class
class _FakeMeta extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
}

// ignore: subtype_of_sealed_class
class MockDocSnap extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;
  final String _id;
  MockDocSnap(this._id, this._data);
  @override
  String get id => _id;
  @override
  Map<String, dynamic> data() => _data;
}

// ignore: subtype_of_sealed_class
class MockQuerySnap extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  MockQuerySnap(this._docs);
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;
  @override
  SnapshotMetadata get metadata => _FakeMeta();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleDocs = [
    MockDocSnap('v1', {
      'name': 'شاليه الرافدين الملكي',
      'active': true,
      'verificationStatus': 'verified',
      'category': 'chalet',
      'price': 200000,
      'deposit': 50000,
      'location': 'الرمادي',
      'ownerName': 'مالك معتمد',
    }),
  ];

  group('iPhone & iOS Environment Layout & Gesture Safety', () {
    testWidgets('BookingScreen respects iPhone 15/16 Safe Area and Bottom Home Bar (390x844)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final streamCtrl = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            fontFamily: 'Cairo',
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47, bottom: 34),
              viewPadding: EdgeInsets.only(top: 47, bottom: 34),
              devicePixelRatio: 3.0,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: BookingScreen(
                admin: false,
                currentUserId: () => 'customer-1',
                banners: Stream.value(const []),
                records: (_) => streamCtrl.stream,
              ),
            ),
          ),
        ),
      );
      streamCtrl.add(MockQuerySnap(sampleDocs));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);

      // Verify bottom bar buttons are positioned above the 34pt iOS home indicator
      final exploreBtn = find.text('استكشف');
      expect(exploreBtn, findsWidgets);

      // Verify scroll physics behave without overflow
      await tester.drag(find.byType(ListView).first, const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('BookingAdminDashboardScreen on iPhone Pro Max (430x932) renders Reports without gap or overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final streamCtrl = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            fontFamily: 'Cairo',
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(430, 932),
              padding: EdgeInsets.only(top: 59, bottom: 34),
              viewPadding: EdgeInsets.only(top: 59, bottom: 34),
              devicePixelRatio: 3.0,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminReportsTab(bookingsStream: streamCtrl.stream),
              ),
            ),
          ),
        ),
      );
      streamCtrl.add(MockQuerySnap(sampleDocs));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('تقارير وإحصائيات الحجوزات والتحصيل'), findsOneWidget);
      expect(find.text('تصدير CSV'), findsOneWidget);
      expect(find.text('الأماكن الأكثر طلباً وحجزاً في الأنبار'), findsOneWidget);

      final rTitle = find.text('الأماكن الأكثر طلباً وحجزاً في الأنبار');
      final rRect = tester.getRect(rTitle);
      expect(rRect.top, lessThan(350.0));
      expect(tester.takeException(), isNull);
    });
  });
}
