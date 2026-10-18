/// يمثل الإحصائيات المحسوبة لمنطقة واحدة داخل سوق العقارات.
///
/// مثال:
/// المدينة: الرمادي
/// المنطقة: التأميم
///
/// يحتوي على عدد العقارات والأسعار ومتوسط سعر المتر
/// ونسبة تغير الأسعار مقارنة بالفترة السابقة.
class AreaStatistics {
  /// اسم المدينة.
  final String city;

  /// اسم المنطقة / الحي.
  final String areaName;

  /// عدد العقارات التي دخلت في الإحصائية.
  final int propertyCount;

  /// متوسط أسعار العقارات.
  final double averagePrice;

  /// وسيط أسعار العقارات.
  ///
  /// الوسيط مفيد لأنه أقل تأثرًا بالعقارات
  /// ذات الأسعار المرتفعة أو المنخفضة جدًا.
  final double medianPrice;

  /// أقل سعر عقار ضمن العينة.
  final double minimumPrice;

  /// أعلى سعر عقار ضمن العينة.
  final double maximumPrice;

  /// متوسط سعر المتر المربع.
  ///
  /// يتم حسابه فقط من العقارات التي تحتوي
  /// على مساحة وسعر صالحين.
  final double averagePricePerSquareMeter;

  /// عدد العقارات التي دخلت في حساب سعر المتر.
  ///
  /// قد يكون أقل من propertyCount لأن بعض العقارات
  /// القديمة قد لا تحتوي على مساحة صحيحة.
  final int pricePerSquareMeterSampleCount;

  /// متوسط السعر في الفترة السابقة.
  ///
  /// يستخدم لحساب اتجاه السوق.
  final double previousAveragePrice;

  /// نسبة تغير متوسط السعر مقارنة بالفترة السابقة.
  ///
  /// مثال:
  /// 5.4 = ارتفاع بنسبة 5.4%
  /// -3.2 = انخفاض بنسبة 3.2%
  /// 0 = لا يوجد تغير أو لا تتوفر مقارنة كافية.
  final double priceChangePercentage;

  const AreaStatistics({
    required this.city,
    required this.areaName,
    required this.propertyCount,
    required this.averagePrice,
    required this.medianPrice,
    required this.minimumPrice,
    required this.maximumPrice,
    required this.averagePricePerSquareMeter,
    required this.pricePerSquareMeterSampleCount,
    required this.previousAveragePrice,
    required this.priceChangePercentage,
  });

  /// هل توجد بيانات فعلية لهذه المنطقة؟
  bool get hasData => propertyCount > 0;

  /// هل توجد بيانات صالحة لحساب سعر المتر؟
  bool get hasPricePerSquareMeter =>
      pricePerSquareMeterSampleCount > 0 && averagePricePerSquareMeter > 0;

  /// هل توجد بيانات من الفترة السابقة تسمح بالمقارنة؟
  bool get hasPreviousPeriodData => previousAveragePrice > 0;

  /// هل ارتفعت الأسعار؟
  bool get isPriceIncreasing =>
      hasPreviousPeriodData && priceChangePercentage > 0;

  /// هل انخفضت الأسعار؟
  bool get isPriceDecreasing =>
      hasPreviousPeriodData && priceChangePercentage < 0;

  /// هل السعر مستقر؟
  bool get isPriceStable => hasPreviousPeriodData && priceChangePercentage == 0;

  /// هل العينة صغيرة؟
  ///
  /// سنستخدم هذا لاحقًا لتنبيه المستخدم بأن
  /// الإحصائية مبنية على عدد قليل من العقارات.
  bool get hasSmallSample => propertyCount > 0 && propertyCount < 5;

  /// هل حجم العينة جيد مبدئيًا؟
  bool get hasReliableSample => propertyCount >= 5;

  /// مدى الأسعار بين أعلى وأقل سعر.
  double get priceRange {
    if (!hasData) {
      return 0;
    }

    return maximumPrice - minimumPrice;
  }

  /// إنشاء نسخة جديدة مع تعديل قيم محددة.
  AreaStatistics copyWith({
    String? city,
    String? areaName,
    int? propertyCount,
    double? averagePrice,
    double? medianPrice,
    double? minimumPrice,
    double? maximumPrice,
    double? averagePricePerSquareMeter,
    int? pricePerSquareMeterSampleCount,
    double? previousAveragePrice,
    double? priceChangePercentage,
  }) {
    return AreaStatistics(
      city: city ?? this.city,
      areaName: areaName ?? this.areaName,
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
      priceChangePercentage:
          priceChangePercentage ?? this.priceChangePercentage,
    );
  }

  /// إنشاء إحصائية فارغة لمنطقة محددة.
  factory AreaStatistics.empty({
    required String city,
    required String areaName,
  }) {
    return AreaStatistics(
      city: city,
      areaName: areaName,
      propertyCount: 0,
      averagePrice: 0,
      medianPrice: 0,
      minimumPrice: 0,
      maximumPrice: 0,
      averagePricePerSquareMeter: 0,
      pricePerSquareMeterSampleCount: 0,
      previousAveragePrice: 0,
      priceChangePercentage: 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AreaStatistics &&
        other.city == city &&
        other.areaName == areaName &&
        other.propertyCount == propertyCount &&
        other.averagePrice == averagePrice &&
        other.medianPrice == medianPrice &&
        other.minimumPrice == minimumPrice &&
        other.maximumPrice == maximumPrice &&
        other.averagePricePerSquareMeter == averagePricePerSquareMeter &&
        other.pricePerSquareMeterSampleCount ==
            pricePerSquareMeterSampleCount &&
        other.previousAveragePrice == previousAveragePrice &&
        other.priceChangePercentage == priceChangePercentage;
  }

  @override
  int get hashCode {
    return Object.hash(
      city,
      areaName,
      propertyCount,
      averagePrice,
      medianPrice,
      minimumPrice,
      maximumPrice,
      averagePricePerSquareMeter,
      pricePerSquareMeterSampleCount,
      previousAveragePrice,
      priceChangePercentage,
    );
  }

  @override
  String toString() {
    return 'AreaStatistics('
        'city: $city, '
        'areaName: $areaName, '
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
        'priceChangePercentage: '
        '$priceChangePercentage'
        ')';
  }
}
