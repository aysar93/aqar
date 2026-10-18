import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/anbar_locations.dart';
import '../models/property_model.dart';
import '../models/statistics/area_statistics.dart';
import '../models/statistics/market_insight.dart';
import '../models/statistics/market_statistics.dart';
import '../models/statistics/price_history_point.dart';
import '../models/statistics/statistics_filter.dart';

/// الخدمة المركزية المسؤولة عن تحليل بيانات سوق العقارات.
///
/// المسؤوليات:
/// - جلب العقارات المعتمدة من Firestore.
/// - تنظيف البيانات غير الصالحة.
/// - تطبيق فلاتر السوق.
/// - حساب المتوسط والوسيط.
/// - حساب متوسط سعر المتر.
/// - مقارنة الفترة الحالية بالفترة السابقة.
/// - تجميع الإحصائيات حسب المناطق.
/// - إنشاء بيانات حركة الأسعار.
/// - إنشاء مؤشرات السوق.
class PropertyStatisticsService {
  PropertyStatisticsService._();

  static final CollectionReference<Map<String, dynamic>> _properties =
      FirebaseFirestore.instance.collection('properties');

  /// الطلب الجاري للعقارات المعتمدة، ويُشارك بين عمليات التحليل المتزامنة.
  static Future<List<PropertyModel>>? _approvedPropertiesRequest;
  static List<PropertyModel>? _approvedPropertiesCache;
  static DateTime? _approvedPropertiesCachedAt;
  static const Duration approvedPropertiesCacheDuration = Duration(minutes: 2);

  /// الحد الأدنى المقبول للسعر.
  ///
  /// نستبعد السعر صفر أو القيم السالبة من الإحصائيات.
  static const double minimumValidPrice = 1;

  /// الحد الأدنى للمساحة المستخدمة في حساب سعر المتر.
  static const int minimumValidArea = 1;

  /// لا نستبعد أي قيمة شاذة من مجموعة أصغر من هذا الحد.
  static const int minimumOutlierSampleSize = 8;

