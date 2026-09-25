import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'property_card_data.dart';

/// خدمة بناء ملفات PDF لبطاقة العقار
///
/// تعتمد بالكامل وبشكل موحد على الصورة عالية الدقة (1080×1920)
/// لبطاقة العقار الاجتماعية الجديدة، مما يضمن تطابقاً بصرياً 100%
/// في المعاينة، الطباعة، ومشاركة ملفات الـ PDF دون أي تشويه أو قص.
class PropertyCardPdfService {
  /// بناء مستند PDF يضم صورة البطاقة الجديدة بنسبة 9:16 متناسقة تماماً داخل الصفحة
  static Future<Uint8List> buildFromCardImage(
    Uint8List cardImageBytes, {
    PdfPageFormat? format,
  }) async {
    final pageFormat = format ?? PdfPageFormat.a4;
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            height: double.infinity,
            color: const PdfColor(0.043, 0.075,
                0.125), // #0B1320 خلفية كحلية فاخرة مطابقة للبطاقة
            alignment: pw.Alignment.center,
            child: pw.Image(
              pw.MemoryImage(cardImageBytes),
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  /// دالة متوافقة مع الاستدعاءات السابقة
  static Future<Uint8List> build(
    PropertyCardData data, {
    Uint8List? cardImageBytes,
    PdfPageFormat? format,
  }) async {
    if (cardImageBytes != null) {
      return buildFromCardImage(cardImageBytes, format: format);
    }
    throw ArgumentError(
      'cardImageBytes مطلوب لإنشاء PDF مبني على البطاقة الجديدة الحالية',
    );
  }
}
