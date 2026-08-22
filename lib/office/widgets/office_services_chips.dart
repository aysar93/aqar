import 'package:flutter/material.dart';

/// عرض خدمات المكتب على شكل Chips.
///
/// أمثلة:
/// - بيع العقارات
/// - إيجار العقارات
/// - إدارة العقارات
/// - التسويق العقاري
/// - التقييم العقاري
/// - الاستثمار العقاري
///
/// الخدمات تأتي من OfficeModel لاحقًا، لذلك هذا Widget
/// يستقبل List<String> فقط ولا يرتبط بقاعدة البيانات مباشرة.
class OfficeServicesChips extends StatelessWidget {
  final List<String> services;

  /// الحد الأقصى لعدد الخدمات الظاهرة.
  ///
  /// إذا كان null يتم عرض جميع الخدمات.
  final int? maxItems;

  /// عند الضغط على خدمة.
  final ValueChanged<String>? onServiceTap;

  const OfficeServicesChips({
    super.key,
    required this.services,
    this.maxItems,
    this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final cleanedServices = services
        .map(
          (service) => service.trim(),
        )
        .where(
          (service) => service.isNotEmpty,
        )
        .toSet()
        .toList();

    if (cleanedServices.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleServices = maxItems == null
        ? cleanedServices
        : cleanedServices.take(maxItems!).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        textDirection: TextDirection.rtl,
        spacing: 8,
        runSpacing: 8,
        children: visibleServices.map(
          (service) {
            return _buildServiceChip(
              context,
              service,
            );
          },
        ).toList(),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Service Chip
  // ═════════════════════════════════════════════

  Widget _buildServiceChip(
    BuildContext context,
    String service,
  ) {
    return InkWell(
      onTap: onServiceTap == null ? null : () => onServiceTap!(service),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFD4AF37).withValues(
            alpha: 0.09,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(
              alpha: 0.35,
            ),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 15,
              color: Color(0xFFD4AF37),
            ),
            const SizedBox(width: 6),
            Text(
              service,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