  /// جلب وتحليل إحصائيات السوق حسب الفلاتر المحددة.
  static Future<MarketStatistics> getMarketStatistics({
    StatisticsFilter filter = StatisticsFilter.initial,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();

    final allProperties = await _loadApprovedProperties(
      forceRefresh: forceRefresh,
    );

    final baseFilteredProperties = allProperties
        .where((property) => _matchesBaseFilters(property, filter))
        .toList();

    final rawCurrentProperties = baseFilteredProperties
        .where((property) => _isInCurrentPeriod(property, filter, now))
        .toList();

    final rawPreviousProperties = baseFilteredProperties
        .where((property) => _isInPreviousPeriod(property, filter, now))
        .toList();

    final currentProperties = _removePriceOutliers(rawCurrentProperties);
    final previousProperties = _removePriceOutliers(rawPreviousProperties);

    if (currentProperties.isEmpty) {
      return MarketStatistics.empty(generatedAt: now);
    }

    final prices = currentProperties
        .map((property) => property.price)
        .where((price) => price >= minimumValidPrice)
        .toList();

    final averagePrice = _average(prices);
    final medianPrice = _median(prices);
    final minimumPrice = _minimum(prices);
    final maximumPrice = _maximum(prices);

    final pricePerSquareMeterValues = _pricePerSquareMeterValues(
      currentProperties,
    );

    final averagePricePerSquareMeter = _average(pricePerSquareMeterValues);

    final previousPrices = previousProperties
        .map((property) => property.price)
        .where((price) => price >= minimumValidPrice)
        .toList();

    final previousAveragePrice = _average(previousPrices);

    final priceChangePercentage = _calculatePercentageChange(
      currentValue: averagePrice,
      previousValue: previousAveragePrice,
    );

    final areas = _buildAreaStatistics(
      currentProperties: currentProperties,
      previousProperties: previousProperties,
    );

    final priceHistory = _buildPriceHistory(
      properties: currentProperties,
      filter: filter,
      now: now,
    );

    final insights = _buildInsights(
      propertyCount: currentProperties.length,
      averagePrice: averagePrice,
      previousAveragePrice: previousAveragePrice,
      priceChangePercentage: priceChangePercentage,
      areas: areas,
    );

    return MarketStatistics(
      propertyCount: currentProperties.length,
      averagePrice: averagePrice,
      medianPrice: medianPrice,
      minimumPrice: minimumPrice,
      maximumPrice: maximumPrice,
      averagePricePerSquareMeter: averagePricePerSquareMeter,
      pricePerSquareMeterSampleCount: pricePerSquareMeterValues.length,
      previousAveragePrice: previousAveragePrice,
      previousPropertyCount: previousProperties.length,
      priceChangePercentage: priceChangePercentage,
      areas: areas,
      priceHistory: priceHistory,
      insights: insights,
      generatedAt: now,
    );
  }

  /// العقار صالح للدخول في إحصائيات السوق.
  static bool _isValidForMarketStatistics(PropertyModel property) {
    if (property.status.trim().toLowerCase() != 'approved') {
      return false;
    }

    if (property.price < minimumValidPrice) {
      return false;
    }

    return true;
  }

  /// تطبيق الفلاتر التي لا تتعلق بالفترة الزمنية.
  static bool _matchesBaseFilters(
    PropertyModel property,
    StatisticsFilter filter,
  ) {
    if (filter.hasAdType &&
        _normalize(property.adType) != _normalize(filter.adType)) {
      return false;
    }

    if (filter.hasPropertyType &&
        _normalize(property.propertyType) != _normalize(filter.propertyType)) {
      return false;
    }

    if (filter.hasCity) {
      final propertyCity = AnbarLocations.normalizeCity(property.city);

      final selectedCity = AnbarLocations.normalizeCity(filter.city);

      if (propertyCity != selectedCity) {
        return false;
      }
    }

    if (filter.hasArea) {
      final propertyArea = AnbarLocations.normalizeArea(
        city: property.city,
        area: property.areaName,
      );

      final selectedArea = AnbarLocations.normalizeArea(
        city: filter.city ?? property.city,
        area: filter.areaName,
      );

      if (AnbarLocations.normalizeText(propertyArea) !=
          AnbarLocations.normalizeText(selectedArea)) {
        return false;
      }
    }

    return true;
  }

  /// هل العقار ضمن الفترة الحالية؟
  static bool _isInCurrentPeriod(
    PropertyModel property,
    StatisticsFilter filter,
    DateTime now,
  ) {
    if (filter.period == StatisticsPeriod.allTime) {
      return true;
    }

    final createdAt = property.createdAt;

    if (createdAt == null) {
      return false;
    }

    final propertyDate = createdAt.toDate();
    final start = filter.startDate(now);

    if (start == null) {
      return true;
    }

    return !propertyDate.isBefore(start) && !propertyDate.isAfter(now);
  }

  /// هل العقار ضمن الفترة السابقة؟
  static bool _isInPreviousPeriod(
    PropertyModel property,
    StatisticsFilter filter,
    DateTime now,
  ) {
    if (filter.period == StatisticsPeriod.allTime) {
      return false;
    }

    final createdAt = property.createdAt;

    if (createdAt == null) {
      return false;
    }

    final start = filter.previousPeriodStart(now);
    final end = filter.previousPeriodEnd(now);

    if (start == null || end == null) {
      return false;
    }

    final propertyDate = createdAt.toDate();

    return !propertyDate.isBefore(start) && propertyDate.isBefore(end);
  }

  /// إنشاء إحصائيات المناطق.
  static List<AreaStatistics> _buildAreaStatistics({
    required List<PropertyModel> currentProperties,
    required List<PropertyModel> previousProperties,
  }) {
    final currentGroups = <String, List<PropertyModel>>{};

    final previousGroups = <String, List<PropertyModel>>{};

    for (final property in currentProperties) {
      final key = _areaKey(property);

      if (key == null) {
        continue;
      }

      currentGroups.putIfAbsent(key, () => <PropertyModel>[]).add(property);
    }

    for (final property in previousProperties) {
      final key = _areaKey(property);

      if (key == null) {
        continue;
      }

      previousGroups.putIfAbsent(key, () => <PropertyModel>[]).add(property);
    }

    final result = <AreaStatistics>[];

    for (final entry in currentGroups.entries) {
      final current = entry.value;

      if (current.isEmpty) {
        continue;
      }

      final first = current.first;

      final city =
          AnbarLocations.normalizeCity(first.city) ?? first.city.trim();

      final areaName = AnbarLocations.normalizeArea(
        city: first.city,
        area: first.areaName,
      );

      final prices = current
          .map((property) => property.price)
          .where((price) => price >= minimumValidPrice)
          .toList();

      final pricePerSquareMeterValues = _pricePerSquareMeterValues(current);

      final previous = previousGroups[entry.key] ?? const <PropertyModel>[];

      final previousPrices = previous
          .map((property) => property.price)
          .where((price) => price >= minimumValidPrice)
          .toList();

      final averagePrice = _average(prices);

      final previousAveragePrice = _average(previousPrices);

      result.add(
        AreaStatistics(
          city: city,
          areaName: areaName,
          propertyCount: current.length,
          averagePrice: averagePrice,
          medianPrice: _median(prices),
          minimumPrice: _minimum(prices),
          maximumPrice: _maximum(prices),
          averagePricePerSquareMeter: _average(pricePerSquareMeterValues),
          pricePerSquareMeterSampleCount: pricePerSquareMeterValues.length,
          previousAveragePrice: previousAveragePrice,
          priceChangePercentage: _calculatePercentageChange(
            currentValue: averagePrice,
            previousValue: previousAveragePrice,
          ),
        ),
      );
    }

    result.sort((a, b) => b.propertyCount.compareTo(a.propertyCount));

    return List<AreaStatistics>.unmodifiable(result);
  }

  /// مفتاح موحد لتجميع العقارات حسب المدينة والمنطقة.
  static String? _areaKey(PropertyModel property) {
    final city =
        AnbarLocations.normalizeCity(property.city) ?? property.city.trim();

    final area = AnbarLocations.normalizeArea(
      city: property.city,
      area: property.areaName,
    );

    if (city.isEmpty || area.isEmpty) {
      return null;
    }

    return '${AnbarLocations.normalizeText(city)}'
        '::'
        '${AnbarLocations.normalizeText(area)}';
  }

  /// إنشاء البيانات الزمنية للرسم البياني.
  static List<PriceHistoryPoint> _buildPriceHistory({
    required List<PropertyModel> properties,
    required StatisticsFilter filter,
    required DateTime now,
  }) {
    if (properties.isEmpty) {
      return const [];
    }

    final groups = <DateTime, List<PropertyModel>>{};

    for (final property in properties) {
      final timestamp = property.createdAt;

      if (timestamp == null) {
        continue;
      }

      final date = timestamp.toDate();

      final bucket = _historyBucket(date: date, period: filter.period);

      groups.putIfAbsent(bucket, () => <PropertyModel>[]).add(property);
    }

    final points = <PriceHistoryPoint>[];

    for (final entry in groups.entries) {
      final groupProperties = entry.value;

      final prices = groupProperties
          .map((property) => property.price)
          .where((price) => price >= minimumValidPrice)
          .toList();

      final pricePerSquareMeterValues = _pricePerSquareMeterValues(
        groupProperties,
      );

      points.add(
        PriceHistoryPoint(
          date: entry.key,
          averagePrice: _average(prices),
          medianPrice: _median(prices),
          averagePricePerSquareMeter: _average(pricePerSquareMeterValues),
          propertyCount: groupProperties.length,
        ),
      );
    }

    points.sort((a, b) => a.date.compareTo(b.date));

    if (points.isEmpty) return const [];

    final requestedStart = filter.startDate(now);
    final firstBucket = requestedStart == null
        ? points.first.date
        : _historyBucket(date: requestedStart, period: filter.period);
    final lastBucket = _historyBucket(date: now, period: filter.period);
    final pointsByDate = <DateTime, PriceHistoryPoint>{
      for (final point in points) point.date: point,
    };
    final completePoints = <PriceHistoryPoint>[];
    var bucket = firstBucket;
    while (!bucket.isAfter(lastBucket)) {
      completePoints.add(
        pointsByDate[bucket] ?? PriceHistoryPoint.empty(date: bucket),
      );
      bucket = _nextHistoryBucket(bucket, filter.period);
    }

    return List<PriceHistoryPoint>.unmodifiable(completePoints);
  }

  static DateTime _nextHistoryBucket(DateTime date, StatisticsPeriod period) {
    switch (period) {
      case StatisticsPeriod.last7Days:
      case StatisticsPeriod.last30Days:
        return date.add(const Duration(days: 1));
      case StatisticsPeriod.last90Days:
      case StatisticsPeriod.last6Months:
      case StatisticsPeriod.lastYear:
      case StatisticsPeriod.allTime:
        return DateTime(date.year, date.month + 1);
    }
  }

  /// تحديد حجم الفترة المستخدمة في الرسم.
  ///
  /// الفترات القصيرة تجمع يوميًا،
  /// والفترات الطويلة تجمع شهريًا.
  static DateTime _historyBucket({
    required DateTime date,
    required StatisticsPeriod period,
  }) {
    switch (period) {
      case StatisticsPeriod.last7Days:
      case StatisticsPeriod.last30Days:
        return DateTime(date.year, date.month, date.day);

      case StatisticsPeriod.last90Days:
      case StatisticsPeriod.last6Months:
      case StatisticsPeriod.lastYear:
      case StatisticsPeriod.allTime:
        return DateTime(date.year, date.month);
    }
  }

  /// إنشاء المؤشرات الذكية للسوق.
  static List<MarketInsight> _buildInsights({
    required int propertyCount,
    required double averagePrice,
    required double previousAveragePrice,
    required double priceChangePercentage,
    required List<AreaStatistics> areas,
  }) {
    final insights = <MarketInsight>[];

    if (propertyCount < 5) {
      insights.add(
        MarketInsight.limitedData(
          description:
              'الإحصائية الحالية مبنية على عدد قليل من العقارات، لذلك قد لا تعكس حركة السوق بشكل كامل',
          propertyCount: propertyCount,
        ),
      );
    }

    if (previousAveragePrice > 0) {
      if (priceChangePercentage > 0) {
        insights.add(
          MarketInsight(
            type: MarketInsightType.priceIncrease,
            level: MarketInsightLevel.positive,
            title: 'ارتفاع متوسط الأسعار',
            description: 'ارتفع متوسط أسعار العقارات مقارنة بالفترة السابقة',
            value: priceChangePercentage,
            propertyCount: propertyCount,
          ),
        );
      } else if (priceChangePercentage < 0) {
        insights.add(
          MarketInsight(
            type: MarketInsightType.priceDecrease,
            level: MarketInsightLevel.negative,
            title: 'انخفاض متوسط الأسعار',
            description: 'انخفض متوسط أسعار العقارات مقارنة بالفترة السابقة',
            value: priceChangePercentage,
            propertyCount: propertyCount,
          ),
        );
      } else {
        insights.add(
          MarketInsight(
            type: MarketInsightType.priceStable,
            level: MarketInsightLevel.info,
            title: 'استقرار الأسعار',
            description:
                'لم يسجل متوسط الأسعار تغيرًا واضحًا مقارنة بالفترة السابقة',
            value: 0,
            propertyCount: propertyCount,
          ),
        );
      }
    }

    final validAreas = areas.where((area) => area.hasData).toList();

    if (validAreas.isNotEmpty) {
      final highestPriceArea = validAreas.reduce(
        (current, next) =>
            next.averagePrice > current.averagePrice ? next : current,
      );

      insights.add(
        MarketInsight(
          type: MarketInsightType.highestPriceArea,
          level: MarketInsightLevel.info,
          title: 'الأعلى في متوسط السعر',
          description:
              '${highestPriceArea.areaName} تتصدر المناطق من حيث متوسط سعر العقار',
          value: highestPriceArea.averagePrice,
          city: highestPriceArea.city,
          areaName: highestPriceArea.areaName,
          propertyCount: highestPriceArea.propertyCount,
        ),
      );

      final lowestPriceArea = validAreas.reduce(
        (current, next) =>
            next.averagePrice < current.averagePrice ? next : current,
      );

      if (lowestPriceArea.areaName != highestPriceArea.areaName ||
          lowestPriceArea.city != highestPriceArea.city) {
        insights.add(
          MarketInsight(
            type: MarketInsightType.lowestPriceArea,
            level: MarketInsightLevel.info,
            title: 'الأقل في متوسط السعر',
            description:
                '${lowestPriceArea.areaName} تسجل أقل متوسط سعر ضمن النتائج الحالية',
            value: lowestPriceArea.averagePrice,
            city: lowestPriceArea.city,
            areaName: lowestPriceArea.areaName,
            propertyCount: lowestPriceArea.propertyCount,
          ),
        );
      }

      final activeArea = validAreas.reduce(
        (current, next) =>
            next.propertyCount > current.propertyCount ? next : current,
      );

      insights.add(
        MarketInsight(
          type: MarketInsightType.mostActiveArea,
          level: MarketInsightLevel.info,
          title: 'المنطقة الأكثر نشاطًا',
          description:
              '${activeArea.areaName} تحتوي على أكبر عدد من العقارات ضمن النتائج الحالية',
          value: activeArea.propertyCount.toDouble(),
          city: activeArea.city,
          areaName: activeArea.areaName,
          propertyCount: activeArea.propertyCount,
        ),
      );

      final areasWithPricePerMeter =
          validAreas.where((area) => area.hasPricePerSquareMeter).toList();

      if (areasWithPricePerMeter.isNotEmpty) {
        final highestPricePerMeter = areasWithPricePerMeter.reduce(
          (current, next) => next.averagePricePerSquareMeter >
                  current.averagePricePerSquareMeter
              ? next
              : current,
        );

        insights.add(
          MarketInsight(
            type: MarketInsightType.highestPricePerSquareMeter,
            level: MarketInsightLevel.info,
            title: 'أعلى سعر للمتر',
            description:
                '${highestPricePerMeter.areaName} تسجل أعلى متوسط سعر للمتر المربع',
            value: highestPricePerMeter.averagePricePerSquareMeter,
            city: highestPricePerMeter.city,
            areaName: highestPricePerMeter.areaName,
            propertyCount: highestPricePerMeter.pricePerSquareMeterSampleCount,
          ),
        );
      }
    }

    return List<MarketInsight>.unmodifiable(insights);
  }

  /// استخراج أسعار المتر الصالحة من العقارات.
  static List<double> _pricePerSquareMeterValues(
    List<PropertyModel> properties,
  ) {
    final values = <double>[];

    for (final property in properties) {
      if (property.price < minimumValidPrice) {
        continue;
      }

      if (property.area < minimumValidArea) {
        continue;
      }

      final value = property.price / property.area;

      if (value.isFinite && value > 0) {
        values.add(value);
      }
    }

    return values;
  }

  /// المتوسط الحسابي.
  static double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    var total = 0.0;

    for (final value in values) {
      total += value;
    }

    return total / values.length;
  }

