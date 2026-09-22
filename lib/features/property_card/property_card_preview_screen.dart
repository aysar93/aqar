import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'property_card_data.dart';
import 'property_card_pdf_service.dart';

class PropertyCardPreviewScreen extends StatelessWidget {
  const PropertyCardPreviewScreen({super.key, required this.data});
  final PropertyCardData data;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff0f172a),
    appBar: AppBar(
      backgroundColor: const Color(0xff0f172a),
      foregroundColor: Colors.white,
      title: const Text('معاينة بطاقة العقار'),
    ),
    body: PdfPreview(
      canChangeOrientation: false,
      canChangePageFormat: false,
      allowPrinting: true,
      allowSharing: true,
      pdfFileName: 'property-${data.number}.pdf',
      build: (_) => PropertyCardPdfService.build(data),
    ),
  );
}
