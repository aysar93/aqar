import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_receipt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate verified PDF from exact Staging booking document', () async {
    // 1. Exact booking from Staging Firestore (IT25G8XYug2xcX39GQvR, 21/11/2026 Morning)
    final realStagingBooking = {
      'id': 'wOXnCid7efRe7sdLJFZUGueCG7j2_1794669200531091',
      'venueId': 'IT25G8XYug2xcX39GQvR',
      'ownerId': 'Q1qjnkQf29W47DEk3GKAB9sZDPc2',
      'customerId': 'wOXnCid7efRe7sdLJFZUGueCG7j2',
      'customerName': 'Guest UAT Test',
      'customerPhone': '07700000000',
      'venueName': 'Chalet-UAT-Updated123-Test',
      'venueLocation': 'Al-Habbaniyah — مركز قضاء الرمادي',
      'start': 1794669200531,
      'end': 1794677292116,
      'status': 'held',
      'total': 75000,
      'deposit': 50000,
      'paid': 0,
      'remaining': 75000,
      'pricing': {
        'id': 'morning',
        'name': 'الفترة الصباحية',
        'priceBeforeDiscount': 100000,
        'discountPercent': 25,
      },
      'terms': 'الالتزام بأوقات الدخول والمغادرة المحددة والحفاظ على نظافة المسبح والحديقة.',
      'checkInCode': '994821',
    };

    final venueSnapshot = {
      'name': 'Chalet-UAT-Updated123-Test',
      'location': 'Al-Habbaniyah — مركز قضاء الرمادي',
      'deposit': 50000,
      'securityDeposit': 0,
    };

    final pdfBytes = await BookingReceiptService.generateReceiptPdf(
      booking: realStagingBooking,
      bookingId: realStagingBooking['id'] as String,
      venue: venueSnapshot,
    );

    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.length, greaterThan(15000));

    final outPath = r'C:\Users\AL-NOOR\.gemini\antigravity\brain\110efef9-b0d8-4732-b69f-01014ab4fb7f\staging_real_receipt_output.pdf';
    await File(outPath).writeAsBytes(pdfBytes);
    expect(await File(outPath).exists(), isTrue);
  });

  test('Verify legacy booking compatibility without total field', () async {
    final legacyBooking = {
      'id': 'legacy_booking_999',
      'price': 120000,
      'deposit': 50000,
      'status': 'confirmed',
      'customerName': 'سعدون جابر',
      'venueName': 'شاليه الحبانية القديم',
    };

    final pdfBytes = await BookingReceiptService.generateReceiptPdf(
      booking: legacyBooking,
      bookingId: 'legacy_booking_999',
    );

    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.length, greaterThan(10000));
  });
}
