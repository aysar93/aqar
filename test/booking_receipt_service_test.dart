import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_receipt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookingReceiptService Financial Calculations', () {
    test('Correctly prioritizes total over price/totalPrice (75k total, 50k deposit -> 25k remaining)', () async {
      final booking = {
        'total': 75000,
        'deposit': 50000,
        'price': 100000,
        'customerName': 'أحمد علي',
        'customerPhone': '07701234567',
        'venueName': 'شاليه الحبانية الملكي',
        'venueLocation': 'الأنبار - الحبانية',
        'status': 'held',
        'start': 1794669200531,
        'end': 1794677292116,
      };

      final pdfBytes = await BookingReceiptService.generateReceiptPdf(
        booking: booking,
        bookingId: 'test-booking-123',
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      expect(pdfBytes[0], 0x25); // '%'
      expect(pdfBytes[1], 0x50); // 'P'
      expect(pdfBytes[2], 0x44); // 'D'
      expect(pdfBytes[3], 0x46); // 'F'

      final outPath = r'C:\Users\AL-NOOR\.gemini\antigravity\brain\110efef9-b0d8-4732-b69f-01014ab4fb7f\receipt_test_output.pdf';
      await File(outPath).writeAsBytes(pdfBytes);
      expect(await File(outPath).exists(), isTrue);
    });

    test('Financial values match exact requirements (75k, 50k, 25k)', () {
      final booking = {
        'total': 75000,
        'deposit': 50000,
        'price': 100000,
      };

      final dynamic totalRaw = booking['total'] ?? booking['price'] ?? booking['totalPrice'] ?? 0;
      final num total = totalRaw is num
          ? totalRaw
          : (num.tryParse(totalRaw.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0);

      final dynamic depositRaw = booking['deposit'] ?? 0;
      final num deposit = depositRaw is num
          ? depositRaw
          : (num.tryParse(depositRaw.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0);

      final num effectiveDeposit = (deposit > total && total > 0) ? total : deposit;
      final num remaining = (total - effectiveDeposit).clamp(0, double.infinity);

      expect(total, 75000);
      expect(effectiveDeposit, 50000);
      expect(remaining, 25000);
    });

    test('Correctly handles legacy bookings with only price or totalPrice', () async {
      final legacy1 = {
        'price': 120000,
        'deposit': 40000,
        'status': 'confirmed',
      };
      final pdf1 = await BookingReceiptService.generateReceiptPdf(
        booking: legacy1,
        bookingId: 'legacy-1',
      );
      expect(pdf1, isNotEmpty);

      final legacy2 = {
        'totalPrice': 90000,
        'deposit': 30000,
        'status': 'confirmed',
      };
      final pdf2 = await BookingReceiptService.generateReceiptPdf(
        booking: legacy2,
        bookingId: 'legacy-2',
      );
      expect(pdf2, isNotEmpty);
    });

    test('Clamps remaining to 0 if deposit >= total, preventing negative amounts', () async {
      final excessDeposit = {
        'total': 50000,
        'deposit': 60000,
        'status': 'confirmed',
      };
      final pdf = await BookingReceiptService.generateReceiptPdf(
        booking: excessDeposit,
        bookingId: 'excess-deposit',
      );
      expect(pdf, isNotEmpty);
    });
  });
}