  /// الوسيط.
  static double _median(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    final sorted = List<double>.from(values)..sort();

    final middle = sorted.length ~/ 2;

    if (sorted.length.isOdd) {
      return sorted[middle];
    }

    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  /// أقل قيمة.
  static double _minimum(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    var result = values.first;

    for (final value in values.skip(1)) {
      if (value < result) {
        result = value;
      }
    }

    return result;
  }

  /// أعلى قيمة.
  static double _maximum(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    var result = values.first;

    for (final value in values.skip(1)) {
      if (value > result) {
        result = value;
      }
    }

    return result;
  }

  /// حساب نسبة التغير بين قيمتين.
  static double _calculatePercentageChange({
    required double currentValue,
    required double previousValue,
  }) {
    if (previousValue <= 0) {
      return 0;
    }

    return ((currentValue - previousValue) / previousValue) * 100;
  }

  /// تنظيف نصوص الفلاتر البسيطة مثل
  /// نوع الإعلان ونوع العقار.
  static String _normalize(String? value) {
    return AnbarLocations.normalizeText(value);
  }

  /// تحليلات موسعة لا تغيّر [MarketStatistics] ولا تكسر الواجهة الحالية.
  /// يمكن للبطاقات الجديدة استدعاء هذه الدالة تدريجيًا عند الحاجة.
  static Future<PropertyMarketAnalytics> getAdvancedAnalytics({
    StatisticsFilter filter = StatisticsFilter.initial,
    int rankingLimit = 5,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final baseProperties =
        (await _loadApprovedProperties(forceRefresh: forceRefresh))
            .where((property) => _matchesBaseFilters(property, filter))
            .toList(growable: false);
    final rawProperties = baseProperties
        .where((property) => _isInCurrentPeriod(property, filter, now))
        .toList(growable: false);
    final rawPreviousProperties = baseProperties
        .where((property) => _isInPreviousPeriod(property, filter, now))
        .toList(growable: false);
    return analyzeProperties(
      currentProperties: rawProperties,
      previousProperties: rawPreviousProperties,
      generatedAt: now,
      rankingLimit: rankingLimit,
    );
  }

  /// مدخل نقي قابل للاختبار لتحليل قوائم عقارات جاهزة دون قراءة Firestore.
  static PropertyMarketAnalytics analyzeProperties({
    required List<PropertyModel> currentProperties,
    List<PropertyModel> previousProperties = const [],
    DateTime? generatedAt,
    int rankingLimit = 5,
  }) {
    final cleanedCurrent = _removePriceOutliers(currentProperties);
    final cleanedPrevious = _removePriceOutliers(previousProperties);
    return PropertyMarketAnalytics.fromProperties(
      cleanedCurrent,
      previousProperties: cleanedPrevious,
      generatedAt: generatedAt ?? DateTime.now(),
      rankingLimit: rankingLimit,
      excludedPriceOutlierCount:
          currentProperties.length - cleanedCurrent.length,
    );
  }

  /// يستبعد القيم خارج 1.5 من المدى الربيعي، داخل كل نوع إعلان وعقار.
  /// التقسيم يمنع مقارنة أسعار الإيجار بأسعار البيع أو الأرض بالشقق.
  static List<PropertyModel> _removePriceOutliers(
    List<PropertyModel> properties,
  ) {
    if (properties.length < minimumOutlierSampleSize) {
      return List<PropertyModel>.unmodifiable(properties);
    }

    final groups = <String, List<PropertyModel>>{};
    for (final property in properties) {
      final key = '${_normalize(property.adType)}::'
          '${_normalize(property.propertyType)}';
      groups.putIfAbsent(key, () => []).add(property);
    }

    final acceptedIds = <String>{};
    for (final group in groups.values) {
      if (group.length < minimumOutlierSampleSize) {
        acceptedIds.addAll(group.map((property) => property.id));
        continue;
      }

      final prices = group.map((property) => property.price).toList()..sort();
      final firstQuartile = _percentile(prices, .25);
      final thirdQuartile = _percentile(prices, .75);
      final range = thirdQuartile - firstQuartile;
      if (range <= 0) {
        acceptedIds.addAll(group.map((property) => property.id));
        continue;
      }

      final lowerFence = firstQuartile - (1.5 * range);
      final upperFence = thirdQuartile + (1.5 * range);
      acceptedIds.addAll(
        group
            .where(
              (property) =>
                  property.price >= lowerFence && property.price <= upperFence,
            )
            .map((property) => property.id),
      );
    }

    return List<PropertyModel>.unmodifiable(
      properties.where((property) => acceptedIds.contains(property.id)),
    );
  }

  static double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0;
    final position = (sortedValues.length - 1) * percentile;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sortedValues[lower];
    final fraction = position - lower;
    return sortedValues[lower] +
        ((sortedValues[upper] - sortedValues[lower]) * fraction);
  }

  static Future<List<PropertyModel>> _loadApprovedProperties({
    bool forceRefresh = false,
  }) async {
    final runningRequest = _approvedPropertiesRequest;
    if (runningRequest != null) return await runningRequest;

    final cached = _approvedPropertiesCache;
    final cachedAt = _approvedPropertiesCachedAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < approvedPropertiesCacheDuration) {
      return cached;
    }

    final request = _fetchApprovedProperties();
    _approvedPropertiesRequest = request;
    try {
      final properties = await request;
      _approvedPropertiesCache = properties;
      _approvedPropertiesCachedAt = DateTime.now();
      return properties;
    } finally {
      if (identical(_approvedPropertiesRequest, request)) {
        _approvedPropertiesRequest = null;
      }
    }
  }

