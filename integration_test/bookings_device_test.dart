import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aqar/bookings_test_main.dart' as app;
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'real Android local customer, calendar, owner, manual payment and administration',
      (tester) async {
    var surfaceConverted = false;
    Future<void> capture(String name) async {
      try {
        if (!surfaceConverted) {
          await binding.convertFlutterSurfaceToImage();
          surfaceConverted = true;
        }
        await tester.pump();
        final bytes = await binding.takeScreenshot(name);
        final directory = await getApplicationDocumentsDirectory();
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
      } catch (e) {
        debugPrint('Optional screenshot unavailable: $name');
      }
    }

    Future<void> waitFor(Finder finder) async {
      for (var attempt = 0; attempt < 120; attempt++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (finder.evaluate().isNotEmpty) return;
      }
      expect(finder, findsWidgets,
          reason: find
              .byType(Text)
              .evaluate()
              .map((e) => (e.widget as Text).data ?? '')
              .join(' | '));
    }

    expect(appFlavor, 'bookingsTest');
    await app.main();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.text('الزبون'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await waitFor(find.byType(BookingVenueCard));
    await tester.enterText(find.byType(TextField).first, 'الانبار');
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    await tester.pumpAndSettle();
    await waitFor(find.byType(BookingVenueCard));
    await tester.ensureVisible(find.text('السعر والسعة والمرافق'));
    await tester.tap(find.text('السعر والسعة والمرافق'));
    await tester.pumpAndSettle();
    expect(find.text('تصفية النتائج'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    await tester.pumpAndSettle();
    await waitFor(find.byType(BookingVenueCard));
    await tester.ensureVisible(find.byType(BookingVenueCard).first);
    await tester.tap(find.byType(BookingVenueCard).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('صباحي').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.byTooltip('الشهر التالي'), findsOneWidget);
    await capture('phone-calendar');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final date = DateTime.now().toUtc().add(const Duration(days: 6));
    final start =
        DateTime.utc(date.year, date.month, date.day, 5).millisecondsSinceEpoch;
    final request = await bookingCall('requestBooking', {
      'venueId': 'test_chalet',
      'requestId': 'phone_${DateTime.now().microsecondsSinceEpoch}',
      'start': start,
      'end': start + 8 * 3600000,
      'shiftId': 'morning',
      'price': 100000,
      'deposit': 20000,
      'acceptedTerms': 'بيانات تجربة فقط. لا تحوّل أموالًا.',
      'cancellationPolicy': {
        'freeCancellationHours': 24,
        'lateRefundPercent': 50
      }
    });
    final id = request['id'] as String;
    Future<void> login(String role) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: '$role@test.invalid', password: 'AqarTest123!');
    }

    Future<void> screen(Widget home) async {
      await tester.pumpWidget(MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.lightTheme,
          home: Directionality(textDirection: TextDirection.rtl, child: home)));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }

    await login('owner');
    await screen(const BookingScreen());
    await bookingCall('actOnBooking', {'bookingId': id, 'action': 'approve'});
    await screen(BookingDetailsScreen(bookingId: id));
    await waitFor(find.textContaining('بانتظار العربون'));
    await login('customer');
    final path =
        'booking_receipts/$id/test_customer/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 32, 32),
        ui.Paint()..color = const ui.Color(0xffeeeeee));
    final image = await recorder.endRecording().toImage(32, 32);
    final pixels = await image.toByteData(format: ui.ImageByteFormat.png);
    await FirebaseStorage.instance.ref(path).putData(
        await FlutterImageCompress.compressWithList(
            pixels!.buffer.asUint8List(),
            minWidth: 32,
            minHeight: 32,
            format: CompressFormat.jpeg),
        SettableMetadata(contentType: 'image/jpeg'));
    image.dispose();
    await bookingCall('actOnBooking', {
      'bookingId': id,
      'action': 'submitPayment',
      'receiptPath': path,
      'method': 'qicard',
      'expectedNumber': '0000000000',
      'transactionNumber': 'phone_$id'
    });
    await login('reviewer');
    await screen(BookingDetailsScreen(bookingId: id));
    await bookingCall(
        'actOnBooking', {'bookingId': id, 'action': 'confirmPayment'});
    await login('customer');
    await screen(BookingDetailsScreen(bookingId: id));
    await waitFor(find.textContaining('حجز مؤكد'));
    await capture('phone-confirmed');
    final ticket = await bookingCall('openBookingSupportTicket', {
      'bookingId': id,
      'requestId': 'phone_$id',
      'subject': 'اختبار الهاتف',
      'message': 'طلب دعم اصطناعي'
    });
    await login('admin');
    await screen(const BookingScreen(admin: true));
    await capture('phone-admin');
    await bookingCall('updateBookingSupportTicket', {
      'ticketId': ticket['id'],
      'status': 'resolved',
      'response': 'تم التحقق في الاختبار'
    });
    await login('customer');
    await bookingCall('actOnBooking',
        {'bookingId': id, 'action': 'cancel', 'reason': 'تنظيف تجربة الهاتف'});
    await login('reviewer');
    await bookingCall('actOnBooking', {
      'bookingId': id,
      'action': 'settleRefund',
      'refundReference': 'test_$id'
    });
    await screen(BookingDetailsScreen(bookingId: id));
    expect(tester.takeException(), isNull);
    await FirebaseAuth.instance.signOut();
  }, timeout: const Timeout(Duration(minutes: 15)));
}
