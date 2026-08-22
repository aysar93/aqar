import 'package:flutter/material.dart';

import '../../models/statistics/area_statistics.dart';
import '../../widgets/statistics/area_statistics_card.dart';
import '../../theme/statistics_text_styles.dart';

/// شاشة التفاصيل الكاملة لإحصائيات منطقة واحدة.
///
/// هذه الشاشة لا تعيد قراءة Firestore.
/// تستقبل AreaStatistics المحسوبة مسبقًا من شاشة
/// إحصائيات السوق، ثم تعرض تفاصيل المنطقة.
class AreaStatisticsScreen extends StatelessWidget {
  final AreaStatistics statistics;

  const AreaStatisticsScreen({super.key, required this.statistics});

  static const Color _background = Color(0xFF0F172A);
  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF59E0B);
  static const Color _blue = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360
        ? 10.0
        : width < 600
            ? 16.0
            : 24.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            statistics.areaName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          leading: IconButton(
            tooltip: 'رجوع',
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              30 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                AreaStatisticsCard(statistics: statistics),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  icon: Icons.analytics_outlined,
                  title: 'تفاصيل الأسعار',
                  subtitle: 'قراءة تفصيلية لأسعار العقارات في المنطقة',
                ),
                const SizedBox(height: 12),
                _buildPriceMetrics(),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  icon: Icons.square_foot_rounded,
                  title: 'سعر المتر المربع',
                  subtitle:
                      'متوسط السعر اعتمادًا على العقارات ذات المساحة الصالحة',
                ),
                const SizedBox(height: 12),
                _buildPricePerSquareMeterCard(),
                if (statistics.hasPreviousPeriodData) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    icon: Icons.timeline_rounded,
                    title: 'اتجاه الأسعار',
                    subtitle: 'مقارنة متوسط السعر بالفترة السابقة',
                  ),
                  const SizedBox(height: 12),
                  _buildTrendCard(),
                ],
                const SizedBox(height: 24),
                _buildSectionHeader(
                  icon: Icons.verified_outlined,
                  title: 'جودة البيانات',
                  subtitle: 'حجم العينة المستخدمة في حساب هذه الإحصائية',
                ),
                const SizedBox(height: 12),
                _buildDataQualityCard(),
                const SizedBox(height: 20),
                _buildDisclaimer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.20)),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: _gold,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
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
                    fontSize: StatisticsTextStyles.pageTitleSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_city_outlined,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.40),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        statistics.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: StatisticsTextStyles.secondarySize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _propertyCountText,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: StatisticsTextStyles.captionSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 330 ? 1 : 2;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'متوسط السعر',
                value: _compactPrice(statistics.averagePrice),
                icon: Icons.payments_outlined,
                accentColor: _gold,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'الوسيط',
                value: _compactPrice(statistics.medianPrice),
                icon: Icons.balance_rounded,
                accentColor: _blue,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'أقل سعر',
                value: _compactPrice(statistics.minimumPrice),
                icon: Icons.south_rounded,
                accentColor: _green,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'أعلى سعر',
                value: _compactPrice(statistics.maximumPrice),
                icon: Icons.north_rounded,
                accentColor: _orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPricePerSquareMeterCard() {
    final hasData = statistics.hasPricePerSquareMeter;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: hasData
              ? _blue.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.square_foot_rounded,
              color: hasData ? _blue : Colors.white.withValues(alpha: 0.30),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'متوسط سعر المتر',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasData
                      ? '${_compactPrice(statistics.averagePricePerSquareMeter)} /م²'
                      : 'غير متوفر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasData
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.50),
                    fontSize: StatisticsTextStyles.metricSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasData
                      ? 'محسوب من ${statistics.pricePerSquareMeterSampleCount} من أصل ${statistics.propertyCount} عقار'
                      : 'لا توجد عقارات كافية تحتوي على سعر ومساحة صالحين',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: StatisticsTextStyles.captionSize,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
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

    final title = increasing
        ? 'الأسعار في ارتفاع'
        : decreasing
            ? 'الأسعار في انخفاض'
            : 'الأسعار مستقرة';

    final change = statistics.priceChangePercentage.abs();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: StatisticsTextStyles.cardTitleSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'مقارنة بمتوسط السعر في الفترة السابقة',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: StatisticsTextStyles.captionSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${increasing ? '+' : decreasing ? '-' : ''}${change.toStringAsFixed(1)}%',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: color,
                    fontSize: StatisticsTextStyles.secondarySize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TrendPrice(
                  title: 'الفترة السابقة',
                  value: _compactPrice(statistics.previousAveragePrice),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: _TrendPrice(
                  title: 'الفترة الحالية',
                  value: _compactPrice(statistics.averagePrice),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataQualityCard() {
    final reliable = statistics.hasReliableSample;

    final color = reliable ? _green : _orange;

    final title = reliable ? 'عينة جيدة' : 'عينة محدودة';

    final description = reliable
        ? 'تعتمد الإحصائية على ${statistics.propertyCount} عقار ضمن هذه المنطقة.'
        : 'تعتمد الإحصائية على عدد قليل من العقارات، لذلك يفضّل اعتبار النتائج مؤشرًا أوليًا للسوق.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              reliable ? Icons.verified_outlined : Icons.warning_amber_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: StatisticsTextStyles.bodySize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: StatisticsTextStyles.sectionSubtitleSize,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _gold, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: StatisticsTextStyles.sectionSubtitleSize,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _gold.withValues(alpha: 0.70),
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'هذه الأرقام مبنية على أسعار العقارات المنشورة والمعتمدة في التطبيق، ولا تمثل تقييمًا رسميًا للعقار أو سعر البيع النهائي',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: StatisticsTextStyles.captionSize,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _propertyCountText {
    final count = statistics.propertyCount;

    if (count <= 0) {
      return 'لا توجد عقارات';
    }

    if (count == 1) {
      return 'عقار واحد';
    }

    if (count == 2) {
      return 'عقاران';
    }

    return '$count عقار';
  }

  String _compactPrice(double value) {
    if (!value.isFinite || value <= 0) {
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  static const Color _cardColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: StatisticsTextStyles.cardTitleSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: StatisticsTextStyles.captionSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPrice extends StatelessWidget {
  final String title;
  final String value;

  const _TrendPrice({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: StatisticsTextStyles.captionSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