  static Future<List<PropertyModel>> _fetchApprovedProperties() async {
    final snapshot =
        await _properties.where('status', isEqualTo: 'approved').get();
    return List<PropertyModel>.unmodifiable(
      snapshot.docs
          .map((doc) => PropertyModel.fromMap(doc.data(), doc.id))
          .where(_isValidForMarketStatistics),
    );
  }
}

/// نتيجة التحليل الموسع. جميع القوائم والخرائط غير قابلة للتعديل.
class PropertyMarketAnalytics {
  final int propertyCount;
  final double averageArea;
  final double averageRooms;
  final double averageBathrooms;
  final double averageLivingRooms;
  final double averageParking;
  final int totalViews;
  final Map<String, int> propertyTypeDistribution;
  final Map<String, int> adTypeDistribution;
  final Map<String, MarketSegmentStatistics> segmentStatistics;
  final Map<String, Map<String, int>> priceBandsBySegment;
  final Map<String, int> areaBandDistribution;
  final List<AreaTrendSummary> growingAreas;
  final List<AreaTrendSummary> decliningAreas;
  final List<AreaTrendSummary> insufficientTrendAreas;
  final int excludedPriceOutlierCount;
  final List<MarketRankingItem> mostActiveCities;
  final List<MarketRankingItem> mostActiveAreas;
  final List<MarketRankingItem> mostActiveOffices;
  final List<ViewedPropertySummary> mostViewedProperties;
  final DateTime generatedAt;

