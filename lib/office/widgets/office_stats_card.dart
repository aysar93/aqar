import 'package:flutter/material.dart';

/// بطاقة إحصائيات المكتب.
///
/// تستخدم لعرض إحصائيات مثل:
/// - عدد العقارات.
/// - عدد العقارات المميزة.
/// - عدد المشاهدات.
/// - عدد المتابعين.
/// - عدد المراجعات.
/// - متوسط التقييم.
///
/// الواجهة مستقلة عن Firebase، وتستقبل القيم مباشرة.
class OfficeStatsCard extends StatelessWidget {
  final int propertiesCount;
  final int featuredPropertiesCount;
  final int viewsCount;
  final int followersCount;
  final int reviewsCount;
  final double rating;

  /// إذا كانت false يتم إخفاء العناصر التي لا توجد لها قيمة.
  final bool hideEmptyStats;

  const OfficeStatsCard({
    super.key,
    this.propertiesCount = 0,
    this.featuredPropertiesCount = 0,
    this.viewsCount = 0,
    this.followersCount = 0,
    this.reviewsCount = 0,
    this.rating = 0,
    this.hideEmptyStats = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    if (items.isEmpty) {
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
          const SizedBox(height: 16),
          _buildStatsGrid(
            context,
            items,
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // عنوان البطاقة
  // ═════════════════════════════════════════════

  Widget _buildTitle(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'إحصائيات المكتب',
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
            Icons.bar_chart_rounded,
            size: 20,
            color: Color(0xFFD4AF37),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // شبكة الإحصائيات
  // ═════════════════════════════════════════════

  Widget _buildStatsGrid(
    BuildContext context,
    List<_OfficeStatItem> items,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.75,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        return _buildStatItem(
          context,
          items[index],
        );
      },
    );
  }

  // ═════════════════════════════════════════════
  // عنصر إحصائية
  // ═════════════════════════════════════════════

  Widget _buildStatItem(
    BuildContext context,
    _OfficeStatItem item,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: const Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // إنشاء عناصر الإحصائيات
  // ═════════════════════════════════════════════

  List<_OfficeStatItem> _buildItems() {
    final items = <_OfficeStatItem>[];

    if (!hideEmptyStats || propertiesCount > 0) {
      items.add(
        _OfficeStatItem(
          icon: Icons.home_work_outlined,
          value: _formatNumber(
            propertiesCount,
          ),
          label: 'إجمالي العقارات',
        ),
      );
    }

    if (!hideEmptyStats || featuredPropertiesCount > 0) {
      items.add(
        _OfficeStatItem(
          icon: Icons.workspace_premium_outlined,
          value: _formatNumber(
            featuredPropertiesCount,
          ),
          label: 'العقارات المميزة',
        ),
      );
    }

    if (!hideEmptyStats || viewsCount > 0) {
      items.add(
        _OfficeStatItem(
          icon: Icons.visibility_outlined,
          value: _formatNumber(
            viewsCount,
          ),
          label: 'إجمالي المشاهدات',
        ),
      );
    }

    if (!hideEmptyStats || followersCount > 0) {
      items.add(
        _OfficeStatItem(
          icon: Icons.people_outline_rounded,
          value: _formatNumber(
            followersCount,
          ),
          label: 'المتابعون',
        ),
      );
    }

    if (!hideEmptyStats || reviewsCount > 0) {
      items.add(
        _OfficeStatItem(
          icon: Icons.reviews_outlined,
          value: _formatNumber(
            reviewsCount,
          ),
          label: 'المراجعات',
        ),
      );
    }

    if (!hideEmptyStats || rating > 0) {
      items.add(
        _OfficeStatItem(
          icon: Icons.star_outline_rounded,
          value: _formatRating(rating),
          label: 'متوسط التقييم',
        ),
      );
    }

    return items;
  }

  // ═════════════════════════════════════════════
  // تنسيق الأرقام
  // ═════════════════════════════════════════════

  String _formatNumber(int value) {
    if (value < 0) {
      return '0';
    }

    if (value >= 1000000) {
      final millions = value / 1000000;

      return '${millions.toStringAsFixed(
        millions.truncateToDouble() == millions ? 0 : 1,
      )}M';
    }

    if (value >= 1000) {
      final thousands = value / 1000;

      return '${thousands.toStringAsFixed(
        thousands.truncateToDouble() == thousands ? 0 : 1,
      )}K';
    }

    return value.toString();
  }

  String _formatRating(double value) {
    if (value.isNaN || value.isInfinite || value <= 0) {
      return '—';
    }

    return value.clamp(0.0, 5.0).toStringAsFixed(1);
  }
}

// ═══════════════════════════════════════════════
// نموذج داخلي لعنصر الإحصائية
// ═══════════════════════════════════════════════

class _OfficeStatItem {
  final IconData icon;
  final String value;
  final String label;

  const _OfficeStatItem({
    required this.icon,
    required this.value,
    required this.label,
  });
}
