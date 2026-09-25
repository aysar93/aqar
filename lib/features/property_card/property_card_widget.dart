import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ignore: implementation_imports
import 'package:qr_flutter/qr_flutter.dart';

import 'property_card_data.dart';

/// Widget مرئي لبطاقة العقار — يُعرض داخل التطبيق
/// ويُستخدم كمرجع بصري للـ PDF والصورة الناتجة
class PropertyCardWidget extends StatelessWidget {
  const PropertyCardWidget({super.key, required this.data});
  final PropertyCardData data;

  static const _navy = Color(0xFF0F172A);
  static const _darkSlate = Color(0xFF1E293B);
  static const _slate = Color(0xFF29384F);
  static const _gold = Color(0xFFD4AF37);
  static const _brightGold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // نسبة Landscape A4: 297/210
    final cardHeight = screenWidth * (210 / 297);

    return Container(
      width: screenWidth,
      height: cardHeight.clamp(230.0, 380.0),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody(context)),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _darkSlate,
        border: Border(bottom: BorderSide(color: _gold.withValues(alpha: 0.6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // شعار + اسم
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.home_work_rounded,
                  color: _gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'عقارات الانبار',
                style: TextStyle(
                  color: _gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // رقم العقار + الحالة
          Row(
            children: [
              _buildStatusChip(),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: _gold.withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '#${data.number}',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final (label, color) = switch (data.availabilityStatus.toLowerCase()) {
      'sold' => ('تم البيع', const Color(0xFFB01E1E)),
      'rented' => ('تم التأجير', const Color(0xFF1E5BB0)),
      _ => ('متوفر', const Color(0xFF228B22)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // اليمين: صورة
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.28,
            child: _buildImagesColumn(),
          ),
          const SizedBox(width: 10),
          // الوسط: المعلومات
          Expanded(child: _buildInfoColumn()),
          const SizedBox(width: 10),
          // اليسار: QR
          SizedBox(width: 90, child: _buildQrColumn()),
        ],
      ),
    );
  }

  Widget _buildImagesColumn() {
    final total = data.images.length;
    final mainUrl = data.imageUrl.isNotEmpty ? data.imageUrl : null;
    final extra1 = data.images.length > 1 ? data.images[1] : null;
    final extra2 = data.images.length > 2 ? data.images[2] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: extra1 != null ? 3 : 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildNetworkImage(mainUrl),
                if (total > 1)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '$total صور',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (extra1 != null) ...[
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildNetworkImage(extra1),
                  ),
                ),
                if (extra2 != null) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildNetworkImage(extra2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNetworkImage(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        color: _slate,
        child: const Icon(Icons.image_not_supported_rounded,
            color: Colors.white30, size: 20),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: _slate),
      errorWidget: (_, __, ___) => Container(
        color: _slate,
        child: const Icon(Icons.broken_image_rounded,
            color: Colors.white24, size: 16),
      ),
    );
  }

  Widget _buildInfoColumn() {
    final priceText = NumberFormat('#,###').format(data.price);
    final details = _buildDetailsItems();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Tags
        Wrap(
          spacing: 4,
          runSpacing: 3,
          alignment: WrapAlignment.end,
          children: [
            _buildMiniTag(data.adTypeLabel, _gold, _navy, bold: true),
            _buildMiniTag(data.propertyType, _slate, Colors.white70),
            if (data.isFeatured) _buildMiniTag('★ مميز', _brightGold, _navy),
            if (data.isVerified)
              _buildMiniTag('✓ موثّق', const Color(0xFF228B22), Colors.white),
          ],
        ),
        const SizedBox(height: 5),

        // العنوان
        Text(
          data.title,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 4),

        // الموقع
        _buildLocationText(),

        const SizedBox(height: 6),
        Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
        const SizedBox(height: 6),

        // السعر
        Text(
          '$priceText د.ع',
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: _gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (data.negotiable)
          const Text(
            'قابل للتفاوض',
            textAlign: TextAlign.right,
            style: TextStyle(color: _brightGold, fontSize: 8.5),
          ),

        const SizedBox(height: 6),
        Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
        const SizedBox(height: 5),

        // التفاصيل
        if (details.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 3,
            alignment: WrapAlignment.end,
            children:
                details.take(6).map((item) => _buildDetailItem(item)).toList(),
          ),

        // الميزات
        if (data.features.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            alignment: WrapAlignment.end,
            children: data.features
                .take(4)
                .map((f) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _slate,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        f.toString(),
                        style:
                            const TextStyle(color: Colors.white60, fontSize: 7),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationText() {
    final parts = <String>[];
    if (data.city.isNotEmpty) parts.add(data.city);
    if (data.areaName.isNotEmpty) parts.add(data.areaName);
    if (data.landmark.isNotEmpty) parts.add(data.landmark);
    final text = parts.isNotEmpty ? parts.join(' • ') : data.location;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
        ),
        const SizedBox(width: 3),
        const Icon(Icons.location_on_rounded, color: _gold, size: 10),
      ],
    );
  }

  Widget _buildMiniTag(String text, Color bg, Color fg, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 8,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildDetailItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _darkSlate,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _gold.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 8),
      ),
    );
  }

