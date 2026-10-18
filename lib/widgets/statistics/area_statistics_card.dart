import 'package:flutter/material.dart';

import '../../models/statistics/area_statistics.dart';
import '../../theme/statistics_text_styles.dart';

class AreaStatisticsCard extends StatelessWidget {
  final AreaStatistics statistics;

  /// ترتيب المنطقة في القائمة، مثل 1 أو 2 أو 3.
  final int? rank;

  /// يتم استدعاؤها عند الضغط على البطاقة.
  final VoidCallback? onTap;

  const AreaStatisticsCard({
    super.key,
    required this.statistics,
    this.rank,
    this.onTap,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.06,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.10,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 15),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(
              alpha: 0.06,
            ),
          ),
          const SizedBox(height: 15),
          _buildAveragePrice(),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _AreaMetric(
                  title: 'سعر المتر',
                  value: statistics.hasPricePerSquareMeter
                      ? '${_compactPrice(statistics.averagePricePerSquareMeter)} /م²'
                      : 'غير متوفر',
                  icon: Icons.square_foot_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                color: Colors.white.withValues(
                  alpha: 0.06,
                ),
              ),
              Expanded(
                child: _AreaMetric(
                  title: 'عدد العقارات',
                  value: _propertyCountText,
                  icon: Icons.home_work_outlined,
                ),
              ),
            ],
          ),
          if (statistics.hasPreviousPeriodData) ...[
            const SizedBox(height: 15),
            _buildTrend(),
          ],
          if (statistics.hasPricePerSquareMeter &&
              statistics.pricePerSquareMeterSampleCount <
                  statistics.propertyCount) ...[
            const SizedBox(height: 11),
            _buildPricePerMeterSampleNote(),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _gold.withValues(alpha: 0.20),
            ),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: _gold,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statistics.areaName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: StatisticsTextStyles.sectionTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                statistics.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.45,
                  ),
                  fontSize: StatisticsTextStyles.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (rank != null)
          _RankBadge(
            rank: rank!,
          ),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.keyboard_arrow_left_rounded,
            color: Colors.white.withValues(
              alpha: 0.42,
            ),
            size: 21,
          ),
        ],
      ],
    );
  }

  Widget _buildAveragePrice() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'متوسط سعر العقار',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.45,
                  ),
                  fontSize: StatisticsTextStyles.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatFullPrice(
                  statistics.averagePrice,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'دينار عراقي',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.38,
                  ),
                  fontSize: StatisticsTextStyles.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (statistics.hasPreviousPeriodData)
          _TrendBadge(
            percentage: statistics.priceChangePercentage,
          ),
      ],
    );
  }

  Widget _buildTrend() {
    final increasing = statistics.isPriceIncreasing;
    final decreasing = statistics.isPriceDecreasing;

    final color = increasing
        ? _green
        : decreasing
            ? _red
            : _gold;

    final icon = increasing
        ? Icons.trending_up_rounded
        : decreasing
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    final description = increasing
        ? 'ارتفاع عن الفترة السابقة'
        : decreasing
            ? 'انخفاض عن الفترة السابقة'
            : 'مستقر مقارنة بالفترة السابقة';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.58,
                ),
                fontSize: StatisticsTextStyles.secondarySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formattedChange,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: StatisticsTextStyles.captionSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricePerMeterSampleNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Colors.white.withValues(
            alpha: 0.34,
          ),
          size: 14,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            'متوسط سعر المتر محسوب من '
            '${statistics.pricePerSquareMeterSampleCount} '
            'من أصل ${statistics.propertyCount} عقار',
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.36,
              ),
              fontSize: StatisticsTextStyles.captionSize,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String get _propertyCountText {
    final count = statistics.propertyCount;

    if (count <= 0) {
      return '0 عقار';
    }

    if (count == 1) {
      return 'عقار واحد';
    }

    if (count == 2) {
      return 'عقاران';
    }

    return '$count عقار';
  }

  String get _formattedChange {
    final value = statistics.priceChangePercentage.abs();

    if (statistics.isPriceIncreasing) {
      return '+${value.toStringAsFixed(1)}%';
    }

    if (statistics.isPriceDecreasing) {
      return '-${value.toStringAsFixed(1)}%';
    }

    return '0.0%';
  }

  String _formatFullPrice(double value) {
    if (value <= 0) {
      return '0';
    }

    final digits = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);

      final remaining = digits.length - i - 1;

      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }

    return buffer.toString();
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

class _AreaMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _AreaMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: _gold.withValues(
              alpha: 0.08,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: _gold,
            size: 16,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.38,
                  ),
                  fontSize: StatisticsTextStyles.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: StatisticsTextStyles.secondarySize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double percentage;

  const _TrendBadge({
    required this.percentage,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final increasing = percentage > 0;
    final decreasing = percentage < 0;

    final color = increasing
        ? _green
        : decreasing
            ? _red
            : _gold;

    final icon = increasing
        ? Icons.arrow_upward_rounded
        : decreasing
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    final prefix = increasing
        ? '+'
        : decreasing
            ? '-'
            : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 3),
          Text(
            '$prefix${percentage.abs().toStringAsFixed(1)}%',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: StatisticsTextStyles.captionSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({
    required this.rank,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(
          color: _gold.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        '#$rank',
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          color: _gold,
          fontSize: StatisticsTextStyles.captionSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
