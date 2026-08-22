import 'package:flutter/material.dart';

/// بطاقة موقع المكتب.
///
/// تعرض:
/// - المحافظة / المدينة.
/// - المنطقة.
/// - العنوان.
/// - أقرب معلم.
/// - إحداثيات الموقع عند توفرها.
/// - زر فتح الموقع.
///
/// لا تحتوي على منطق الخرائط أو فتح Google Maps مباشرة.
/// سيتم ربط زر الموقع بالخدمة المناسبة لاحقًا.
class OfficeLocationCard extends StatelessWidget {
  final String city;
  final String areaName;
  final String address;
  final String landmark;

  final double? latitude;
  final double? longitude;

  final VoidCallback? onOpenMap;

  const OfficeLocationCard({
    super.key,
    this.city = '',
    this.areaName = '',
    this.address = '',
    this.landmark = '',
    this.latitude,
    this.longitude,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    if (!_hasLocationData) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTitle(context),
          const SizedBox(height: 14),
          _buildLocationDetails(context),
          if (_hasCoordinates) ...[
            const SizedBox(height: 14),
            _buildMapButton(context),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // العنوان
  // ═════════════════════════════════════════════

  Widget _buildTitle(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'موقع المكتب',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            size: 19,
            color: Color(0xFFD4AF37),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // تفاصيل الموقع
  // ═════════════════════════════════════════════

  Widget _buildLocationDetails(
    BuildContext context,
  ) {
    final items = <Widget>[];

    if (_locationText.isNotEmpty) {
      items.add(
        _buildDetailRow(
          context,
          icon: Icons.location_city_outlined,
          label: 'الموقع',
          value: _locationText,
        ),
      );
    }

    if (_clean(address).isNotEmpty) {
      items.add(
        _buildDetailRow(
          context,
          icon: Icons.home_outlined,
          label: 'العنوان',
          value: _clean(address),
        ),
      );
    }

    if (_clean(landmark).isNotEmpty) {
      items.add(
        _buildDetailRow(
          context,
          icon: Icons.place_outlined,
          label: 'أقرب معلم',
          value: _clean(landmark),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i != items.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }

  // ═════════════════════════════════════════════
  // صف التفاصيل
  // ═════════════════════════════════════════════

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            size: 19,
            color: const Color(0xFFD4AF37),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // زر الخريطة
  // ═════════════════════════════════════════════

  Widget _buildMapButton(
    BuildContext context,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onOpenMap,
        icon: const Icon(
          Icons.map_outlined,
          size: 19,
        ),
        label: const Text(
          'فتح الموقع على الخريطة',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37),
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // النص المجمع للموقع
  // ═════════════════════════════════════════════

  String get _locationText {
    final parts = <String>[];

    if (_clean(city).isNotEmpty) {
      parts.add(_clean(city));
    }

    if (_clean(areaName).isNotEmpty) {
      parts.add(_clean(areaName));
    }

    return parts.join(' - ');
  }

  // ═════════════════════════════════════════════
  // هل توجد إحداثيات؟
  // ═════════════════════════════════════════════

  bool get _hasCoordinates {
    return latitude != null &&
        longitude != null &&
        latitude!.abs() <= 90 &&
        longitude!.abs() <= 180;
  }

  // ═════════════════════════════════════════════
  // هل توجد بيانات؟
  // ═════════════════════════════════════════════

  bool get _hasLocationData {
    return _locationText.isNotEmpty ||
        _clean(address).isNotEmpty ||
        _clean(landmark).isNotEmpty ||
        _hasCoordinates;
  }

  String _clean(String value) {
    return value.trim();
  }
}
