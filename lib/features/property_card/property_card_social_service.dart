import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'property_card_data.dart';

/// خدمة توليد صورة بطاقة العقار الاجتماعية 9:16 بدقة 1080×1920
///
/// تعمل بشكل مستقل تماماً عن حجم الشاشة وتُنتج PNG عالي الجودة.
class PropertyCardSocialService {
  // ─── الثوابت ──────────────────────────────────────────────────────────────
  static const double _logicalW = 360.0;
  static const double _logicalH = 640.0;
  static const double _pixelRatio = 3.0; // 360×3 = 1080, 640×3 = 1920

  // ─── هوية الألوان الفاخرة (Luxury Real Estate) ────────────────────────────
  static const _navy     = Color(0xFF0B1320);   // Navy عميق جداً وأنيق — الخلفية الرئيسية
  static const _navyMid  = Color(0xFF131F33);   // Navy ثانوي — للشرائح والبطاقات
  static const _navyCard = Color(0xFF182740);   // Navy للكروت البارزة (السعر)
  static const _gold     = Color(0xFFB8972A);   // ذهبي فاخر هادئ غير صارخ
  static const _goldSoft = Color(0xFFC9A227);   // ذهبي ثانوي ناعم
  static const _white    = Colors.white;
  static const _textSub  = Color(0xFFCBD5E1);   // نصوص ثانوية واضحة

  // ─── Entry Points ─────────────────────────────────────────────────────────
  static Widget buildSocialCardFor(PropertyCardData data) => _buildSocialCard(data);
  static Widget buildWidget(PropertyCardData data) => _buildSocialCard(data);