  const PropertyMarketAnalytics({
    required this.propertyCount,
    required this.averageArea,
    required this.averageRooms,
    required this.averageBathrooms,
    required this.averageLivingRooms,
    required this.averageParking,
    required this.totalViews,
    required this.propertyTypeDistribution,
    required this.adTypeDistribution,
    required this.segmentStatistics,
    required this.priceBandsBySegment,
    required this.areaBandDistribution,
    required this.growingAreas,
    required this.decliningAreas,
    required this.insufficientTrendAreas,
    required this.excludedPriceOutlierCount,
    required this.mostActiveCities,
    required this.mostActiveAreas,
    required this.mostActiveOffices,
    required this.mostViewedProperties,
    required this.generatedAt,
  });

  bool get hasData => propertyCount > 0;

  factory PropertyMarketAnalytics.fromProperties(
    List<PropertyModel> properties, {
    List<PropertyModel> previousProperties = const [],
    required DateTime generatedAt,
    int rankingLimit = 5,
    int excludedPriceOutlierCount = 0,
  }) {
    final safeLimit = rankingLimit < 1 ? 1 : rankingLimit;
    final types = <String, int>{};
    final adTypes = <String, int>{};
    final cities = <String, List<PropertyModel>>{};
    final areas = <String, List<PropertyModel>>{};
    final offices = <String, List<PropertyModel>>{};
    final segments = <String, List<PropertyModel>>{};
    final areaBands = <String, int>{};

    for (final property in properties) {
      _increment(types, _label(property.propertyType));
      _increment(adTypes, _label(property.adType));
      segments
          .putIfAbsent(_segmentLabel(property.adType), () => [])
          .add(property);
      if (property.area > 0) {
        _increment(areaBands, _areaBand(property.area));
      }
      cities.putIfAbsent(_label(property.city), () => []).add(property);
      final areaLabel = _label(property.areaName);
      areas
          .putIfAbsent('${_label(property.city)} - $areaLabel', () => [])
          .add(property);
      if (property.officeName.trim().isNotEmpty ||
          property.officeId.trim().isNotEmpty) {
        final office = property.officeName.trim().isEmpty
            ? property.officeId.trim()
            : property.officeName.trim();
        offices.putIfAbsent(office, () => []).add(property);
      }
    }

    double averageInt(int Function(PropertyModel) read) {
      final values = properties.map(read).where((value) => value > 0).toList();
      if (values.isEmpty) return 0;
      return values.fold<int>(0, (total, value) => total + value) /
          values.length;
    }

    final viewed = List<PropertyModel>.from(properties)
      ..sort((a, b) => b.views.compareTo(a.views));
    final trends = _buildAreaTrends(properties, previousProperties);
    final growing = trends.where((trend) => trend.isGrowing).toList()
      ..sort((a, b) => b.changePercentage.compareTo(a.changePercentage));
    final declining = trends.where((trend) => trend.isDeclining).toList()
      ..sort((a, b) => a.changePercentage.compareTo(b.changePercentage));
    final insufficient =
        trends.where((trend) => !trend.hasReliableSample).toList()
          ..sort(
            (a, b) => b.currentPropertyCount.compareTo(a.currentPropertyCount),
          );

    return PropertyMarketAnalytics(
      propertyCount: properties.length,
      averageArea: averageInt((property) => property.area),
      averageRooms: averageInt((property) => property.rooms),
      averageBathrooms: averageInt((property) => property.bathrooms),
      averageLivingRooms: averageInt((property) => property.livingRooms),
      averageParking: averageInt((property) => property.parking),
      totalViews: properties.fold<int>(
        0,
        (total, property) => total + property.views,
      ),
      propertyTypeDistribution: Map.unmodifiable(types),
      adTypeDistribution: Map.unmodifiable(adTypes),
      segmentStatistics: Map.unmodifiable(
        segments.map(
          (label, items) => MapEntry(
            label,
            MarketSegmentStatistics.fromProperties(label, items),
          ),
        ),
      ),
      priceBandsBySegment: Map.unmodifiable(
        segments.map(
          (label, items) => MapEntry(
            label,
            Map<String, int>.unmodifiable(_buildPriceBands(label, items)),
          ),
        ),
      ),
      areaBandDistribution: Map.unmodifiable(areaBands),
      growingAreas: List.unmodifiable(growing.take(safeLimit)),
      decliningAreas: List.unmodifiable(declining.take(safeLimit)),
      insufficientTrendAreas: List.unmodifiable(insufficient.take(safeLimit)),
      excludedPriceOutlierCount: excludedPriceOutlierCount,
      mostActiveCities: _rank(cities, safeLimit),
      mostActiveAreas: _rank(areas, safeLimit),
      mostActiveOffices: _rank(offices, safeLimit),
      mostViewedProperties: List.unmodifiable(
        viewed.take(safeLimit).map(ViewedPropertySummary.fromProperty),
      ),
      generatedAt: generatedAt,
    );
  }

