import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyRequestHomeCard extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> data;
  final bool isAdmin;
  final VoidCallback onTap;

  const PropertyRequestHomeCard({
    super.key,
    required this.requestId,
    required this.data,
    required this.isAdmin,
    required this.onTap,
  });

  static const Color _gold = Color(0xffD4AF37);
  static const Color _card = Color(0xff1E293B);

  @override
  Widget build(BuildContext context) {
    final requestType = _text(data['requestType']);
    final propertyType = _text(data['propertyType'], fallback: 'عقار');
    final city = _text(data['city']);
    final district = _text(data['district']);

    final location =
        [city, district].where((value) => value.isNotEmpty).join(' • ');

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _gold.withValues(alpha: .24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned(
                    top: -45,
                    left: -35,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gold.withValues(alpha: .06),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(
                                  color: _gold.withValues(alpha: .22),
                                ),
                              ),
                              child: Icon(
                                _propertyIcon(propertyType),
                                color: _gold,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "مطلوب",
                                    style: TextStyle(
                                      color: _gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _title(
                                      requestType,
                                      propertyType,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _requestTypeBadge(requestType),
                                if (isAdmin) ...[
                                  const SizedBox(width: 4),
                                  const SizedBox.shrink(),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (location.isNotEmpty)
                          _infoRow(
                            icon: Icons.location_on_rounded,
                            title: location,
                          ),
                        if (location.isNotEmpty) const SizedBox(height: 8),
                        _infoRow(
                          icon: Icons.square_foot_rounded,
                          title: _range(
                            data['minArea'],
                            data['maxArea'],
                            suffix: "م²",
                          ),
                        ),
                        const SizedBox(height: 8),
                        _infoRow(
                          icon: Icons.account_balance_wallet_rounded,
                          title: _range(
                            data['minPrice'],
                            data['maxPrice'],
                            suffix: "د.ع",
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _gold.withValues(alpha: .18),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "عرض تفاصيل الطلب",
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRequest(
    BuildContext context,
  ) async {
    final propertyType = _text(
      data['propertyType'],
      fallback: 'العقار',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xff1E293B),
            title: const Text(
              'حذف الطلب',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'هل أنت متأكد من حذف طلب $propertyType نهائيًا؟\n\n'
              'سيختفي الطلب من قسم مطلوب على عقارات الانبار، '
              'ولا يمكن التراجع عن الحذف',
              style: const TextStyle(
                color: Colors.white70,
                height: 1.6,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text(
                  'حذف',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('property_requests')
          .doc(requestId)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حذف الطلب بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر حذف الطلب: $e',
          ),
        ),
      );
    }
  }

  Widget _requestTypeBadge(String requestType) {
    final String label;

    if (requestType == 'شراء') {
      label = 'شراء';
    } else if (requestType == 'إيجار') {
      label = 'إيجار';
    } else {
      label = requestType.isEmpty ? 'طلب' : requestType;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _gold.withValues(alpha: .25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _gold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: _gold,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _title(
    String requestType,
    String propertyType,
  ) {
    if (requestType == 'شراء') {
      return "$propertyType للشراء";
    }

    if (requestType == 'إيجار') {
      return "$propertyType للإيجار";
    }

    return propertyType;
  }

  String _range(
    dynamic minValue,
    dynamic maxValue, {
    required String suffix,
  }) {
    final min = _toDouble(minValue);
    final max = _toDouble(maxValue);

    if (min == null && max == null) {
      return "غير محدد";
    }

    if (min != null && max != null) {
      if (min == max) {
        return "${_formatNumber(min)} $suffix";
      }

      return "${_formatNumber(min)} - ${_formatNumber(max)} $suffix";
    }

    if (min != null) {
      return "من ${_formatNumber(min)} $suffix";
    }

    return "حتى ${_formatNumber(max!)} $suffix";
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().replaceAll(',', ''),
    );
  }

  String _formatNumber(double value) {
    return NumberFormat('#,##0').format(value.round());
  }

  String _text(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  IconData _propertyIcon(String propertyType) {
    switch (propertyType) {
      case 'بيت':
        return Icons.home_rounded;

      case 'شقة':
        return Icons.apartment_rounded;

      case 'أرض':
        return Icons.landscape_rounded;

      case 'محل':
        return Icons.storefront_rounded;

      case 'عمارة':
        return Icons.location_city_rounded;

      case 'مزرعة':
        return Icons.agriculture_rounded;

      default:
        return Icons.real_estate_agent_rounded;
    }
  }
}
