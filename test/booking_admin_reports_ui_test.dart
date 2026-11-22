import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/admin/booking_admin_dashboard_screen.dart';
import 'package:aqar/bookings/admin/tabs/booking_admin_reports_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleDocs = [
    MockDocSnap('b1', {
      'total': 180000,
      'deposit': 60000,
      'status': 'confirmed',
      'venueName': 'شاليه الرافدين الملكي',
      'category': 'chalet',
      'createdAt': Timestamp.now(),
    }),
    MockDocSnap('b2', {
      'total': 250000,
      'deposit': 80000,
      'status': 'confirmed',
      'venueName': 'مزرعة الفرات السياحية',
      'category': 'farm',
      'createdAt': Timestamp.now(),
    }),
    MockDocSnap('b3', {
      'total': 400000,
      'deposit': 150000,
      'status': 'completed',
      'venueName': 'قاعة قصر الأمراء',
      'category': 'hall',
      'createdAt': Timestamp.now(),
    }),
  ];

  group('BookingAdminReportsTab Layout & Responsiveness', () {
    testWidgets('renders reports immediately at top on small screen (320x640) without empty gap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final streamCtrl = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BookingAdminReportsTab(bookingsStream: streamCtrl.stream),
            ),
          ),
        ),
      );
      streamCtrl.add(MockQuerySnap(sampleDocs));
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Unified compact header is present
      expect(find.text('تقارير وإحصائيات الحجوزات والتحصيل'), findsOneWidget);
      expect(find.text('تصدير CSV'), findsOneWidget);

      // 2. Report title is visible in upper half of the screen (< 350px)
      final rTitle = find.text('الأماكن الأكثر طلباً وحجزاً في الأنبار');
      expect(rTitle, findsOneWidget);
      final rRect = tester.getRect(rTitle);
      expect(rRect.top, lessThan(350.0));

      // 3. Ranked venue items are visible immediately
      expect(find.text('شاليه الرافدين الملكي'), findsOneWidget);
      expect(find.text('مزرعة الفرات السياحية'), findsOneWidget);

      // 4. Natural scrolling works smoothly
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('نسب الحجوزات حسب نوع المنشأة'), findsOneWidget);
    });

    testWidgets('renders properly on standard phone (390x844) in dark mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final streamCtrl = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BookingAdminReportsTab(bookingsStream: streamCtrl.stream),
            ),
          ),
        ),
      );
      streamCtrl.add(MockQuerySnap(sampleDocs));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('تقارير وإحصائيات الحجوزات والتحصيل'), findsOneWidget);
      expect(find.text('الأماكن الأكثر طلباً وحجزاً في الأنبار'), findsOneWidget);
      expect(find.text('شاليه الرافدين الملكي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on tablet/desktop screen (1280x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final streamCtrl = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BookingAdminReportsTab(bookingsStream: streamCtrl.stream),
            ),
          ),
        ),
      );
      streamCtrl.add(MockQuerySnap(sampleDocs));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('تقارير وإحصائيات الحجوزات والتحصيل'), findsOneWidget);
      expect(find.text('الأماكن الأكثر طلباً وحجزاً في الأنبار'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles empty data state cleanly without broken layout', (tester) async {
      final streamCtrl = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BookingAdminReportsTab(bookingsStream: streamCtrl.stream),
            ),
          ),
        ),
      );
      streamCtrl.add(MockQuerySnap([]));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('تقارير وإحصائيات الحجوزات والتحصيل'), findsOneWidget);
      expect(find.text('إجمالي البيانات المشمولة بالتحليل: 0 حجز'), findsOneWidget);
      expect(find.text('لا توجد بيانات حجوزات لتصنيف الأماكن.'), findsOneWidget);
      expect(find.text('لا توجد حجوزات في هذه الفترة.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles error state cleanly', (tester) async {
      final streamCtrl = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BookingAdminReportsTab(bookingsStream: streamCtrl.stream),
            ),
          ),
        ),
      );
      streamCtrl.addError('Firestore permission denied');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('حدث خطأ في تحميل بيانات التقارير'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BookingAdminDashboardScreen Tab Switching & Isolation', () {
    testWidgets('navigating to reports tab starts at top without inherited offset', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final streamCtrl = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BookingAdminDashboardScreen(
            bookingsStream: streamCtrl.stream,
            venuesStream: streamCtrl.stream,
            reelsStream: streamCtrl.stream,
            reportsStream: streamCtrl.stream,
            auditStream: streamCtrl.stream,
          ),
        ),
      );
      streamCtrl.add(MockQuerySnap(sampleDocs));
      await tester.pump(const Duration(milliseconds: 200));

      // Open drawer and navigate to 'التقارير والتحليل'
      final menuBtn = find.byIcon(Icons.menu_rounded);
      await tester.tap(menuBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final reportsItem = find.descendant(
        of: find.byType(Drawer),
        matching: find.text('التقارير والتحليل'),
      );
      expect(reportsItem, findsOneWidget);
      await tester.tap(reportsItem);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Reports header and content are immediately visible
      expect(find.text('تقارير وإحصائيات الحجوزات والتحصيل'), findsOneWidget);
      expect(find.text('الأماكن الأكثر طلباً وحجزاً في الأنبار'), findsOneWidget);

      // Verify header top position is right below AppBar (around 120px)
      final header = find.text('تقارير وإحصائيات الحجوزات والتحصيل');
      final pos = tester.getRect(header);
      expect(pos.top, lessThan(200.0));
    });
  });
}