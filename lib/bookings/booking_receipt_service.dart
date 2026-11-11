import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'booking_venue_details.dart';
import 'booking_widgets.dart';

class BookingReceiptService {
  /// Generate a high quality verified PDF receipt for a booking
  static Future<Uint8List> generateReceiptPdf({
    required Map<String, dynamic> booking,
    required String bookingId,
    Map<String, dynamic>? venue,
  }) async {
    final pdf = pw.Document();

    // Load bundled Arabic fonts for offline-safe, high-fidelity rendering
    pw.Font arabicFont;
    pw.Font arabicBoldFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
      arabicFont = pw.Font.ttf(fontData);
      arabicBoldFont = pw.Font.ttf(boldData);
    } catch (_) {
      try {
        final cairoData = await rootBundle.load('assets/fonts/Cairo.ttf');
        arabicFont = pw.Font.ttf(cairoData);
        arabicBoldFont = pw.Font.ttf(cairoData);
      } catch (_) {
        arabicFont = await PdfGoogleFonts.cairoRegular();
        arabicBoldFont = await PdfGoogleFonts.cairoBold();
      }
    }

    final vName = venue?['name']?.toString() ??
        booking['venueName']?.toString() ??
        'شاليه / منتجع بالأنبار';
    final vLoc = venue?['location']?.toString() ??
        booking['venueLocation']?.toString() ??
        'محافظة الأنبار';
    final customerName = booking['customerName']?.toString() ??
        booking['guestName']?.toString() ??
        'ضيف معتمد';
    final customerPhone = booking['customerPhone']?.toString() ??
        booking['phone']?.toString() ??
        '';

    final total = booking['price'] ?? booking['totalPrice'] ?? 0;
    final deposit = booking['deposit'] ?? 0;
    final remaining = (total is num && deposit is num) ? (total - deposit).clamp(0, double.infinity) : 0;
    final securityDeposit = booking['securityDeposit'] ?? venue?['securityDeposit'] ?? 0;
    final status = booking['status']?.toString() ?? 'confirmed';
    final statusArabic = {
      'requested': 'قيد المراجعة',
      'held': 'معلق بانتظار العربون',
      'payment_review': 'مراجعة الدفع',
      'confirmed': 'مؤكد ومعتمد',
      'arrived': 'تم الوصول',
      'completed': 'مكتمل',
      'cancelled': 'ملغى',
      'rejected': 'مرفوض',
    }[status] ?? 'معتمد';

    // Dates in Baghdad Time (UTC+3)
    DateTime? startDate;
    DateTime? endDate;
    final rawStart = booking['start'];
    final rawEnd = booking['end'];
    if (rawStart is num) startDate = DateTime.fromMillisecondsSinceEpoch(rawStart.toInt());
    if (rawEnd is num) endDate = DateTime.fromMillisecondsSinceEpoch(rawEnd.toInt());
    final startBaghdad = startDate?.toUtc().add(const Duration(hours: 3));
    final endBaghdad = endDate?.toUtc().add(const Duration(hours: 3));

    final dateStr = startBaghdad != null
        ? '${startBaghdad.year}/${startBaghdad.month.toString().padLeft(2, '0')}/${startBaghdad.day.toString().padLeft(2, '0')}'
        : 'غير محدد';
    final checkInStr = startBaghdad != null ? bookingClock12(startBaghdad.hour * 60 + startBaghdad.minute) : '-';
    final checkOutStr = endBaghdad != null ? bookingClock12(endBaghdad.hour * 60 + endBaghdad.minute) : '-';