  static void _increment(Map<String, int> target, String key) {
    target.update(key, (value) => value + 1, ifAbsent: () => 1);
  }

  static String _label(String value) =>
      value.trim().isEmpty ? 'غير محدد' : value.trim();

  static String _segmentLabel(String value) {
    final normalized = AnbarLocations.normalizeText(value);
    if (normalized.contains('بيع')) return 'للبيع';
    if (normalized.contains('ايجار')) return 'للإيجار';
    return _label(value);
  }

  static String _areaBand(int area) {
    if (area < 100) return 'أقل من 100 م²';
    if (area < 200) return '100–199 م²';
    if (area < 300) return '200–299 م²';
    if (area < 500) return '300–499 م²';
    return '500 م² فأكثر';
  }

  static Map<String, int> _buildPriceBands(
    String segment,
    List<PropertyModel> properties,
  ) {
    final result = <String, int>{};
    final isRent = AnbarLocations.normalizeText(segment).contains('ايجار');
    for (final property in properties) {
      final price = property.price;
      final label = isRent
          ? price < 500000
              ? 'أقل من 500 ألف'
              : price < 1000000
                  ? '500–999 ألف'
                  : price < 2000000
                      ? '1–1.9 مليون'
                      : price < 5000000
                          ? '2–4.9 مليون'
                          : '5 ملايين فأكثر'
          : price < 50000000
              ? 'أقل من 50 مليون'
              : price < 100000000
                  ? '50–99 مليون'
                  : price < 250000000
                      ? '100–249 مليون'
                      : price < 500000000
                          ? '250–499 مليون'
                          : '500 مليون فأكثر';
      _increment(result, label);
    }
    return result;
  }

