import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_extras.dart';

void main() {
  group('BookingManualCheckInDialog Unit & Widget Tests', () {
    const testBookingId = 'booking_abc123';
    const validSecret =
        'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
    const validQrString = 'aqar-booking:$testBookingId:$validSecret';

    testWidgets('renders dialog with Arabic title, text field and action buttons',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingManualCheckInDialog(bookingId: testBookingId),
          ),
        ),
      );

      expect(find.text('إدخال رمز التحقق يدوياً'), findsOneWidget);
      expect(find.text('رمز التحقق'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('تحقق من الرمز'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('validates empty input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingManualCheckInDialog(bookingId: testBookingId),
          ),
        ),
      );

      await tester.tap(find.text('تحقق من الرمز'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال أو لصق رمز التحقق للمتابعة'), findsOneWidget);
    });

    testWidgets('validates prefix format (must start with aqar-booking:)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingManualCheckInDialog(bookingId: testBookingId),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'invalid-prefix:123:abc');
      await tester.tap(find.text('تحقق من الرمز'));
      await tester.pumpAndSettle();

      expect(find.text('صيغة الرمز غير صالحة. يجب أن يبدأ بـ aqar-booking:'),
          findsOneWidget);
    });

    testWidgets('validates matching bookingId', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingManualCheckInDialog(bookingId: testBookingId),
          ),
        ),
      );

      await tester.enterText(
          find.byType(TextField), 'aqar-booking:different_booking_id:$validSecret');
      await tester.tap(find.text('تحقق من الرمز'));
      await tester.pumpAndSettle();

      expect(find.text('هذا الرمز يخص حجزاً آخر؛ يرجى فتح الحجز الصحيح'), findsOneWidget);
    });

    testWidgets('validates hex secret length and characters (must be 64-hex)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingManualCheckInDialog(bookingId: testBookingId),
          ),
        ),
      );

      // Secret too short
      await tester.enterText(
          find.byType(TextField), 'aqar-booking:$testBookingId:tooshort123');
      await tester.tap(find.text('تحقق من الرمز'));
      await tester.pumpAndSettle();

      expect(find.text('رمز التحقق غير مكتمل أو تالف'), findsOneWidget);

      // Secret with invalid non-hex characters
      await tester.enterText(find.byType(TextField),
          'aqar-booking:$testBookingId:zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz');
      await tester.tap(find.text('تحقق من الرمز'));
      await tester.pumpAndSettle();

      expect(find.text('رمز التحقق غير مكتمل أو تالف'), findsOneWidget);
    });

    testWidgets(
        'submits valid code to callable, shows loading, and completes successfully',
        (tester) async {
      String? calledName;
      Map<String, dynamic>? calledParams;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => BookingManualCheckInDialog(
                      bookingId: testBookingId,
                      call: (name, params) async {
                        calledName = name;
                        calledParams = params;
                        return {'success': true};
                      },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('إدخال رمز التحقق يدوياً'), findsOneWidget);

      await tester.enterText(find.byType(TextField), validQrString);
      await tester.tap(find.text('تحقق من الرمز'));
      await tester.pumpAndSettle();

      expect(calledName, 'verifyBookingCheckInCode');
      expect(calledParams?['bookingId'], testBookingId);
      expect(calledParams?['code'], validQrString);
      // Dialog should be dismissed on success
      expect(find.text('إدخال رمز التحقق يدوياً'), findsNothing);
    });

    testWidgets('handles backend error gracefully without leaking internals',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingManualCheckInDialog(
              bookingId: testBookingId,
              call: (name, params) async {
                throw Exception('Backend permission denied or invalid code');
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), validQrString);
      await tester.tap(find.text('تحقق من الرمز'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('تعذر اعتماد الرمز'), findsOneWidget);
    });
  });

  group('FCM Payload & Booking ID extraction tests', () {
    String? extractBookingId(Map<String, dynamic>? data) {
      if (data == null) return null;
      final raw = data['bookingId'] ?? data['id'];
      if (raw == null) return null;
      final idStr = raw.toString().trim();
      if (idStr.isEmpty || idStr.contains('/') || idStr.length > 200) {
        return null;
      }
      if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(idStr)) return null;
      return idStr;
    }

    test('extracts valid bookingId from bookingId field', () {
      expect(extractBookingId({'bookingId': 'bk_12345'}), 'bk_12345');
      expect(extractBookingId({'bookingId': ' booking_with_spaces '}),
          'booking_with_spaces');
    });

    test('extracts valid bookingId from fallback id field', () {
      expect(extractBookingId({'id': 'bk_from_id'}), 'bk_from_id');
    });

    test('rejects malicious, empty, or path-traversal IDs', () {
      expect(extractBookingId(null), isNull);
      expect(extractBookingId({}), isNull);
      expect(extractBookingId({'bookingId': ''}), isNull);
      expect(extractBookingId({'bookingId': '   '}), isNull);
      expect(extractBookingId({'bookingId': 'bookings/evil_path'}), isNull);
      expect(extractBookingId({'bookingId': '../../etc/passwd'}), isNull);
      expect(extractBookingId({'bookingId': 'bad char;DROP TABLE'}), isNull);
      expect(extractBookingId({'bookingId': 'a' * 201}), isNull);
    });
  });
}
