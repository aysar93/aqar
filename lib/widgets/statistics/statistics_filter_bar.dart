import 'package:flutter/material.dart';

import '../../models/statistics/statistics_filter.dart';
import '../../theme/statistics_text_styles.dart';

class StatisticsFilterBar extends StatelessWidget {
  final StatisticsFilter filter;
  final VoidCallback onTap;

  const StatisticsFilterBar({
    super.key,
    required this.filter,
    required this.onTap,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.07,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildFilterIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'تصفية الإحصائيات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: StatisticsTextStyles.cardTitleSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (filter.activeFiltersCount > 0) ...[
                          const SizedBox(width: 7),
                          _FilterCountBadge(
                            count: filter.activeFiltersCount,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _filterSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.58,
                        ),
                        fontSize: StatisticsTextStyles.sectionSubtitleSize,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.05,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.keyboard_arrow_left_rounded,
                  color: Colors.white.withValues(
                    alpha: 0.65,
                  ),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _gold.withValues(alpha: 0.22),
        ),
      ),
      child: const Icon(
        Icons.tune_rounded,
        color: _gold,
        size: 22,
      ),
    );
  }

  String get _filterSummary {
    final values = <String>[];

    if (filter.hasAdType) {
      values.add(filter.adType!);
    } else {
      values.add('بيع وإيجار');
    }

    if (filter.hasPropertyType) {
      values.add(filter.propertyType!);
    } else {
      values.add('كل العقارات');
    }

    if (filter.hasCity) {
      values.add(filter.city!);
    } else {
      values.add('كل المدن');
    }

    if (filter.hasArea) {
      values.add(filter.areaName!);
    }

    values.add(filter.periodLabel);

    return values.join(' • ');
  }
}

class _FilterCountBadge extends StatelessWidget {
  final int count;

  const _FilterCountBadge({
    required this.count,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 22,
        minHeight: 22,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _gold.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: _gold,
          fontSize: StatisticsTextStyles.captionSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