  // ─── Render عبر OverlayEntry ──────────────────────────────────────────────
  static Future<Uint8List> generateViaRepaint(
    BuildContext context,
    PropertyCardData data,
  ) async {
    final repaintKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -_logicalW * 2,
        top: 0,
        width: _logicalW,
        height: _logicalH,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: repaintKey,
            child: _buildSocialCard(data),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 500));

    Uint8List result;
    try {
      final boundary =
          repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      result = byteData!.buffer.asUint8List();
    } finally {
      overlay.remove();
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CARD ROOT — 360 × 640 logical → 1080 × 1920 physical
  // ══════════════════════════════════════════════════════════════════════════
  static Widget _buildSocialCard(PropertyCardData data) {
    return Theme(
      data: ThemeData(
        fontFamily: 'Cairo',
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Cairo'),
        child: Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Container(
            width: _logicalW,
            height: _logicalH,
            color: _navy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ① HEADER (50px)
                _Header(data: data),

                // ② HERO IMAGE (180px)
                _HeroImage(data: data),

                // ③ MIDDLE CONTENT (يتمدد ويستوعب التفاصيل بدون أي overflow)
                Expanded(
                  child: _MiddleContent(data: data),
                ),

                // ④ QR & DESCRIPTION (88px)
                _QrDescSection(data: data),

                // ⑤ FOOTER (66px)
                _Footer(data: data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static ui.Image? testLogoImage;
  static ui.Image? testHeroImage;

  /// تحميل الشعار الرسمي مع دعم البيئات المختلفة (تطبيق، اختبار، معاينة)
  static Widget _buildLogo(double size) {
    if (testLogoImage != null) {
      return RawImage(
        image: testLogoImage,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    const assetPath = 'assets/images/logo.png';
    final file = File(assetPath);
    final projFile = File('d:/Projects/aqar/$assetPath');
    if (file.existsSync()) {
      return Image.memory(file.readAsBytesSync(), width: size, height: size, fit: BoxFit.contain);
    } else if (projFile.existsSync()) {
      return Image.memory(projFile.readAsBytesSync(), width: size, height: size, fit: BoxFit.contain);
    }
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.home_work_rounded,
        color: PropertyCardSocialService._gold,
        size: size * 0.8,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ① HEADER (ارتفاع ثابت: 50px)
// ══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  const _Header({required this.data});
  final PropertyCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: PropertyCardSocialService._navyMid,
      ),
      child: Stack(
        children: [
          // خط ذهبي قطري ديكوري
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: CustomPaint(
              size: const Size(50, 50),
              painter: _DiagonalAccentPainter(),
            ),
          ),

          // المحتوى
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // الشعار الرسمي
                PropertyCardSocialService._buildLogo(34),
                const SizedBox(width: 9),

                // اسم الشركة
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'عقارات الانبار',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PropertyCardSocialService._white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        'AL-ANBAR REAL ESTATE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PropertyCardSocialService._gold,
                          fontSize: 7,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // الشعار النصي + رقم العقار
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'خيارك الأفضل .. لاستثمار آمن',
                        style: TextStyle(
                          color: PropertyCardSocialService._textSub,
                          fontSize: 8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: PropertyCardSocialService._gold.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${data.number}',
                          style: const TextStyle(
                            color: PropertyCardSocialService._gold,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // خط ذهبي سفلي رفيع
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 1,
              color: PropertyCardSocialService._gold.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8972A).withValues(alpha: 0.15)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ② HERO IMAGE (ارتفاع ثابت: 180px)
// ══════════════════════════════════════════════════════════════════════════════
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.data});
  final PropertyCardData data;

  Widget _buildImage(String path) {
    if (PropertyCardSocialService.testHeroImage != null) {
      return RawImage(
        image: PropertyCardSocialService.testHeroImage,
        fit: BoxFit.cover,
      );
    }
    if (path.isEmpty) return _placeholder();
    final file = File(path);
    final projFile = File('d:/Projects/aqar/$path');
    if (file.existsSync()) {
      return Image.memory(file.readAsBytesSync(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    } else if (projFile.existsSync()) {
      return Image.memory(projFile.readAsBytesSync(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF142033),
      child: const Center(
        child: Icon(
          Icons.apartment_rounded,
          color: Colors.white12,
          size: 54,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // الصورة
            _buildImage(data.imageUrl),

            // Gradient سفلي ناعم
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),

            // Badges أعلى اليسار (مميز / موثق)
            Positioned(
              top: 8,
              left: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.isFeatured)
                    const _StatusTag(
                      label: '★ مميز',
                      bg: PropertyCardSocialService._gold,
                      fg: Color(0xFF0B1320),
                    ),
                  if (data.isFeatured && data.isVerified)
                    const SizedBox(width: 5),
                  if (data.isVerified)
                    const _StatusTag(
                      label: '✓ موثّق',
                      bg: Color(0xFF14532D),
                      fg: Colors.white,
                    ),
                ],
              ),
            ),

            // حالة العقار أعلى اليمين (إن لم يكن متوفراً)
            if (data.availabilityStatus.toLowerCase() != 'available' &&
                data.availabilityStatus.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: _StatusTag(
                  label: data.statusLabel,
                  bg: const Color(0xFF7F1D1D),
                  fg: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ③ MIDDLE CONTENT (العنوان، السعر، التفاصيل)
// ══════════════════════════════════════════════════════════════════════════════
class _MiddleContent extends StatelessWidget {
  const _MiddleContent({required this.data});
  final PropertyCardData data;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final priceStr = fmt.format(data.price);

    // تجهيز قائمة التفاصيل الديناميكية
    final details = _buildDetails(data);

    // تجهيز الموقع
    final locParts = <String>[];
    if (data.city.trim().isNotEmpty) locParts.add(data.city.trim());
    if (data.areaName.trim().isNotEmpty) locParts.add(data.areaName.trim());
    if (data.landmark.trim().isNotEmpty) locParts.add(data.landmark.trim());
    final locationStr = locParts.isNotEmpty ? locParts.join(' - ') : data.location;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── نوع الإعلان + نوع العقار + العنوان ──────────────────────────
          Row(
            children: [
              _MiniBadge(label: data.adTypeLabel, gold: true),
              const SizedBox(width: 5),
              _MiniBadge(label: data.propertyType),
            ],
          ),
          const SizedBox(height: 4),

          // العنوان الرئيسي
          Text(
            data.title,
            style: const TextStyle(
              color: PropertyCardSocialService._white,
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),

          // الموقع بالذهبي
          if (locationStr.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: PropertyCardSocialService._gold,
                  size: 11.5,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationStr,
                    style: const TextStyle(
                      color: PropertyCardSocialService._gold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 8),

          // ── السعر ونوع العقار ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: PropertyCardSocialService._navyCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: PropertyCardSocialService._gold.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // السعر
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'السعر',
                        style: TextStyle(
                          color: PropertyCardSocialService._textSub,
                          fontSize: 8,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: priceStr,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: PropertyCardSocialService._gold,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(
                              text: '  د.ع',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: PropertyCardSocialService._textSub,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (data.negotiable)
                        const Text(
                          'قابل للتفاوض',
                          style: TextStyle(
                            color: PropertyCardSocialService._goldSoft,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

                // نوع العقار + رقمه
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.home_work_outlined,
                          color: PropertyCardSocialService._gold,
                          size: 11.5,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          data.propertyType,
                          style: const TextStyle(
                            color: PropertyCardSocialService._white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AQR-${data.number}',
                      style: const TextStyle(
                        color: PropertyCardSocialService._textSub,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── تفاصيل العقار (Grid) ────────────────────────────────────────
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DetailsGrid(items: details),
          ],

          // مساحة مرنة تتمدد لامتصاص الفراغ
          const Spacer(),

          // مساحة تنفس 16px قبل خط الباركود بالضبط
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // بناء تفاصيل العقار مع عزل تام لبيانات الأرض
  static List<_DetailItem> _buildDetails(PropertyCardData data) {
    final list = <_DetailItem>[];

    // المساحة — تظهر للكل
    if (data.area > 0) {
      list.add(_DetailItem(
        icon: Icons.straighten_rounded,
        label: 'المساحة',
        value: '${data.area} م²',
      ));
    }

    // تفاصيل المباني — لا تظهر نهائياً للأرض
    if (!data.isLandType) {
      if (data.rooms > 0) {
        list.add(_DetailItem(
          icon: Icons.bed_rounded,
          label: 'غرف النوم',
          value: '${data.rooms}',
        ));
      }
      if (data.bathrooms > 0) {
        list.add(_DetailItem(
          icon: Icons.bathroom_rounded,
          label: 'الحمامات',
          value: '${data.bathrooms}',
        ));
      }
      if (data.livingRooms > 0) {
        list.add(_DetailItem(
          icon: Icons.weekend_rounded,
          label: 'المعيشة',
          value: '${data.livingRooms}',
        ));
      }
      if (data.parking > 0) {
        list.add(_DetailItem(
          icon: Icons.garage_rounded,
          label: 'الكراج',
          value: '${data.parking}',
        ));
      }
      if (data.floors != null && data.floors! > 0) {
        list.add(_DetailItem(
          icon: Icons.layers_rounded,
          label: 'الطوابق',
          value: '${data.floors}',
        ));
      }
      if (data.buildYear > 1970) {
        list.add(_DetailItem(
          icon: Icons.calendar_today_rounded,
          label: 'سنة البناء',
          value: '${data.buildYear}',
        ));
      }
      if (data.furnitureStatus.trim().isNotEmpty &&
          data.furnitureStatus.trim() != '—') {
        list.add(_DetailItem(
          icon: Icons.chair_rounded,
          label: 'الأثاث',
          value: data.furnitureStatus,
        ));
      }
    }

    // تفاصيل الأرض والموقع المشتركة
    if (data.frontage != null && data.frontage! > 0) {
      list.add(_DetailItem(
        icon: Icons.width_normal_rounded,
        label: 'الواجهة',
        value: '${data.frontage!.toStringAsFixed(0)} م',
      ));
    }
    if (data.depth != null && data.depth! > 0) {
      list.add(_DetailItem(
        icon: Icons.height_rounded,
        label: 'العمق',
        value: '${data.depth!.toStringAsFixed(0)} م',
      ));
    }
    if (data.documentType.trim().isNotEmpty &&
        data.documentType.trim() != '—') {
      list.add(_DetailItem(
        icon: Icons.description_rounded,
        label: 'الوثيقة',
        value: data.documentType,
      ));
    }

    return list.take(6).toList();
  }
}

// ── شبكة تفاصيل العقار الأنيقة ────────────────────────────────────────────
class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.items});
  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    final cols = items.length >= 5 ? 3 : (items.length == 1 ? 1 : 2);
    final rows = <List<_DetailItem>>[];
    for (var i = 0; i < items.length; i += cols) {
      rows.add(items.sublist(i, (i + cols).clamp(0, items.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: List.generate(cols, (ci) {
              if (ci >= row.length) return const Expanded(child: SizedBox());
              final item = row[ci];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: ci < cols - 1 ? 6 : 0),
                  child: _DetailCell(item: item),
                ),
              );
            }),
          ),
        );
      }).toList(),
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({required this.item});
  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          item.icon,
          color: PropertyCardSocialService._gold,
          size: 11.5,
        ),
        const SizedBox(width: 4.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  color: PropertyCardSocialService._textSub,
                  fontSize: 7.5,
                  height: 1.1,
                ),
                maxLines: 1,
              ),
              Text(
                item.value,
                style: const TextStyle(
                  color: PropertyCardSocialService._white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailItem {
  const _DetailItem({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, this.gold = false});
  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: gold
            ? PropertyCardSocialService._gold.withValues(alpha: 0.15)
            : PropertyCardSocialService._navyCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: gold
              ? PropertyCardSocialService._gold.withValues(alpha: 0.4)
              : PropertyCardSocialService._textSub.withValues(alpha: 0.2),
          width: 0.7,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: gold
              ? PropertyCardSocialService._gold
              : PropertyCardSocialService._textSub,
          fontSize: 8.5,
          fontWeight: gold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ④ قسم QR والوصف (ارتفاع محسوب: ~88px)
// ══════════════════════════════════════════════════════════════════════════════
class _QrDescSection extends StatelessWidget {
  const _QrDescSection({required this.data});
  final PropertyCardData data;

  @override
  Widget build(BuildContext context) {
    final hasDesc = data.description.trim().isNotEmpty;
    final shortDesc = hasDesc
        ? (data.description.trim().length > 70
            ? '${data.description.trim().substring(0, 70)}...'
            : data.description.trim())
        : '';

    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: PropertyCardSocialService._navyMid,
        border: Border(
          top: BorderSide(
            color: PropertyCardSocialService._gold.withValues(alpha: 0.35),
            width: 0.9,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // تفاصيل ووصف العقار
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            color: PropertyCardSocialService._gold,
                            size: 11,
                          ),
                          SizedBox(width: 3.5),
                          Text(
                            'وصف العقار',
                            style: TextStyle(
                              color: PropertyCardSocialService._gold,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: PropertyCardSocialService._navyCard,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: PropertyCardSocialService._gold.withValues(alpha: 0.3),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          'رقم: #${data.number}',
                          style: const TextStyle(
                            color: PropertyCardSocialService._gold,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                if (hasDesc) ...[
                  Text(
                    shortDesc,
                    style: const TextStyle(
                      color: PropertyCardSocialService._textSub,
                      fontSize: 8,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                ],
                const Text(
                  'تحقق من أحدث السعر والحالة عبر الباركود',
                  style: TextStyle(
                    color: PropertyCardSocialService._textSub,
                    fontSize: 7.5,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // رمز QR واضح داخل خلفية بيضاء
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: QrImageView(
              data: data.publicUrl,
              version: QrVersions.auto,
              size: 58,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // نصوص امسح الكود
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'امسح الكود',
                style: TextStyle(
                  color: PropertyCardSocialService._gold,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              Text(
                'لمشاهدة العقار',
                style: TextStyle(
                  color: PropertyCardSocialService._textSub,
                  fontSize: 8,
                  height: 1.2,
                ),
              ),
              Text(
                'على الخريطة',
                style: TextStyle(
                  color: PropertyCardSocialService._textSub,
                  fontSize: 8,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑤ FOOTER (ارتفاع ثابت: 66px)
// ══════════════════════════════════════════════════════════════════════════════
class _Footer extends StatelessWidget {
  const _Footer({required this.data});
  final PropertyCardData data;

  @override
  Widget build(BuildContext context) {
    final phone = data.contactWhatsapp.isNotEmpty
        ? data.contactWhatsapp
        : data.contactPhone;

    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: Color(0xFF09101C), // Navy فاحم وأنيق
        border: Border(
          top: BorderSide(
            color: Color(0xFFB8972A),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // رقم الهاتف والتواصل
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            color: PropertyCardSocialService._gold,
                            size: 10,
                          ),
                          SizedBox(width: 3.5),
                          Text(
                            'للاستفسار والتواصل',
                            style: TextStyle(
                              color: PropertyCardSocialService._textSub,
                              fontSize: 7.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        phone.isNotEmpty ? phone : '0780 000 0000',
                        style: const TextStyle(
                          color: PropertyCardSocialService._white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // الشعار المركزي
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: PropertyCardSocialService._buildLogo(26),
              ),

              // مميزات الهوية (3 نقاط ثقة)
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FooterFeature(icon: Icons.verified_rounded, label: 'معتمدون وموثوقون'),
                    SizedBox(height: 1.5),
                    _FooterFeature(icon: Icons.star_rounded, label: 'خدمة احترافية'),
                    SizedBox(height: 1.5),
                    _FooterFeature(icon: Icons.trending_up_rounded, label: 'خبرة في السوق'),
                  ],
                ),
              ),
            ],
          ),

          // سطر ختامي أنيق
          const Text(
            'عقارات الانبار .. شريكك في كل خطوة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PropertyCardSocialService._gold,
              fontSize: 8,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterFeature extends StatelessWidget {
  const _FooterFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PropertyCardSocialService._textSub,
              fontSize: 7,
            ),
          ),
          const SizedBox(width: 2.5),
          Icon(icon, color: PropertyCardSocialService._gold, size: 8.5),
        ],
      ),
    );
  }
}
