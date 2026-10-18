import 'package:flutter/material.dart';

import '../../models/statistics/market_statistics.dart';
import '../../models/statistics/statistics_filter.dart';
import '../../services/property_statistics_service.dart';
import '../../theme/statistics_text_styles.dart';
import '../../widgets/statistics/areas_ranking_section.dart';
import '../../widgets/statistics/advanced_market_section.dart';
import '../../widgets/statistics/data_confidence_badge.dart';
import '../../widgets/statistics/market_insights_section.dart';
import '../../widgets/statistics/market_overview_card.dart';
import '../../widgets/statistics/price_trend_chart.dart';
import '../../widgets/statistics/statistic_metric_card.dart';
import '../../widgets/statistics/statistics_empty_state.dart';
import '../../widgets/statistics/statistics_filter_bar.dart';
import '../../widgets/statistics/statistics_filter_sheet.dart';
import '../../widgets/statistics/statistics_header.dart';
import '../../widgets/statistics/statistics_loading.dart';
import 'area_statistics_screen.dart';

class PropertyStatisticsScreen extends StatefulWidget {
  const PropertyStatisticsScreen({super.key});

  @override
  State<PropertyStatisticsScreen> createState() =>
      _PropertyStatisticsScreenState();
}

class _PropertyStatisticsScreenState extends State<PropertyStatisticsScreen> {
  static const Color _background = Color(0xFF0F172A);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _green = Color(0xFF22C55E);
  static const Color _blue = Color(0xFF38BDF8);
  static const Color _orange = Color(0xFFF59E0B);

  StatisticsFilter _filter = StatisticsFilter.initial;

  MarketStatistics? _statistics;

