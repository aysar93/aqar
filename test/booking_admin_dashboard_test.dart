import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aqar/bookings/admin/booking_admin_theme.dart';
import 'package:aqar/bookings/admin/booking_admin_dashboard_screen.dart';
import 'package:aqar/bookings/admin/tabs/booking_admin_bookings_tab.dart';

final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookingAdminTheme & Visual Identity Tests', () {
    test(
      'theme colors strictly adhere to the dark navy and restrained gold identity',
      () {
        expect(BookingAdminTheme.bgPrimary, const Color(0xFF0F172A));
        expect(BookingAdminTheme.surfaceCard, const Color(0xFF1E293B));
        expect(BookingAdminTheme.surfaceAlt, const Color(0xFF162238));
        expect(BookingAdminTheme.gold, const Color(0xFFD4AF37));
        expect(BookingAdminTheme.textPrimary, const Color(0xFFF8FAFC));
        expect(BookingAdminTheme.iconColor, const Color(0xFFE2E8F0));
        expect(BookingAdminTheme.iconMuted, const Color(0xFF94A3B8));
      },
    );

    testWidgets(
      'BookingAdminStatusBadge renders proper Arabic labels and colors',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  BookingAdminStatusBadge(status: 'confirmed'),
                  BookingAdminStatusBadge(status: 'requested'),
                  BookingAdminStatusBadge(status: 'payment_review'),
                  BookingAdminStatusBadge(status: 'cancelled'),
                  BookingAdminStatusBadge(status: 'needs_revision'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('مؤكد'), findsOneWidget);
        expect(find.text('بانتظار المالك'), findsOneWidget);
        expect(find.text('مراجعة العربون'), findsOneWidget);
        expect(find.text('ملغي'), findsOneWidget);
        expect(find.text('إعادة للمالك للتعديل'), findsOneWidget);
      },
    );

    testWidgets(
      'BookingAdminStatCard renders unified muted silver icons and values',
      (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookingAdminStatCard(
                title: 'إجمالي الحجوزات',
                value: '128',
                subtitle: 'كل الطلبات المسجلة',
                icon: Icons.calendar_month_outlined,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.text('إجمالي الحجوزات'), findsOneWidget);
        expect(find.text('128'), findsOneWidget);
        expect(find.text('كل الطلبات المسجلة'), findsOneWidget);
        expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);

        await tester.tap(find.byType(BookingAdminStatCard));
        expect(tapped, isTrue);
      },
    );
  });

  group('BookingAdminDashboardScreen Shell, RTL & Responsive Tests', () {
    testWidgets(
      'renders shell with RTL directionality, AppBar, Staging badge, and drawer items on small (320x640) and large (1280x900) screens without overflow',
      (tester) async {
        final emptyStream =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast()
                .stream;

        for (final size in [const Size(320, 640), const Size(1280, 900)]) {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MaterialApp(
              home: BookingAdminDashboardScreen(
                bookingsStream: emptyStream,
                venuesStream: emptyStream,
                reelsStream: emptyStream,
                reportsStream: emptyStream,
                auditStream: emptyStream,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);

          final dir = tester.widget<Directionality>(
            find.descendant(
              of: find.byType(BookingAdminDashboardScreen),
              matching: find.byType(Directionality),
            ).first,
          );
          expect(dir.textDirection, TextDirection.rtl);

          expect(find.textContaining('لوحة إدارة الحجوزات'), findsWidgets);
          expect(find.textContaining('Staging'), findsWidgets);
          expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
          expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
        }

        // Open Navigation Drawer
        final menuBtn = find.byIcon(Icons.menu_rounded);
        await tester.tap(menuBtn);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('الرئيسية والإحصائيات'), findsWidgets);
        expect(find.text('إدارة الحجوزات'), findsWidgets);
        expect(find.text('إدارة الأماكن'), findsWidgets);
        expect(find.text('إدارة ريلز الحجوزات'), findsWidgets);
        expect(find.text('إدارة المدفوعات'), findsWidgets);
        expect(find.text('التقارير والتحليل'), findsWidgets);
        expect(find.text('الصلاحيات وسجل العمليات'), findsWidgets);
        expect(find.text('الرجوع للوحة الإدارة العامة'), findsOneWidget);

        await tester.tap(find.descendant(
          of: find.byType(Drawer),
          matching: find.text('إدارة المدفوعات'),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Deposit Receipt Verification Tests (Display, Loading, Failure, Missing, Unauthorized, Review)', () {
    testWidgets(
      'BookingAdminReceiptViewer handles loading, valid image display, and zoom modal for authorized user',
      (tester) async {
        final completer = Completer<Uint8List?>();

        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminReceiptViewer(
                  receiptPath: 'booking_receipts/b101/u1/receipt.png',
                  isAuthorized: true,
                  receiptLoader: (_) => completer.future,
                ),
              ),
            ),
          ),
        );

        // 1. Loading state
        expect(find.text('جارٍ تحميل صورة الإيصال المالي...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // 2. Complete with valid PNG bytes
        completer.complete(_validPngBytes);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(Image), findsOneWidget);
        expect(find.text('تكبير ومعاينة الإيصال الكامل'), findsOneWidget);

        // 3. Open zoom dialog
        await tester.tap(find.text('تكبير ومعاينة الإيصال الكامل'));
        await tester.pumpAndSettle();
        expect(find.text('معاينة إيصال العربون المالي'), findsOneWidget);
      },
    );

    testWidgets(
      'BookingAdminReceiptViewer handles missing receipt, load failure with retry, and unauthorized access',
      (tester) async {
        // 1. Missing receipt (empty path)
        await tester.pumpWidget(
          const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminReceiptViewer(
                  receiptPath: '',
                  isAuthorized: true,
                ),
              ),
            ),
          ),
        );
        expect(find.text('لا يوجد إيصال تحويل مرفوع لهذا الحجز'), findsOneWidget);

        // 2. Unauthorized user flag
        await tester.pumpWidget(
          const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminReceiptViewer(
                  receiptPath: 'booking_receipts/b101/u1/receipt.png',
                  isAuthorized: false,
                ),
              ),
            ),
          ),
        );
        expect(
          find.text('لا تملك صلاحية عرض إيصال هذا الحجز (غير مخوّل)'),
          findsOneWidget,
        );

        // 3. Storage permission-denied error
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminReceiptViewer(
                  receiptPath: 'booking_receipts/b101/u1/receipt.png',
                  isAuthorized: true,
                  receiptLoader: (_) async => throw FirebaseException(
                    plugin: 'firebase_storage',
                    code: 'unauthorized',
                    message: 'User is not authorized',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('لا تملك صلاحية عرض إيصال هذا الحجز (غير مخوّل)'),
          findsOneWidget,
        );

        // 4. Load failure + retry recovery
        int attempts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminReceiptViewer(
                  receiptPath: 'booking_receipts/b101/u1/receipt_retry.png',
                  isAuthorized: true,
                  receiptLoader: (_) async {
                    attempts++;
                    if (attempts == 1) {
                      throw Exception('network_timeout');
                    }
                    return _validPngBytes;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('تعذر تحميل أو عرض صورة الإيصال المالي'),
          findsOneWidget,
        );
        expect(find.text('إعادة المحاولة'), findsOneWidget);

        await tester.tap(find.text('إعادة المحاولة'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets(
      'BookingAdminDetailsSheet enforces authorization, blocks self-review by booking parties, and allows independent reviewer to approve or reject deposit receipt',
      (tester) async {
        final calls = <Map<String, dynamic>>[];
        final bookingData = <String, dynamic>{
          'status': 'payment_review',
          'venueName': 'شاليه الرافدين الملكي',
          'customerName': 'أحمد محمود الدليمي',
          'customerPhone': '07801234567',
          'ownerName': 'أبو محمد الدليمي',
          'ownerId': 'owner_1',
          'customerId': 'customer_1',
          'total': 200000,
          'deposit': 50000,
          'remaining': 150000,
          'paymentMethod': 'qicard',
          'transactionNumber': 'TX-998877',
          'receiptPath': 'booking_receipts/b101/customer_1/receipt.png',
          'version': 3,
        };

        // Case A: Unauthorized stranger blocked from viewing booking details & receipt
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminDetailsSheet(
                  bookingId: 'b101',
                  initialData: bookingData,
                  bookingDocStream: const Stream.empty(),
                  auditStream: const Stream.empty(),
                  currentUid: 'stranger_99',
                  isAdminOrFinance: false,
                  receiptLoader: (_) async => _validPngBytes,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('لا تملك صلاحية عرض إيصال هذا الحجز (غير مخوّل)'),
          findsOneWidget,
        );
        expect(find.text('اعتماد العربون وتأكيد الحجز'), findsNothing);
        expect(find.text('TX-998877'), findsNothing);

        // Case B: Booking owner cannot self-approve deposit receipt
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminDetailsSheet(
                  bookingId: 'b101',
                  initialData: bookingData,
                  bookingDocStream: const Stream.empty(),
                  auditStream: const Stream.empty(),
                  currentUid: 'owner_1',
                  isAdminOrFinance: true,
                  receiptLoader: (_) async => _validPngBytes,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(
          find.text('يتطلب اعتماد أو رفض العربون مراجعاً مالياً مستقلاً عن طرفي الحجز.'),
          findsOneWidget,
        );
        expect(find.text('اعتماد العربون وتأكيد الحجز'), findsNothing);

        // Case C: Independent admin/finance reviewer views receipt, approves ('confirmPayment'), and rejects ('rejectPayment')
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BookingAdminDetailsSheet(
                  bookingId: 'b101',
                  initialData: bookingData,
                  bookingDocStream: const Stream.empty(),
                  auditStream: const Stream.empty(),
                  currentUid: 'finance_reviewer_1',
                  isAdminOrFinance: true,
                  receiptLoader: (_) async => _validPngBytes,
                  callHook: (name, data) async {
                    calls.add({'name': name, 'data': data});
                    return {'ok': true};
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);
        expect(find.text('TX-998877'), findsOneWidget);

        // Scroll to action buttons and approve
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('اعتماد العربون وتأكيد الحجز'));
        await tester.tap(find.text('اعتماد العربون وتأكيد الحجز'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('نعم، اعتمد الحجز'));
        await tester.pumpAndSettle();

        expect(calls.length, 1);
        expect(calls.first['name'], 'actOnBooking');
        expect(calls.first['data']['bookingId'], 'b101');
        expect(calls.first['data']['action'], 'confirmPayment');
        expect(calls.first['data']['version'], 3);

        // Reject with reason
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('رفض الإيصال المالي'));
        await tester.tap(find.text('رفض الإيصال المالي'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'رقم الحوالة غير مطابق لكشف الحساب');
        await tester.tap(find.text('تأكيد'));
        await tester.pumpAndSettle();

        expect(calls.length, 2);
        expect(calls.last['data']['action'], 'rejectPayment');
        expect(calls.last['data']['reason'], 'رقم الحوالة غير مطابق لكشف الحساب');
        expect(calls.last['data']['version'], 3);
      },
    );
  });

  group('Data Sanitization & Post-Sanitization Statistical Consistency Tests', () {
    test(
      'BookingAdminDataSanitizer is strictly non-destructive (does not mutate input maps) and produces 100% consistent counts and categories',
      () {
        final rawFirestoreDocs = <Map<String, dynamic>>[
          {
            '_id': 'pub_1',
            'name': 'شاليه الرافدين الملكي - Staging',
            'location': 'STAGING',
            'ownerName': 'اختبار owner — بيئة Staging',
            'category': 'chalet',
            'active': true,
            'verificationStatus': 'verified',
          },
          {
            '_id': 'pub_2',
            'name': 'شاليه الفرات الملكي - Staging',
            'location': 'STAGING',
            'ownerName': 'test_owner',
            'category': 'chalet',
            'active': true,
            'verificationStatus': 'verified',
          },
          for (int i = 0; i < 12; i++)
            {
              '_id': 'syn_$i',
              'name': 'Android 13 media acceptance synthetic $i',
              'location': 'UAT Anbar Synthetic',
              'ownerName': 'UAT Owner $i',
              'category': 'chalet',
              'active': false,
              'verificationStatus': i.isEven ? 'verified' : 'pending',
            },
        ];

        final snapshotBefore = jsonEncode(rawFirestoreDocs);
        final cleanList = BookingAdminDataSanitizer.prepareCleanVenuesList(rawFirestoreDocs);

        // 1. Verify zero mutation of source records
        expect(jsonEncode(rawFirestoreDocs), snapshotBefore);

        // 2. Verify count consistency (2 published + 6 pending = 8 total)
        expect(cleanList.length, 8);
        final publishedCount = cleanList.where((v) => v['active'] == true).length;
        final pendingCount = cleanList.where((v) {
          final vs = (v['verificationStatus'] ?? 'pending').toString();
          return vs == 'pending' || (v['active'] != true && vs != 'verified');
        }).length;
        expect(publishedCount, 2);
        expect(pendingCount, 6);
        expect(publishedCount + pendingCount, cleanList.length);

        // 3. Verify category alignment with sanitized Arabic names (4 chalets, 2 farms, 2 halls)
        final chalets = cleanList.where((v) => v['category'] == 'chalet').length;
        final farms = cleanList.where((v) => v['category'] == 'farm').length;
        final halls = cleanList.where((v) => v['category'] == 'hall').length;
        expect(chalets, 4);
        expect(farms, 2);
        expect(halls, 2);
        expect(chalets + farms + halls, cleanList.length);
      },
    );
  });
}
