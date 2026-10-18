import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aqar/services/share_origin.dart';

import 'property_card_data.dart';
import 'property_card_pdf_service.dart';
import 'property_card_social_service.dart';

class PropertyCardPreviewScreen extends StatefulWidget {
  const PropertyCardPreviewScreen({super.key, required this.data});
  final PropertyCardData data;

  @override
  State<PropertyCardPreviewScreen> createState() =>
      _PropertyCardPreviewScreenState();
}

class _PropertyCardPreviewScreenState
    extends State<PropertyCardPreviewScreen> {
  static const _navy = Color(0xFF0F172A);
  static const _darkSlate = Color(0xFF1E293B);
  static const _gold = Color(0xFFD4AF37);

  // التخزين المؤقت للصورة عالية الدقة لتوحيد الناتج عبر كل الأزرار
  Uint8List? _cachedCardBytes;

  bool _loadingPdf = false;
  bool _loadingPrint = false;
  bool _loadingSave = false;
  bool _loadingShare = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _darkSlate,
        foregroundColor: Colors.white,
        title: const Text(
          'بطاقة العقار',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _gold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _gold.withValues(alpha: 0.4)),
        ),
      ),
      body: Column(
        children: [
          // ── معاينة البطاقة الاجتماعية 9:16 ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // بطاقة 9:16 مرئية
                  _buildSocialCardPreview(),

                  const SizedBox(height: 16),

                  // زر معاينة PDF
                  _buildPreviewPdfButton(),
                ],
              ),
            ),
          ),

          // ── شريط الأزرار ──
          _buildActionBar(),
        ],
      ),
    );
  }

  // ─── بطاقة 9:16 المرئية على الشاشة ───────────────────────────────────────
  Widget _buildSocialCardPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth * (16 / 9);

        return SizedBox(
          width: cardWidth,
          height: cardHeight.clamp(500.0, 700.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 360,
                height: 640,
                child: PropertyCardSocialService.buildWidget(widget.data),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewPdfButton() {
    return OutlinedButton.icon(
      onPressed: _loadingPdf ? null : _previewPdf,
      icon: _loadingPdf
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
            )
          : const Icon(Icons.picture_as_pdf_rounded, color: _gold),
      label: const Text(
        'معاينة PDF للطباعة',
        style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _gold, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── شريط الأزرار ─────────────────────────────────────────────────────────
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      decoration: BoxDecoration(
        color: _darkSlate,
        border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.4))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // السطر 1: PDF + طباعة
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'مشاركة PDF',
                  loading: _loadingPdf,
                  onTap: _sharePdf,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.print_rounded,
                  label: 'طباعة',
                  loading: _loadingPrint,
                  onTap: _printCard,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // السطر 2: حفظ + مشاركة
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.save_alt_rounded,
                  label: 'حفظ في الاستوديو',
                  loading: _loadingSave,
                  onTap: _saveToGallery,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'مشاركة الصورة',
                  loading: _loadingShare,
                  onTap: _shareImage,
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool loading,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? Colors.black : _gold,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? _gold : _darkSlate,
          foregroundColor: isPrimary ? Colors.black : _gold,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _gold.withValues(alpha: isPrimary ? 0 : 0.5),
            ),
          ),
        ),
      ),
    );
  }

  // ─── المسار الموحد لالتقاط البطاقة بجودة فائقة 1080×1920 ───────────────────
  /// دالة موحدة لالتقاط نفس البطاقة الجديدة الحالية بجودة فائقة
  /// بدقة 1080×1920 (pixelRatio: 3.0) مستخدمة عبر كافة الأزرار
  Future<Uint8List?> _captureHighQualityCard() async {
    if (_cachedCardBytes != null) return _cachedCardBytes;

    try {
      final bytes = await PropertyCardSocialService.generateViaRepaint(
        context,
        widget.data,
      );
      _cachedCardBytes = bytes;
      return bytes;
    } catch (e) {
      debugPrint('Error capturing high quality card: $e');
      return null;
    }
  }

  // ─── 4. حفظ في الاستوديو ──────────────────────────────────────────────────
  Future<void> _saveToGallery() async {
    if (_loadingSave) return;
    setState(() => _loadingSave = true);

    try {
      final imageBytes = await _captureHighQualityCard();
      if (imageBytes == null) {
        if (!mounted) return;
        _showError('تعذر توليد الصورة');
        return;
      }

      final decodedImage = await decodeImageFromList(imageBytes);
      final w = decodedImage.width;
      final h = decodedImage.height;
      debugPrint('Generated image: ${w}x$h');

      final tmpDir = await getTemporaryDirectory();
      final fileName =
          'aqar-property-${widget.data.number}-${DateTime.now().millisecondsSinceEpoch}.png';
      final tmpFile = File('${tmpDir.path}/$fileName');
      await tmpFile.writeAsBytes(imageBytes);

      // حفظ في Gallery
      await Gal.putImage(tmpFile.path, album: 'عقارات الانبار');
      await tmpFile.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 8),
              Text(
                'تم الحفظ في الاستوديو ✓ ($w x $h)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _loadingSave = false);
    }
  }

  // ─── 5. مشاركة الصورة بنفس الجودة العالية ─────────────────────────────────
  Future<void> _shareImage() async {
    if (_loadingShare) return;
    setState(() => _loadingShare = true);

    try {
      final imageBytes = await _captureHighQualityCard();
      if (imageBytes == null) {
        if (!mounted) return;
        _showError('تعذر توليد الصورة للمشاركة');
        return;
      }

      final tmpDir = await getTemporaryDirectory();
      final fileName =
          'aqar-property-${widget.data.number}-${DateTime.now().millisecondsSinceEpoch}.png';
      final tmpFile = File('${tmpDir.path}/$fileName');
      await tmpFile.writeAsBytes(imageBytes);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(tmpFile.path, mimeType: 'image/png')],
        subject: 'عقار #${widget.data.number} — ${widget.data.title}',
        sharePositionOrigin: shareOrigin(context),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('تعذر مشاركة الصورة: $e');
    } finally {
      if (mounted) setState(() => _loadingShare = false);
    }
  }

  // ─── 1. معاينة PDF (تعتمد على البطاقة الجديدة) ───────────────────────────
  Future<void> _previewPdf() async {
    if (_loadingPdf) return;
    setState(() => _loadingPdf = true);

    try {
      final imageBytes = await _captureHighQualityCard();
      if (imageBytes == null) {
        if (!mounted) return;
        _showError('تعذر تجهيز البطاقة للمعاينة');
        return;
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PdfPreviewPage(
            data: widget.data,
            cardImageBytes: imageBytes,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  // ─── 3. مشاركة PDF (تعتمد على البطاقة الجديدة) ───────────────────────────
  Future<void> _sharePdf() async {
    if (_loadingPdf) return;
    setState(() => _loadingPdf = true);

    try {
      final imageBytes = await _captureHighQualityCard();
      if (imageBytes == null) {
        if (!mounted) return;
        _showError('تعذر تجهيز البطاقة للـ PDF');
        return;
      }

      final pdfBytes =
          await PropertyCardPdfService.buildFromCardImage(imageBytes);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/property_card_${widget.data.number}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'بطاقة عقار #${widget.data.number} — ${widget.data.title}',
        sharePositionOrigin: shareOrigin(context),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('تعذر مشاركة PDF: $e');
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  // ─── 2. الطباعة (تعتمد على البطاقة الجديدة) ──────────────────────────────
  Future<void> _printCard() async {
    if (_loadingPrint) return;
    setState(() => _loadingPrint = true);

    try {
      final imageBytes = await _captureHighQualityCard();
      if (imageBytes == null) {
        if (!mounted) return;
        _showError('تعذر تجهيز البطاقة للطباعة');
        return;
      }

      await Printing.layoutPdf(
        onLayout: (format) => PropertyCardPdfService.buildFromCardImage(
          imageBytes,
          format: format,
        ),
        name: 'property_card_${widget.data.number}',
      );
    } catch (e) {
      if (!mounted) return;
      _showError('تعذر الطباعة: $e');
    } finally {
      if (mounted) setState(() => _loadingPrint = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[800],
      ),
    );
  }
}

// ─── صفحة معاينة PDF (تعرض البطاقة الجديدة الحالية 100%) ─────────────────────
class _PdfPreviewPage extends StatelessWidget {
  const _PdfPreviewPage({
    required this.data,
    required this.cardImageBytes,
  });

  final PropertyCardData data;
  final Uint8List cardImageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(
          'معاينة PDF — #${data.number}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'property_card_${data.number}.pdf',
        build: (format) => PropertyCardPdfService.buildFromCardImage(
          cardImageBytes,
          format: format,
        ),
      ),
    );
  }
}
