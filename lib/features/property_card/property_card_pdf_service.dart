import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'property_card_data.dart';

class PropertyCardPdfService {
  static Future<Uint8List> build(PropertyCardData data) async {
    final document = pw.Document();
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final image = await _loadImage(data.imageUrl);
    final price = NumberFormat('#,###').format(data.price);
    final status = _statusLabel(data.availabilityStatus);
    final details = <String>[
      if (data.area > 0) 'المساحة: ${data.area} م²',
      if (data.rooms > 0) 'غرف النوم: ${data.rooms}',
      if (data.bathrooms > 0) 'الحمامات: ${data.bathrooms}',
      if (data.floors != null && data.floors! > 0) 'الطوابق: ${data.floors}',
      if (data.documentType.trim().isNotEmpty) 'السند: ${data.documentType}',
    ];

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xff0f172a),
              borderRadius: pw.BorderRadius.circular(18),
              border: pw.Border.all(color: PdfColor.fromInt(0xffd4af37), width: 1.2),
            ),
            child: pw.Column(children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xff1e293b),
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(17), topRight: pw.Radius.circular(17),
                  ),
                ),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('عقارات الأنبار', style: pw.TextStyle(color: PdfColor.fromInt(0xffd4af37), font: bold, fontSize: 18)),
                  pw.Text('رقم العقار #${data.number}', style: pw.TextStyle(color: PdfColors.white, font: bold, fontSize: 13)),
                ]),
              ),
              pw.Expanded(child: pw.Padding(
                padding: const pw.EdgeInsets.all(18),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                  pw.Expanded(flex: 34, child: pw.ClipRRect(
                    horizontalRadius: 12, verticalRadius: 12,
                    child: image == null
                        ? pw.Container(color: PdfColor.fromInt(0xff334155), child: pw.Center(child: pw.Text('لا توجد صورة', style: const pw.TextStyle(color: PdfColors.white))))
                        : pw.Image(image, fit: pw.BoxFit.cover),
                  )),
                  pw.SizedBox(width: 18),
                  pw.Expanded(flex: 42, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Wrap(spacing: 7, runSpacing: 6, children: [
                      _tag(data.adType, bold), _tag(data.propertyType, bold), _tag(status, bold),
                    ]),
                    pw.SizedBox(height: 11),
                    pw.Text(data.title, textAlign: pw.TextAlign.right, maxLines: 2, style: pw.TextStyle(color: PdfColors.white, font: bold, fontSize: 19)),
                    pw.SizedBox(height: 8),
                    pw.Text('الموقع: ${_location(data)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                    pw.SizedBox(height: 12),
                    pw.Text('$price د.ع${data.negotiable ? '  •  قابل للتفاوض' : ''}', style: pw.TextStyle(color: PdfColor.fromInt(0xffd4af37), font: bold, fontSize: 17)),
                    pw.SizedBox(height: 13),
                    pw.Wrap(alignment: pw.WrapAlignment.end, spacing: 7, runSpacing: 7, children: details.map((item) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xff1e293b), borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Text(item, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                    )).toList()),
                    if (data.features.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Text('المزايا: ${data.features.take(4).join(' • ')}', maxLines: 2, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                    ],
                    pw.Spacer(),
                    pw.Text('${data.isOffice ? 'المكتب' : 'الناشر'}: ${data.contactName}', style: pw.TextStyle(color: PdfColors.white, font: bold, fontSize: 10)),
                    if (data.contactPhone.isNotEmpty) pw.Text('للاستفسار: ${data.contactPhone}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ])),
                  pw.SizedBox(width: 14),
                  pw.SizedBox(width: 116, child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      color: PdfColors.white,
                      child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: data.publicUrl, width: 82, height: 82, color: PdfColors.black),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('امسح الباركود لعرض العقار', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColor.fromInt(0xffd4af37), font: bold, fontSize: 8)),
                    pw.SizedBox(height: 3),
                    pw.Text('تحقق من أحدث السعر والحالة', textAlign: pw.TextAlign.center, style: const pw.TextStyle(color: PdfColors.white, fontSize: 7)),
                  ])),
                ]),
              )),
            ]),
          ),
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _tag(String text, pw.Font bold) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xff334155), borderRadius: pw.BorderRadius.circular(6)),
    child: pw.Text(text, style: pw.TextStyle(color: PdfColor.fromInt(0xffd4af37), font: bold, fontSize: 8)),
  );

  static String _location(PropertyCardData data) => data.location.trim().isNotEmpty
      ? data.location : [data.city, data.areaName].where((item) => item.trim().isNotEmpty).join(' - ');
  static String _statusLabel(String status) => switch (status.toLowerCase()) {
    'sold' => 'تم البيع', 'rented' => 'تم التأجير', _ => 'متوفر',
  };
  static Future<pw.ImageProvider?> _loadImage(String url) async {
    if (!url.startsWith('http')) return null;
    try { return await networkImage(url); } catch (_) { return null; }
  }
}
