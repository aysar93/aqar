import 'area_statistics.dart';
import 'market_insight.dart';
import 'price_history_point.dart';

/// النتيجة النهائية لتحليل سوق العقارات.
///
/// يجمع هذا النموذج جميع البيانات التي يحتاجها
/// PropertyStatisticsScreen لعرض الإحصائيات.
class MarketStatistics {
  /// إجمالي العقارات التي دخلت في الإحصائية الحالية.
  final int propertyCount;

  /// متوسط أسعار العقارات.
  final double averagePrice;

  /// وسيط أسعار العقارات.
  final double medianPrice;

  /// أقل سعر ضمن العينة.
  final double minimumPrice;

  /// أعلى سعر ضمن العينة.
  final double maximumPrice;

  /// متوسط سعر المتر المربع.
  final double averagePricePerSquareMeter;

  /// عدد العقارات التي دخلت فعليًا
  /// في حساب متوسط سعر المتر.
  final int pricePerSquareMeterSampleCount;

  /// متوسط سعر الفترة السابقة.
  final double previousAveragePrice;

  /// عدد العقارات في الفترة السابقة.
  final int previousPropertyCount;

  /// نسبة تغير متوسط السعر مقارنة بالفترة السابقة.
  ///
  /// موجب = ارتفاع.
  /// سالب = انخفاض.
  final double priceChangePercentage;

  /// الإحصائيات الخاصة بكل منطقة.
  final List<AreaStatistics> areas;

  /// البيانات الزمنية المستخدمة في الرسم البياني.
  final List<PriceHistoryPoint> priceHistory;

  /// الاستنتاجات والمؤشرات الناتجة عن التحليل.
  final List<MarketInsight> insights;

  /// وقت إنشاء هذه النتيجة.
  ///
  /// يفيد لاحقًا في عرض "آخر تحديث".
  final DateTime generatedAt;

  const MarketStatistics({
    required this.propertyCount,
    required this.averagePrice,
    required this.medianPrice,
    required this.minimumPrice,
    required this.maximumPrice,
    required this.averagePricePerSquareMeter,
    required this.pricePerSquareMeterSampleCount,
    required this.previousAveragePrice,
    required this.previousPropertyCount,
    required this.priceChangePercentage,
    required this.areas,
    required this.priceHistory,
    required this.insights,
    required this.generatedAt,
  });

  /// هل توجد بيانات سوق فعلية؟
  bool get hasData => propertyCount > 0;

  /// هل لدينا بيانات صالحة لسعر المتر؟
  bool get hasPricePerSquareMeter =>
      pricePerSquareMeterSampleCount > 0 && averagePricePerSquareMeter > 0;

  /// هل توجد بيانات للفترة السابقة؟
  bool get hasPreviousPeriodData =>
      previousPropertyCount > 0 && previousAveragePrice > 0;

  /// هل ارتفع متوسط السعر؟
  bool get isPriceIncreasing =>
      hasPreviousPeriodData && priceChangePercentage > 0;

  /// هل انخفض متوسط السعر؟
  bool get isPriceDecreasing =>
      hasPreviousPeriodData && priceChangePercentage < 0;

  /// هل متوسط السعر مستقر؟
  bool get isPriceStable => hasPreviousPeriodData && priceChangePercentage == 0;

  /// هل توجد إحصائيات مناطق؟
  bool get hasAreas => areas.isNotEmpty;

  /// هل توجد بيانات للرسم البياني؟
  bool get hasPriceHistory => priceHistory.isNotEmpty;

  /// هل توجد مؤشرات سوق؟
  bool get hasInsights => insights.isNotEmpty;

  /// مدى الأسعار بين أعلى وأقل سعر.
  double get priceRange {
    if (!hasData) {
      return 0;
    }

    return maximumPrice - minimumPrice;
  }

  /// المنطقة الأعلى من حيث متوسط السعر.
  AreaStatistics? get highestAveragePriceArea {
    if (areas.isEmpty) {
      return null;
    }

    AreaStatistics? result;

    for (final area in areas) {
      if (!area.hasData) {
        continue;
      }

      if (result == null || area.averagePrice > result.averagePrice) {
        result = area;
      }
    }

    return result;
  }

