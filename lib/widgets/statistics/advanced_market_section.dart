import 'package:flutter/material.dart';

import '../../services/property_statistics_service.dart';
import '../../theme/statistics_text_styles.dart';

/// يعرض المؤشرات الوصفية الجديدة من دون التأثير في بطاقات الأسعار القديمة.
class AdvancedMarketSection extends StatelessWidget {
  final PropertyMarketAnalytics analytics;

  const AdvancedMarketSection({super.key, required this.analytics});

  static const _gold = Color(0xFFD4AF37);
  static const _surface = Color(0xFF162033);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 330 ? 1 : 2;
            final itemWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(
                  itemWidth,
                  'متوسط المساحة',
                  _decimal(analytics.averageArea, 'م²'),
                  Icons.square_foot_rounded,
                ),
                _metric(
                  itemWidth,
                  'متوسط الغرف',
                  _decimal(analytics.averageRooms, 'غرفة'),
                  Icons.bedroom_parent_outlined,
                ),
                _metric(
                  itemWidth,
                  'متوسط الحمامات',
                  _decimal(analytics.averageBathrooms, 'حمام'),
                  Icons.bathtub_outlined,
                ),
                _metric(
                  itemWidth,
                  'إجمالي المشاهدات',
                  _integer(analytics.totalViews),
                  Icons.visibility_outlined,
                ),
                _metric(
                  itemWidth,
                  'متوسط الصالات',
                  _decimal(analytics.averageLivingRooms, 'صالة'),
                  Icons.weekend_outlined,
                ),
                _metric(
                  itemWidth,
                  'متوسط المواقف',
                  _decimal(analytics.averageParking, 'موقف'),
                  Icons.local_parking_outlined,
                ),
              ],
            );
          },
        ),
        if (analytics.segmentStatistics.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SegmentsCard(segments: analytics.segmentStatistics.values.toList()),
        ],
        if (analytics.excludedPriceOutlierCount > 0) ...[
          const SizedBox(height: 10),
          _DataCleaningNote(count: analytics.excludedPriceOutlierCount),
        ],
        if (analytics.propertyTypeDistribution.isNotEmpty) ...[
          const SizedBox(height: 14),
          _DistributionCard(
            title: 'توزيع أنواع العقارات',
            values: analytics.propertyTypeDistribution,
            total: analytics.propertyCount,
          ),
        ],
        if (analytics.adTypeDistribution.isNotEmpty) ...[
          const SizedBox(height: 10),
          _DistributionCard(
            title: 'البيع مقابل الإيجار',
            values: analytics.adTypeDistribution,
            total: analytics.propertyCount,
          ),
        ],
        for (final entry in analytics.priceBandsBySegment.entries)
          if (entry.value.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DistributionCard(
              title: 'الفئات السعرية – ${entry.key}',
              values: entry.value,
              total: entry.value.values.fold<int>(
                0,
                (sum, value) => sum + value,
              ),
            ),
          ],
        if (analytics.areaBandDistribution.isNotEmpty) ...[
          const SizedBox(height: 10),
          _DistributionCard(
            title: 'المساحات الأكثر انتشارًا',
            values: analytics.areaBandDistribution,
            total: analytics.areaBandDistribution.values.fold<int>(
              0,
              (sum, value) => sum + value,
            ),
          ),
        ],
        if (analytics.growingAreas.isNotEmpty) ...[
          const SizedBox(height: 10),
          _TrendAreasCard(
            title: 'المناطق الصاعدة',
            items: analytics.growingAreas,
            color: const Color(0xFF22C55E),
            icon: Icons.trending_up_rounded,
          ),
        ],
        if (analytics.decliningAreas.isNotEmpty) ...[
          const SizedBox(height: 10),
          _TrendAreasCard(
            title: 'المناطق الهابطة',
            items: analytics.decliningAreas,
            color: const Color(0xFFEF4444),
            icon: Icons.trending_down_rounded,
          ),
        ],
        if (analytics.insufficientTrendAreas.isNotEmpty) ...[
          const SizedBox(height: 10),
          _InsufficientAreasCard(items: analytics.insufficientTrendAreas),
        ],
        if (analytics.mostActiveCities.isNotEmpty) ...[
          const SizedBox(height: 10),
          _RankingCard(
            title: 'المدن الأكثر نشاطًا',
            items: analytics.mostActiveCities,
          ),
        ],
        if (analytics.mostActiveAreas.isNotEmpty) ...[
          const SizedBox(height: 10),
          _RankingCard(
            title: 'المناطق الأكثر نشاطًا',
            items: analytics.mostActiveAreas,
          ),
        ],
        if (analytics.mostActiveOffices.isNotEmpty) ...[
          const SizedBox(height: 10),
          _RankingCard(
            title: 'المكاتب الأكثر نشرًا',
            items: analytics.mostActiveOffices,
          ),
        ],
        if (analytics.mostViewedProperties.isNotEmpty) ...[
          const SizedBox(height: 10),
          _MostViewedCard(properties: analytics.mostViewedProperties),
        ],
      ],
    );
  }

  Widget _metric(double width, String title, String value, IconData icon) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _gold, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: StatisticsTextStyles.caption),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StatisticsTextStyles.metric,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _decimal(double value, String unit) =>
      value <= 0 ? 'غير متوفر' : '${value.toStringAsFixed(1)} $unit';

  String _integer(int value) => value.toString();
}