  PropertyMarketAnalytics? _analytics;

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadStatistics();
  }

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
          title: const Text(
            'إحصائيات العقارات',
            style: TextStyle(
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
          actions: [
            IconButton(
              tooltip: 'تحديث الإحصائيات',
              onPressed: _isLoading
                  ? null
                  : () {
                      _loadStatistics(forceRefresh: true);
                    },
              icon: Icon(
                Icons.refresh_rounded,
                color:
                    _isLoading ? Colors.white.withValues(alpha: 0.30) : _gold,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: RefreshIndicator(
          color: _gold,
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () => _loadStatistics(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  30 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverToBoxAdapter(child: _buildBody()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const StatisticsLoading();
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          StatisticsFilterBar(filter: _filter, onTap: _openFilterSheet),
          const SizedBox(height: 18),
          StatisticsEmptyState.error(
            message: _errorMessage,
            onRetry: _loadStatistics,
          ),
        ],
      );
    }

    final statistics = _statistics;

    if (statistics == null) {
      return StatisticsEmptyState.error(
        message: 'تعذر الحصول على بيانات الإحصائيات',
        onRetry: _loadStatistics,
      );
    }

    if (statistics.propertyCount <= 0) {
      return Column(
        children: [
          StatisticsHeader(
            propertyCount: statistics.propertyCount,
            generatedAt: statistics.generatedAt,
          ),
          const SizedBox(height: 14),
          StatisticsFilterBar(filter: _filter, onTap: _openFilterSheet),
          const SizedBox(height: 18),
          StatisticsEmptyState.noData(
            message:
                'لا توجد عقارات مطابقة للفلاتر الحالية خلال ${_filter.periodLabel}. جرّب تغيير المدينة أو المنطقة أو نوع العقار أو الفترة الزمنية',
            onResetFilters: _resetFilters,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatisticsHeader(
          propertyCount: statistics.propertyCount,
          generatedAt: statistics.generatedAt,
        ),
        const SizedBox(height: 14),
        StatisticsFilterBar(filter: _filter, onTap: _openFilterSheet),
        const SizedBox(height: 14),
        MarketOverviewCard(statistics: statistics),
        const SizedBox(height: 14),
        DataConfidenceBadge(
          sampleSize: statistics.propertyCount,
          pricePerSquareMeterSampleSize:
              statistics.pricePerSquareMeterSampleCount,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          icon: Icons.analytics_outlined,
          title: 'مؤشرات الأسعار',
          subtitle: 'ملخص لأهم أرقام السوق ضمن الفلاتر الحالية',
        ),
        const SizedBox(height: 12),
        _buildMetrics(statistics),
        if (_analytics?.hasData == true) ...[
          const SizedBox(height: 24),
          AdvancedMarketSection(analytics: _analytics!),
        ],
        if (statistics.priceHistory.isNotEmpty) ...[
          const SizedBox(height: 24),
          PriceTrendChart(points: statistics.priceHistory),
        ],
        if (statistics.areas.isNotEmpty) ...[
          const SizedBox(height: 24),
          AreasRankingSection(
            areas: statistics.areas,
            onAreaTap: (area) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AreaStatisticsScreen(statistics: area),
                ),
              );
            },
          ),
        ],
        if (statistics.insights.isNotEmpty) ...[
          const SizedBox(height: 24),
          MarketInsightsSection(insights: statistics.insights),
        ],
        const SizedBox(height: 20),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildMetrics(MarketStatistics statistics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 330 ? 1 : 2;
        final cardWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: cardWidth,
              child: StatisticMetricCard(
                title: 'الوسيط',
                value: _compactPrice(statistics.medianPrice),
                subtitle: 'السعر الأوسط',
                icon: Icons.balance_rounded,
                accentColor: _gold,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatisticMetricCard(
                title: 'أقل سعر',
                value: _compactPrice(statistics.minimumPrice),
                subtitle: 'ضمن النتائج الحالية',
                icon: Icons.south_rounded,
                accentColor: _green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatisticMetricCard(
                title: 'أعلى سعر',
                value: _compactPrice(statistics.maximumPrice),
                subtitle: 'ضمن النتائج الحالية',
                icon: Icons.north_rounded,
                accentColor: _orange,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatisticMetricCard(
                title: 'متوسط سعر المتر',
                value: statistics.pricePerSquareMeterSampleCount > 0
                    ? '${_compactPrice(statistics.averagePricePerSquareMeter)}/م²'
                    : 'غير متوفر',
                subtitle: statistics.pricePerSquareMeterSampleCount > 0
                    ? '${statistics.pricePerSquareMeterSampleCount} عقار بمساحة صالحة'
                    : 'لا توجد مساحات كافية',
                icon: Icons.square_foot_rounded,
                accentColor: _blue,
                highlighted: statistics.pricePerSquareMeterSampleCount > 0,
              ),
            ),
          ],
        );
      },
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: _gold, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: StatisticsTextStyles.sectionTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: StatisticsTextStyles.captionSize,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _gold.withValues(alpha: 0.75),
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'هذه الإحصائيات تعتمد على أسعار العقارات المنشورة والمعتمدة داخل التطبيق، وتهدف إلى إعطاء مؤشر عام عن السوق. السعر الفعلي للعقار قد يختلف حسب الموقع والحالة والمواصفات وظروف البيع أو الإيجار',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: StatisticsTextStyles.sectionSubtitleSize,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStatistics({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        PropertyStatisticsService.getMarketStatistics(
          filter: _filter,
          forceRefresh: forceRefresh,
        ),
        PropertyStatisticsService.getAdvancedAnalytics(
          filter: _filter,
          forceRefresh: forceRefresh,
        ),
      ]);
      final statistics = results[0] as MarketStatistics;
      final analytics = results[1] as PropertyMarketAnalytics;

      if (!mounted) {
        return;
      }

      setState(() {
        _statistics = statistics;
        _analytics = analytics;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('PropertyStatisticsScreen error: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _statistics = null;
        _analytics = null;
        _isLoading = false;
        _errorMessage =
            'حدث خطأ أثناء تحميل بيانات السوق. تحقق من الاتصال بالإنترنت ثم حاول مرة أخرى.';
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await StatisticsFilterSheet.show(
      context,
      initialFilter: _filter,
    );

    if (!mounted || result == null) {
      return;
    }

    if (result == _filter) {
      return;
    }

    setState(() {
      _filter = result;
    });

    await _loadStatistics();
  }

  Future<void> _resetFilters() async {
    if (_filter == StatisticsFilter.initial) {
      await _loadStatistics();
      return;
    }

    setState(() {
      _filter = StatisticsFilter.initial;
    });

    await _loadStatistics();
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