  /// المنطقة الأقل من حيث متوسط السعر.
  AreaStatistics? get lowestAveragePriceArea {
    if (areas.isEmpty) {
      return null;
    }

    AreaStatistics? result;

    for (final area in areas) {
      if (!area.hasData) {
        continue;
      }

      if (result == null || area.averagePrice < result.averagePrice) {
        result = area;
      }
    }

    return result;
  }

  /// المنطقة الأعلى من حيث متوسط سعر المتر.
  AreaStatistics? get highestPricePerSquareMeterArea {
    if (areas.isEmpty) {
      return null;
    }

    AreaStatistics? result;

    for (final area in areas) {
      if (!area.hasPricePerSquareMeter) {
        continue;
      }

      if (result == null ||
          area.averagePricePerSquareMeter > result.averagePricePerSquareMeter) {
        result = area;
      }
    }

    return result;
  }

  /// المنطقة الأكثر نشاطًا حسب عدد العقارات.
  AreaStatistics? get mostActiveArea {
    if (areas.isEmpty) {
      return null;
    }

    AreaStatistics? result;

    for (final area in areas) {
      if (!area.hasData) {
        continue;
      }

      if (result == null || area.propertyCount > result.propertyCount) {
        result = area;
      }
    }

    return result;
  }

  /// إنشاء نتيجة فارغة.
  ///
  /// تستخدم عندما لا توجد عقارات مطابقة للفلاتر.
  factory MarketStatistics.empty({
    DateTime? generatedAt,
  }) {
    return MarketStatistics(
      propertyCount: 0,
      averagePrice: 0,
      medianPrice: 0,
      minimumPrice: 0,
      maximumPrice: 0,
      averagePricePerSquareMeter: 0,
      pricePerSquareMeterSampleCount: 0,
      previousAveragePrice: 0,
      previousPropertyCount: 0,
      priceChangePercentage: 0,
      areas: const [],
      priceHistory: const [],
      insights: const [],
      generatedAt: generatedAt ?? DateTime.now(),
    );
  }

  /// إنشاء نسخة جديدة مع تعديل قيم محددة.
  MarketStatistics copyWith({
    int? propertyCount,
    double? averagePrice,
    double? medianPrice,
    double? minimumPrice,
    double? maximumPrice,
    double? averagePricePerSquareMeter,
    int? pricePerSquareMeterSampleCount,
    double? previousAveragePrice,
    int? previousPropertyCount,
    double? priceChangePercentage,
    List<AreaStatistics>? areas,
    List<PriceHistoryPoint>? priceHistory,
    List<MarketInsight>? insights,
    DateTime? generatedAt,
  }) {
    return MarketStatistics(
      propertyCount: propertyCount ?? this.propertyCount,
      averagePrice: averagePrice ?? this.averagePrice,
      medianPrice: medianPrice ?? this.medianPrice,
      minimumPrice: minimumPrice ?? this.minimumPrice,
      maximumPrice: maximumPrice ?? this.maximumPrice,
      averagePricePerSquareMeter:
          averagePricePerSquareMeter ?? this.averagePricePerSquareMeter,
      pricePerSquareMeterSampleCount:
          pricePerSquareMeterSampleCount ?? this.pricePerSquareMeterSampleCount,
      previousAveragePrice: previousAveragePrice ?? this.previousAveragePrice,
      previousPropertyCount:
          previousPropertyCount ?? this.previousPropertyCount,
      priceChangePercentage:
          priceChangePercentage ?? this.priceChangePercentage,
      areas: areas ?? this.areas,
      priceHistory: priceHistory ?? this.priceHistory,
      insights: insights ?? this.insights,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  @override
  String toString() {
    return 'MarketStatistics('
        'propertyCount: $propertyCount, '
        'averagePrice: $averagePrice, '
        'medianPrice: $medianPrice, '
        'minimumPrice: $minimumPrice, '
        'maximumPrice: $maximumPrice, '
        'averagePricePerSquareMeter: '
        '$averagePricePerSquareMeter, '
        'pricePerSquareMeterSampleCount: '
        '$pricePerSquareMeterSampleCount, '
        'previousAveragePrice: '
        '$previousAveragePrice, '
        'previousPropertyCount: '
        '$previousPropertyCount, '
        'priceChangePercentage: '
        '$priceChangePercentage, '
        'areas: ${areas.length}, '
        'priceHistory: ${priceHistory.length}, '
        'insights: ${insights.length}, '
        'generatedAt: $generatedAt'
        ')';
  }
}