class _SegmentsCard extends StatelessWidget {
  final List<MarketSegmentStatistics> segments;

  const _SegmentsCard({required this.segments});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'إحصائيات البيع والإيجار',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 330
              ? constraints.maxWidth
              : (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: segments.map((segment) {
              return SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .035),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.real_estate_agent_outlined,
                            color: AdvancedMarketSection._gold,
                            size: 19,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              segment.label,
                              style: StatisticsTextStyles.cardTitle,
                            ),
                          ),
                          Text(
                            '${segment.propertyCount}',
                            style: StatisticsTextStyles.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'متوسط السعر',
                        style: StatisticsTextStyles.caption,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _compactPrice(segment.averagePrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StatisticsTextStyles.metric,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الوسيط: ${_compactPrice(segment.medianPrice)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StatisticsTextStyles.caption,
                      ),
                      if (segment.pricePerSquareMeterSampleCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'المتر: ${_compactPrice(segment.averagePricePerSquareMeter)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StatisticsTextStyles.caption,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          );
        },
      ),
    );
  }

  static String _compactPrice(double value) {
    if (value <= 0 || !value.isFinite) return 'غير متوفر';
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} مليار د.ع';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} مليون د.ع';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)} ألف د.ع';
    }
    return '${value.round()} د.ع';
  }
}

class _DataCleaningNote extends StatelessWidget {
  final int count;

  const _DataCleaningNote({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: .14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cleaning_services_outlined,
            color: Color(0xFF38BDF8),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تم استبعاد $count ${count == 1 ? 'قيمة سعرية شاذة' : 'قيم سعرية شاذة'} بعد توفر عينة كافية، لتحسين دقة المؤشرات.',
              style: StatisticsTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.query_stats_rounded,
          color: AdvancedMarketSection._gold,
          size: 25,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('خصائص السوق', style: StatisticsTextStyles.sectionTitle),
              SizedBox(height: 3),
              Text(
                'قراءة أوسع للمساحات والمواصفات وتوزيع العقارات',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: StatisticsTextStyles.sectionSubtitleSize,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final String title;
  final Map<String, int> values;
  final int total;

  const _DistributionCard({
    required this.title,
    required this.values,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _Panel(
      title: title,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries.map((entry) {
          final percentage =
              total <= 0 ? 0 : (entry.value / total * 100).round();
          return Chip(
            backgroundColor: Colors.white.withValues(alpha: .05),
            side: BorderSide(color: Colors.white.withValues(alpha: .07)),
            label: Text(
              '${entry.key}  ${entry.value} ($percentage٪)',
              style: StatisticsTextStyles.chip,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  final String title;
  final List<MarketRankingItem> items;

  const _RankingCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index + 1}',
                    style: StatisticsTextStyles.cardTitle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StatisticsTextStyles.body,
                  ),
                ),
                Text(
                  '${item.propertyCount} عقار',
                  style: StatisticsTextStyles.caption,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _TrendAreasCard extends StatelessWidget {
  final String title;
  final List<AreaTrendSummary> items;
  final Color color;
  final IconData icon;

  const _TrendAreasCard({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName.isEmpty
                            ? 'منطقة غير محددة'
                            : item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StatisticsTextStyles.body,
                      ),
                      Text(
                        '${item.currentPropertyCount} حاليًا • ${item.previousPropertyCount} سابقًا',
                        style: StatisticsTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.changePercentage > 0 ? '+' : ''}${item.changePercentage.toStringAsFixed(1)}٪',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: color,
                    fontSize: StatisticsTextStyles.cardTitleSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _InsufficientAreasCard extends StatelessWidget {
  final List<AreaTrendSummary> items;

  const _InsufficientAreasCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'بيانات غير كافية للاتجاه',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحتاج المنطقة إلى 5 عقارات على الأقل في كل فترة قبل وصفها بالصعود أو الهبوط.',
            style: StatisticsTextStyles.caption,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items.map((item) {
              return Chip(
                backgroundColor: Colors.white.withValues(alpha: .04),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: .06),
                ),
                label: Text(
                  item.displayName.isEmpty
                      ? 'منطقة غير محددة'
                      : item.displayName,
                  style: StatisticsTextStyles.chip,
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _MostViewedCard extends StatelessWidget {
  final List<ViewedPropertySummary> properties;

  const _MostViewedCard({required this.properties});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'العقارات الأكثر مشاهدة',
      child: Column(
        children: List.generate(properties.length, (index) {
          final property = properties[index];
          final location = [
            property.city.trim(),
            property.areaName.trim(),
          ].where((value) => value.isNotEmpty).join(' - ');

          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AdvancedMarketSection._gold.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AdvancedMarketSection._gold,
                      fontSize: StatisticsTextStyles.captionSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title.trim().isEmpty
                            ? 'عقار دون عنوان'
                            : property.title.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: StatisticsTextStyles.body,
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StatisticsTextStyles.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          color: Color(0xFF38BDF8),
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${property.views}',
                          textDirection: TextDirection.ltr,
                          style: StatisticsTextStyles.cardTitle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _SegmentsCard._compactPrice(property.price),
                      textDirection: TextDirection.rtl,
                      style: StatisticsTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdvancedMarketSection._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: StatisticsTextStyles.cardTitle),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
