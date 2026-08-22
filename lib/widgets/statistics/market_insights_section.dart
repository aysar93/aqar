import 'package:flutter/material.dart';

import '../../models/statistics/market_insight.dart';
import '../../theme/statistics_text_styles.dart';

/// قسم مؤشرات السوق.
///
/// يستقبل النتائج التي أنشأها محرك الإحصائيات
/// ويعرضها بطريقة واضحة للمستخدم.
class MarketInsightsSection extends StatelessWidget {
  final List<MarketInsight> insights;

  /// أقصى عدد من المؤشرات المعروضة.
  ///
  /// null = عرض جميع المؤشرات.
  final int? maxVisibleItems;

  const MarketInsightsSection({
    super.key,
    required this.insights,
    this.maxVisibleItems,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return _buildEmptyState();
    }

    final visibleInsights = _visibleInsights;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        ...List.generate(
          visibleInsights.length,
          (index) {
            final insight = visibleInsights[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleInsights.length - 1 ? 0 : 10,
              ),
              child: _MarketInsightCard(
                insight: insight,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _gold.withValues(alpha: 0.18),
            ),
          ),
          child: const Icon(
            Icons.auto_graph_rounded,
            color: _gold,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مؤشرات السوق',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: StatisticsTextStyles.sectionTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'قراءة مبسطة للبيانات ضمن الفلاتر الحالية',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.46,
                  ),
                  fontSize: StatisticsTextStyles.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${insights.length}',
            style: const TextStyle(
              color: _gold,
              fontSize: StatisticsTextStyles.secondarySize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 26,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.06,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 31,
            color: _gold.withValues(alpha: 0.60),
          ),
          const SizedBox(height: 10),
          const Text(
            'لا توجد مؤشرات متاحة',
            style: TextStyle(
              color: Colors.white,
              fontSize: StatisticsTextStyles.cardTitleSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'ستظهر مؤشرات السوق عند توفر بيانات كافية للتحليل',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.44,
              ),
              fontSize: StatisticsTextStyles.captionSize,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  List<MarketInsight> get _visibleInsights {
    if (maxVisibleItems == null ||
        maxVisibleItems! <= 0 ||
        insights.length <= maxVisibleItems!) {
      return insights;
    }

    return insights.take(maxVisibleItems!).toList(growable: false);
  }
}

class _MarketInsightCard extends StatelessWidget {
  final MarketInsight insight;

  const _MarketInsightCard({
    required this.insight,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF59E0B);
  static const Color _blue = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: accent.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(accent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        insight.title,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (_formattedValue != null) ...[
                      const SizedBox(width: 8),
                      _ValueBadge(
                        value: _formattedValue!,
                        color: accent,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  insight.description,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.60,
                    ),
                    fontSize: StatisticsTextStyles.secondarySize,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
                if (_hasMetadata) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (insight.hasCity)
                        _MetadataChip(
                          icon: Icons.location_city_outlined,
                          text: insight.city!,
                        ),
                      if (insight.hasArea)
                        _MetadataChip(
                          icon: Icons.location_on_outlined,
                          text: insight.areaName!,
                        ),
                      if (insight.hasPropertyCount)
                        _MetadataChip(
                          icon: Icons.home_work_outlined,
                          text: '${insight.propertyCount} عقار',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        _icon,
        color: color,
        size: 20,
      ),
    );
  }

  bool get _hasMetadata {
    return insight.hasCity || insight.hasArea || insight.hasPropertyCount;
  }

  Color get _accentColor {
    switch (insight.level) {
      case MarketInsightLevel.positive:
        return _green;

      case MarketInsightLevel.warning:
        return _orange;

      case MarketInsightLevel.negative:
        return _red;

      case MarketInsightLevel.info:
        switch (insight.type) {
          case MarketInsightType.highestPriceArea:
          case MarketInsightType.highestPricePerSquareMeter:
            return _gold;

          case MarketInsightType.mostActiveArea:
            return _blue;

          default:
            return _gold;
        }
    }
  }

  IconData get _icon {
    switch (insight.type) {
      case MarketInsightType.priceIncrease:
        return Icons.trending_up_rounded;

      case MarketInsightType.priceDecrease:
        return Icons.trending_down_rounded;

      case MarketInsightType.priceStable:
        return Icons.trending_flat_rounded;

      case MarketInsightType.highestPriceArea:
        return Icons.workspace_premium_outlined;

      case MarketInsightType.lowestPriceArea:
        return Icons.south_rounded;

      case MarketInsightType.highestPricePerSquareMeter:
        return Icons.square_foot_rounded;

      case MarketInsightType.mostActiveArea:
        return Icons.local_fire_department_outlined;

      case MarketInsightType.limitedData:
        return Icons.warning_amber_rounded;

      case MarketInsightType.general:
        return Icons.lightbulb_outline_rounded;
    }
  }

  String? get _formattedValue {
    final value = insight.value;

    if (value == null) {
      return null;
    }

    switch (insight.type) {
      case MarketInsightType.priceIncrease:
        return '+${value.abs().toStringAsFixed(1)}%';

      case MarketInsightType.priceDecrease:
        return '-${value.abs().toStringAsFixed(1)}%';

      case MarketInsightType.priceStable:
        return '${value.abs().toStringAsFixed(1)}%';

      case MarketInsightType.highestPriceArea:
      case MarketInsightType.lowestPriceArea:
        return _compactPrice(value);

      case MarketInsightType.highestPricePerSquareMeter:
        return '${_compactPrice(value)}/م²';

      case MarketInsightType.mostActiveArea:
        return '${value.round()} عقار';

      case MarketInsightType.limitedData:
      case MarketInsightType.general:
        return null;
    }
  }

  String _compactPrice(double value) {
    if (value <= 0) {
      return '0 د.ع';
    }

    if (value >= 1000000000) {
      return '${_compactNumber(value / 1000000000)} مليار د.ع';
    }

    if (value >= 1000000) {
      return '${_compactNumber(value / 1000000)} مليون د.ع';
    }

    if (value >= 1000) {
      return '${_compactNumber(value / 1000)} ألف د.ع';
    }

    return '${value.round()} د.ع';
  }

  String _compactNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}

class _ValueBadge extends StatelessWidget {
  final String value;
  final Color color;

  const _ValueBadge({
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        value,
        maxLines: 1,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: color,
          fontSize: StatisticsTextStyles.captionSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetadataChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.04,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.055,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white.withValues(
              alpha: 0.40,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.50,
              ),
              fontSize: StatisticsTextStyles.captionSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
