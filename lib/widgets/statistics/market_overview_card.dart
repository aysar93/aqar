import 'package:flutter/material.dart';

import '../../models/statistics/market_statistics.dart';
import '../../theme/statistics_text_styles.dart';

/// البطاقة الرئيسية لملخص السوق العقاري.
///
/// تعرض:
/// - متوسط السعر الحالي.
/// - نسبة التغير عن الفترة السابقة.
/// - متوسط الفترة السابقة.
/// - حجم العينة.
/// - حالة توفر المقارنة.
class MarketOverviewCard extends StatelessWidget {
  final MarketStatistics statistics;

  const MarketOverviewCard({
    super.key,
    required this.statistics,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final trendColor = _trendColor;
    final trendIcon = _trendIcon;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _gold.withValues(alpha: 0.16),
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
                  color: _gold.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
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
                      'متوسط أسعار العقارات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: StatisticsTextStyles.sectionTitleSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'حسب الفلاتر والفترة المحددة',
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.48,
                        ),
                        fontSize: StatisticsTextStyles.captionSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _formatPrice(statistics.averagePrice),
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'دينار عراقي',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: StatisticsTextStyles.secondarySize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 17),
          if (statistics.hasPreviousPeriodData)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: trendColor.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendIcon,
                        color: trendColor,
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formattedChange,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: trendColor,
                          fontSize: StatisticsTextStyles.bodySize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _trendDescription,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.58,
                      ),
                      fontSize: StatisticsTextStyles.secondarySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          else
            _buildNoComparison(),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OverviewInfo(
                  title: 'حجم العينة',
                  value: '${statistics.propertyCount} عقار',
                  icon: Icons.home_work_outlined,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                color: Colors.white.withValues(alpha: 0.07),
              ),
              Expanded(
                child: _OverviewInfo(
                  title: 'المتوسط السابق',
                  value: statistics.hasPreviousPeriodData
                      ? _compactPrice(
                          statistics.previousAveragePrice,
                        )
                      : 'غير متوفر',
                  icon: Icons.history_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoComparison() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white.withValues(alpha: 0.55),
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'لا تتوفر بيانات كافية للمقارنة مع الفترة السابقة',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: StatisticsTextStyles.captionSize,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _trendColor {
    if (statistics.isPriceIncreasing) {
      return _green;
    }

    if (statistics.isPriceDecreasing) {
      return _red;
    }

    return _gold;
  }

  IconData get _trendIcon {
    if (statistics.isPriceIncreasing) {
      return Icons.trending_up_rounded;
    }

    if (statistics.isPriceDecreasing) {
      return Icons.trending_down_rounded;
    }

    return Icons.trending_flat_rounded;
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

  String get _trendDescription {
    if (statistics.isPriceIncreasing) {
      return 'ارتفاع مقارنة بالفترة السابقة';
    }

    if (statistics.isPriceDecreasing) {
      return 'انخفاض مقارنة بالفترة السابقة';
    }

    return 'استقرار مقارنة بالفترة السابقة';
  }

  String _formatPrice(double value) {
    if (value <= 0) {
      return '0';
    }

    final rounded = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;

      buffer.write(rounded[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  String _compactPrice(double value) {
    if (value <= 0) {
      return 'غير متوفر';
    }

    if (value >= 1000000000) {
      final result = value / 1000000000;

      return '${_compactNumber(result)} مليار د.ع';
    }

    if (value >= 1000000) {
      final result = value / 1000000;

      return '${_compactNumber(result)} مليون د.ع';
    }

    if (value >= 1000) {
      final result = value / 1000;

      return '${_compactNumber(result)} ألف د.ع';
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

class _OverviewInfo extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _OverviewInfo({
    required this.title,
    required this.value,
    required this.icon,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: _gold,
          size: 18,
        ),
        const SizedBox(width: 8),
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
                    alpha: 0.42,
                  ),
                  fontSize: StatisticsTextStyles.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: StatisticsTextStyles.sectionSubtitleSize,
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
