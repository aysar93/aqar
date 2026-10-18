import 'package:flutter/material.dart';

import '../models/property_location.dart';

class LocationSummaryCard extends StatelessWidget {
  final PropertyLocation location;
  final bool isInsideAnbar;
  final bool isMoving;

  const LocationSummaryCard({
    super.key,
    required this.location,
    required this.isInsideAnbar,
    this.isMoving = false,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _card = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final city = location.city.trim();
    final district = location.district.trim();
    final landmark = location.landmark.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: _gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'موقع العقار',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _addressText(
                        city: city,
                        district: district,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                isInsideAnbar: isInsideAnbar,
                isMoving: isMoving,
              ),
            ],
          ),
          if (landmark.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  color: _textSecondary,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    landmark,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CoordinateValue(
                    label: 'خط العرض',
                    value: location.latitude,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(
                    alpha: 0.08,
                  ),
                ),
                Expanded(
                  child: _CoordinateValue(
                    label: 'خط الطول',
                    value: location.longitude,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _addressText({
    required String city,
    required String district,
  }) {
    if (city.isEmpty && district.isEmpty) {
      return 'لم يتم تحديد المدينة والمنطقة';
    }

    if (district.isEmpty) {
      return city;
    }

    if (city.isEmpty) {
      return district;
    }

    return '$city - $district';
  }
}

class _CoordinateValue extends StatelessWidget {
  final String label;
  final double value;

  const _CoordinateValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.toStringAsFixed(6),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isInsideAnbar;
  final bool isMoving;

  const _StatusBadge({
    required this.isInsideAnbar,
    required this.isMoving,
  });

  @override
  Widget build(BuildContext context) {
    const success = Color(0xFF22C55E);
    const error = Color(0xFFEF4444);
    const moving = Color(0xFFD4AF37);

    final Color color;
    final String text;
    final IconData icon;

    if (isMoving) {
      color = moving;
      text = 'تحديد...';
      icon = Icons.my_location_rounded;
    } else if (isInsideAnbar) {
      color = success;
      text = 'داخل الأنبار';
      icon = Icons.check_circle_rounded;
    } else {
      color = error;
      text = 'خارج النطاق';
      icon = Icons.error_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