  static List<AreaTrendSummary> _buildAreaTrends(
    List<PropertyModel> current,
    List<PropertyModel> previous,
  ) {
    String key(PropertyModel property) {
      final city =
          AnbarLocations.normalizeCity(property.city) ?? property.city.trim();
      final area = AnbarLocations.normalizeArea(
        city: property.city,
        area: property.areaName,
      );
      return '${AnbarLocations.normalizeText(city)}::'
          '${AnbarLocations.normalizeText(area)}';
    }

    final currentGroups = <String, List<PropertyModel>>{};
    final previousGroups = <String, List<PropertyModel>>{};
    for (final property in current) {
      currentGroups.putIfAbsent(key(property), () => []).add(property);
    }
    for (final property in previous) {
      previousGroups.putIfAbsent(key(property), () => []).add(property);
    }

    final keys = <String>{...currentGroups.keys, ...previousGroups.keys};
    return keys.map((groupKey) {
      final currentItems = currentGroups[groupKey] ?? const <PropertyModel>[];
      final previousItems = previousGroups[groupKey] ?? const <PropertyModel>[];
      final sample =
          currentItems.isNotEmpty ? currentItems.first : previousItems.first;
      double average(List<PropertyModel> items) => items.isEmpty
          ? 0
          : items.fold<double>(0, (total, item) => total + item.price) /
              items.length;
      final currentAverage = average(currentItems);
      final previousAverage = average(previousItems);
      final reliable = currentItems.length >= 5 && previousItems.length >= 5;
      final change = reliable && previousAverage > 0
          ? ((currentAverage - previousAverage) / previousAverage) * 100
          : 0.0;
      return AreaTrendSummary(
        city: sample.city.trim(),
        areaName: sample.areaName.trim(),
        currentPropertyCount: currentItems.length,
        previousPropertyCount: previousItems.length,
        currentAveragePrice: currentAverage,
        previousAveragePrice: previousAverage,
        changePercentage: change,
        hasReliableSample: reliable,
      );
    }).toList(growable: false);
  }