  Widget _buildQrColumn() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
          ),
          child: QrImageView(
            data: data.publicUrl,
            version: QrVersions.auto,
            size: 72,
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
        const SizedBox(height: 5),
        const Text(
          'امسح الباركود',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _gold, fontSize: 7.5, fontWeight: FontWeight.bold),
        ),
        const Text(
          'لعرض العقار',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _gold, fontSize: 7.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'تحقق من أحدث\nالسعر والحالة',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 7, height: 1.4),
        ),
        const SizedBox(height: 5),
        Container(height: 0.5, color: Colors.white24),
        const SizedBox(height: 4),
        Text(
          '#${data.number}',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: _gold, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context) {
    final phone = data.contactPhone.trim();
    final whatsapp = data.contactWhatsapp.trim();
    final dateStr = DateFormat('dd/MM/yyyy').format(data.cardDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _darkSlate,
        border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // بيانات التواصل (يمين)
          Row(
            children: [
              if (phone.isNotEmpty) ...[
                const Icon(Icons.phone_rounded, color: _gold, size: 10),
                const SizedBox(width: 3),
                Text(phone,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 8.5)),
                const SizedBox(width: 10),
              ],
              if (whatsapp.isNotEmpty && whatsapp != phone) ...[
                const Icon(Icons.chat_rounded, color: _gold, size: 10),
                const SizedBox(width: 3),
                Text(whatsapp,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 8.5)),
              ],
            ],
          ),

          // شعار + تاريخ (يسار)
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 14,
                    height: 14,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.home_work_rounded,
                        color: _gold,
                        size: 12),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'عقارات الانبار',
                    style: TextStyle(
                        color: _gold, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                'تاريخ إنشاء البطاقة: $dateStr',
                style: const TextStyle(color: Colors.white30, fontSize: 7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helper: قائمة التفاصيل ────────────────────────────────────────────
  List<String> _buildDetailsItems() {
    final isLand = data.isLandType;
    final items = <String>[];

    if (data.area > 0) items.add('${data.area} م²');
    if (!isLand) {
      if (data.rooms > 0) items.add('${data.rooms} غرف');
      if (data.bathrooms > 0) items.add('${data.bathrooms} حمام');
      if (data.livingRooms > 0) items.add('${data.livingRooms} صالة');
      if (data.parking > 0) items.add('كراج ${data.parking}');
    }
    if (data.floors != null && data.floors! > 0)
      items.add('${data.floors} طابق');
    if (data.frontage != null && data.frontage! > 0) {
      items.add('واجهة ${data.frontage!.toStringAsFixed(0)}م');
    }
    if (data.depth != null && data.depth! > 0) {
      items.add('عمق ${data.depth!.toStringAsFixed(0)}م');
    }
    if (data.buildYear > 0) items.add('${data.buildYear}');
    if (data.documentType.trim().isNotEmpty) items.add(data.documentType);
    if (data.furnitureStatus.trim().isNotEmpty && !isLand) {
      items.add(data.furnitureStatus);
    }
    return items;
  }
}
