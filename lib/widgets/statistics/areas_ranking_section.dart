import 'package:flutter/material.dart';

import '../../models/statistics/area_statistics.dart';
import 'area_statistics_card.dart';
import '../../theme/statistics_text_styles.dart';

/// طريقة ترتيب المناطق.
enum AreasRankingType {
  averagePrice,
  pricePerSquareMeter,
  activity,
}

/// قسم ترتيب المناطق داخل شاشة إحصائيات السوق.
///
/// يدعم:
/// - الأعلى في متوسط سعر العقار.
/// - الأعلى في متوسط سعر المتر.
/// - الأكثر نشاطًا حسب عدد العقارات.
class AreasRankingSection extends StatefulWidget {
  final List<AreaStatistics> areas;

  /// عدد المناطق المعروضة افتراضيًا.
  final int initialVisibleCount;

  /// عند الضغط على منطقة.
  final ValueChanged<AreaStatistics>? onAreaTap;

  const AreasRankingSection({
    super.key,
    required this.areas,
    this.initialVisibleCount = 5,
    this.onAreaTap,
  });

  @override
  State<AreasRankingSection> createState() => _AreasRankingSectionState();
}

class _AreasRankingSectionState extends State<AreasRankingSection> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardColor = Color(0xFF1E293B);

  AreasRankingType _rankingType = AreasRankingType.averagePrice;

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final areas = _sortedAreas;

    if (areas.isEmpty) {
      return _buildEmptyState();
    }

    final visibleAreas =
        _showAll ? areas : areas.take(widget.initialVisibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(areas.length),
        const SizedBox(height: 14),
        _buildRankingSelector(),
        const SizedBox(height: 15),
        ...List.generate(
          visibleAreas.length,
          (index) {
            final area = visibleAreas[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleAreas.length - 1 ? 0 : 12,
              ),
              child: AreaStatisticsCard(
                statistics: area,
                rank: index + 1,
                onTap: widget.onAreaTap == null
                    ? null
                    : () {
                        widget.onAreaTap!(area);
                      },
              ),
            );
          },
        ),
        if (areas.length > widget.initialVisibleCount) ...[
          const SizedBox(height: 13),
          _buildShowMoreButton(areas.length),
        ],
      ],
    );
  }

  Widget _buildHeader(int count) {
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
            Icons.leaderboard_outlined,
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
                'ترتيب المناطق',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: StatisticsTextStyles.sectionTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'مقارنة $count منطقة حسب بيانات السوق الحالية',
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
      ],
    );
  }

  Widget _buildRankingSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.06,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RankingButton(
              label: 'متوسط السعر',
              icon: Icons.payments_outlined,
              selected: _rankingType == AreasRankingType.averagePrice,
              onTap: () {
                _changeRanking(
                  AreasRankingType.averagePrice,
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _RankingButton(
              label: 'سعر المتر',
              icon: Icons.square_foot_rounded,
              selected: _rankingType == AreasRankingType.pricePerSquareMeter,
              onTap: () {
                _changeRanking(
                  AreasRankingType.pricePerSquareMeter,
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _RankingButton(
              label: 'الأكثر نشاطًا',
              icon: Icons.local_fire_department_outlined,
              selected: _rankingType == AreasRankingType.activity,
              onTap: () {
                _changeRanking(
                  AreasRankingType.activity,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowMoreButton(int totalCount) {
    final hiddenCount = totalCount - widget.initialVisibleCount;

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _showAll = !_showAll;
          });
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: _gold,
          side: BorderSide(
            color: _gold.withValues(alpha: 0.20),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: _gold.withValues(alpha: 0.035),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _showAll ? 'عرض أقل' : 'عرض $hiddenCount منطقة إضافية',
              style: const TextStyle(
                fontSize: StatisticsTextStyles.sectionSubtitleSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              _showAll
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 19,
            ),
          ],
        ),
      ),
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
            Icons.location_off_outlined,
            color: _gold.withValues(alpha: 0.65),
            size: 31,
          ),
          const SizedBox(height: 10),
          const Text(
            'لا توجد مناطق للمقارنة',
            style: TextStyle(
              color: Colors.white,
              fontSize: StatisticsTextStyles.cardTitleSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'ستظهر مقارنة المناطق عند توفر بيانات كافية ضمن الفلاتر الحالية',
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

  List<AreaStatistics> get _sortedAreas {
    Iterable<AreaStatistics> source = widget.areas.where(
      (area) => area.hasData,
    );

    // عند ترتيب سعر المتر نستبعد المناطق التي
    // لا تحتوي على عينة صالحة لسعر المتر.
    if (_rankingType == AreasRankingType.pricePerSquareMeter) {
      source = source.where(
        (area) => area.hasPricePerSquareMeter,
      );
    }

    final result = List<AreaStatistics>.from(source);

    switch (_rankingType) {
      case AreasRankingType.averagePrice:
        result.sort((a, b) {
          final comparison = b.averagePrice.compareTo(
            a.averagePrice,
          );

          if (comparison != 0) {
            return comparison;
          }

          return b.propertyCount.compareTo(
            a.propertyCount,
          );
        });
        break;

      case AreasRankingType.pricePerSquareMeter:
        result.sort((a, b) {
          final comparison = b.averagePricePerSquareMeter.compareTo(
            a.averagePricePerSquareMeter,
          );

          if (comparison != 0) {
            return comparison;
          }

          return b.pricePerSquareMeterSampleCount.compareTo(
            a.pricePerSquareMeterSampleCount,
          );
        });
        break;

      case AreasRankingType.activity:
        result.sort((a, b) {
          final comparison = b.propertyCount.compareTo(
            a.propertyCount,
          );

          if (comparison != 0) {
            return comparison;
          }

          return b.averagePrice.compareTo(
            a.averagePrice,
          );
        });
        break;
    }

    return result;
  }

  void _changeRanking(
    AreasRankingType type,
  ) {
    if (_rankingType == type) {
      return;
    }

    setState(() {
      _rankingType = type;

      // عند تغيير معيار الترتيب نعود إلى
      // العدد المختصر حتى تبقى الصفحة مرتبة.
      _showAll = false;
    });
  }
}

class _RankingButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RankingButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color:
                selected ? _gold.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? _gold.withValues(alpha: 0.22) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? _gold
                    : Colors.white.withValues(
                        alpha: 0.45,
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? _gold
                      : Colors.white.withValues(
                          alpha: 0.55,
                        ),
                  fontSize: StatisticsTextStyles.secondarySize,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