    // Safe QR payload for gate check-in without exposing private secrets
    final qrPayload = 'https://aqar-anbar.iq/verify-booking?id=$bookingId&code=${booking['checkInCode'] ?? bookingId.hashCode.abs()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBoldFont),
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#D4AF37'), width: 2),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('عقارات الأنبار',
                            style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#0F172A'))),
                        pw.SizedBox(height: 4),
                        pw.Text('منصة الحجوزات العقارية والاستراحات السياحية',
                            style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#64748B'))),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#D4AF37'),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text('إيصال حجز إلكتروني',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1.5, height: 24),

                // 2. Booking Reference & Status Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('رقم الحجز المرجعي:',
                              style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                          pw.SizedBox(height: 2),
                          pw.Text(bookingId,
                              textDirection: pw.TextDirection.ltr,
                              style: pw.TextStyle(
                                  fontSize: 15,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#0F172A'))),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: status == 'confirmed' || status == 'completed'
                              ? PdfColor.fromHex('#DCFCE7')
                              : PdfColor.fromHex('#FEF3C7'),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(
                            color: status == 'confirmed' || status == 'completed'
                                ? PdfColor.fromHex('#16A34A')
                                : PdfColor.fromHex('#D97706'),
                          ),
                        ),
                        child: pw.Text(statusArabic,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: status == 'confirmed' || status == 'completed'
                                  ? PdfColor.fromHex('#15803D')
                                  : PdfColor.fromHex('#B45309'),
                            )),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // 3. Venue & Guest Details
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Venue Info Box
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('تفاصيل المكان المحجوز',
                                style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#D4AF37'))),
                            pw.SizedBox(height: 8),
                            pw.Text(vName,
                                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text('الموقع: $vLoc',
                                style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569'))),
                            pw.SizedBox(height: 4),
                            pw.Text('تاريخ الحجز: $dateStr',
                                style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569'))),
                            pw.Text('وقت الدخول: $checkInStr | وقت الخروج: $checkOutStr',
                                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 14),

                    // Guest Info Box
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('بيانات صاحب الحجز',
                                style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#D4AF37'))),
                            pw.SizedBox(height: 8),
                            pw.Text('الاسم: $customerName',
                                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                            if (customerPhone.isNotEmpty) ...[
                              pw.SizedBox(height: 4),
                              pw.Text('الهاتف: $customerPhone',
                                  textDirection: pw.TextDirection.ltr,
                                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569'))),
                            ],
                            pw.SizedBox(height: 4),
                            pw.Text('توقيت الاعتماد: توقيت بغداد (GMT+3)',
                                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),

                // 4. Financial Breakdown Table
                pw.Text('تفاصيل الحساب المالي المعتمد',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F172A'))),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('البند المالي',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('المبلغ بالدينار العراقي',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('حالة الدفع',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('السعر الإجمالي للحجز', style: const pw.TextStyle(fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(bookingMoney(total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('إجمالي القيمة', style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('العربون المدفوع (مقدم الحجز)', style: const pw.TextStyle(fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(bookingMoney(deposit), style: pw.TextStyle(color: PdfColor.fromHex('#16A34A'), fontWeight: pw.FontWeight.bold, fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('تم السداد إلكترونياً', style: pw.TextStyle(color: PdfColor.fromHex('#16A34A'), fontSize: 10))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('الرصيد المتبقي عند الوصول', style: const pw.TextStyle(fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(bookingMoney(remaining), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('يُسدد نقداً للمالك', style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                    if (securityDeposit != null && (securityDeposit is num ? securityDeposit > 0 : (num.tryParse(securityDeposit.toString()) ?? 0) > 0))
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('مبلغ التأمين (ضمان الأضرار)', style: const pw.TextStyle(fontSize: 11))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(bookingMoney(securityDeposit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('يُسترد عند تسليم المكان', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 18),

                // 5. QR Code & Verification Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 76,
                        height: 76,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrPayload,
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('رمز التحقق الرقمي السريع (QR Check-in)',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11,
                                    color: PdfColor.fromHex('#0F172A'))),
                            pw.SizedBox(height: 3),
                            pw.Text(
                                'أبرز هذا الرمز عند بوابة الدخول أو للمالك لمسحه والتحقق الفوري من صحة الحجز دون الحاجة لشبكة الإنترنت.',
                                style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#64748B'), height: 1.4)),
                            pw.SizedBox(height: 4),
                            pw.Text('هذا الإيصال وثيقة إلكترونية رسمية صادرة عن نظام عقارات الأنبار.',
                                style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#94A3B8'))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or open print preview dialog directly
  static Future<void> printReceipt({
    required Map<String, dynamic> booking,
    required String bookingId,
    Map<String, dynamic>? venue,
  }) async {
    final bytes = await generateReceiptPdf(
      booking: booking,
      bookingId: bookingId,
      venue: venue,
    );
    await Printing.layoutPdf(
      name: 'إيصال_حجز_$bookingId.pdf',
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  /// Share PDF receipt via WhatsApp, Mail, Files, or native share sheet
  static Future<void> shareReceipt({
    required Map<String, dynamic> booking,
    required String bookingId,
    Map<String, dynamic>? venue,
  }) async {
    final bytes = await generateReceiptPdf(
      booking: booking,
      bookingId: bookingId,
      venue: venue,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'ايصال_حجز_$bookingId.pdf',
    );
  }
}