  static List<MarketRankingItem> _rank(
    Map<String, List<PropertyModel>> groups,
    int limit,
  ) {
    final result = groups.entries.map((entry) {
      final prices = entry.value
          .map((property) => property.price)
          .where((price) => price > 0)
          .toList(growable: false);
      final total = prices.fold<double>(0, (value, price) => value + price);
      return MarketRankingItem(
        label: entry.key,
        propertyCount: entry.value.length,
        averagePrice: prices.isEmpty ? 0 : total / prices.length,
      );
    }).toList()
      ..sort((a, b) => b.propertyCount.compareTo(a.propertyCount));
    return List.unmodifiable(result.take(limit));
  }
}

class MarketSegmentStatistics {
  final String label;
  final int propertyCount;
  final double averagePrice;
  final double medianPrice;
  final double averagePricePerSquareMeter;
  final int pricePerSquareMeterSampleCount;

  const MarketSegmentStatistics({
    required this.label,
    required this.propertyCount,
    required this.averagePrice,
    required this.medianPrice,
    required this.averagePricePerSquareMeter,
    required this.pricePerSquareMeterSampleCount,
  });

  factory MarketSegmentStatistics.fromProperties(
    String label,
    List<PropertyModel> properties,
  ) {
    final prices = properties
        .map((property) => property.price)
        .where((price) => price > 0)
        .toList()
      ..sort();
    final squareMeterPrices = properties
        .where((property) => property.price > 0 && property.area > 0)
        .map((property) => property.price / property.area)
        .toList(growable: false);

    double average(List<double> values) => values.isEmpty
        ? 0
        : values.fold<double>(0, (total, value) => total + value) /
            values.length;
    double median(List<double> values) {
      if (values.isEmpty) return 0;
      final middle = values.length ~/ 2;
      return values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2;
    }

    return MarketSegmentStatistics(
      label: label,
      propertyCount: properties.length,
      averagePrice: average(prices),
      medianPrice: median(prices),
      averagePricePerSquareMeter: average(squareMeterPrices),
      pricePerSquareMeterSampleCount: squareMeterPrices.length,
    );
  }
}

class AreaTrendSummary {
  final String city;
  final String areaName;
  final int currentPropertyCount;
  final int previousPropertyCount;
  final double currentAveragePrice;
  final double previousAveragePrice;
  final double changePercentage;
  final bool hasReliableSample;

  const AreaTrendSummary({
    required this.city,
    required this.areaName,
    required this.currentPropertyCount,
    required this.previousPropertyCount,
    required this.currentAveragePrice,
    required this.previousAveragePrice,
    required this.changePercentage,
    required this.hasReliableSample,
  });

  bool get isGrowing => hasReliableSample && changePercentage > 0;
  bool get isDeclining => hasReliableSample && changePercentage < 0;
  String get displayName => [
        city.trim(),
        areaName.trim(),
      ].where((value) => value.isNotEmpty).join(' - ');
}

class MarketRankingItem {
  final String label;
  final int propertyCount;
  final double averagePrice;

  const MarketRankingItem({
    required this.label,
    required this.propertyCount,
    required this.averagePrice,
  });
}

class ViewedPropertySummary {
  final String id;
  final String title;
  final String city;
  final String areaName;
  final int views;
  final double price;

  const ViewedPropertySummary({
    required this.id,
    required this.title,
    required this.city,
    required this.areaName,
    required this.views,
    required this.price,
  });

  factory ViewedPropertySummary.fromProperty(PropertyModel property) =>
      ViewedPropertySummary(
        id: property.id,
        title: property.title,
        city: property.city,
        areaName: property.areaName,
        views: property.views,
        price: property.price,
      );
}
