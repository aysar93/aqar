/// أنواع المؤشرات التي يمكن أن ينتجها محرك
/// إحصائيات السوق العقاري.
enum MarketInsightType {
  priceIncrease,
  priceDecrease,
  priceStable,
  highestPriceArea,
  lowestPriceArea,
  highestPricePerSquareMeter,
  mostActiveArea,
  limitedData,
  general,
}

/// مستوى أهمية المؤشر.
///
/// يستخدم لاحقًا في الواجهة لتحديد طريقة عرض
/// المؤشر بدون ربط الـ Model بألوان أو Widgets.
enum MarketInsightLevel {
  info,
  positive,
  warning,
  negative,
}

/// يمثل ملاحظة أو استنتاجًا ناتجًا عن تحليل
/// بيانات السوق العقاري.
///
/// مثال:
/// العنوان: الأسعار في ارتفاع
/// الوصف: ارتفع متوسط الأسعار بنسبة 6.4%
///
/// لا يحتوي هذا النموذج على أي كود Flutter
/// حتى يبقى مستقلًا عن طبقة الواجهة.
class MarketInsight {
  /// نوع المؤشر.
  final MarketInsightType type;

  /// مستوى أهمية المؤشر.
  final MarketInsightLevel level;

  /// عنوان مختصر يظهر للمستخدم.
  final String title;

  /// وصف تفصيلي للمؤشر.
  final String description;

  /// قيمة رقمية مرتبطة بالمؤشر إن وجدت.
  ///
  /// أمثلة:
  /// نسبة التغير = 6.4
  /// متوسط السعر = 125000000
  final double? value;

  /// اسم المدينة المرتبطة بالمؤشر إن وجدت.
  final String? city;

  /// اسم المنطقة المرتبطة بالمؤشر إن وجدت.
  final String? areaName;

  /// عدد العقارات التي يستند إليها المؤشر إن وجد.
  final int? propertyCount;

  const MarketInsight({
    required this.type,
    required this.level,
    required this.title,
    required this.description,
    this.value,
    this.city,
    this.areaName,
    this.propertyCount,
  });

  /// هل يحتوي المؤشر على قيمة رقمية؟
  bool get hasValue => value != null;

  /// هل المؤشر مرتبط بمدينة؟
  bool get hasCity => city != null && city!.trim().isNotEmpty;

  /// هل المؤشر مرتبط بمنطقة؟
  bool get hasArea => areaName != null && areaName!.trim().isNotEmpty;

  /// هل يحتوي المؤشر على حجم عينة؟
  bool get hasPropertyCount => propertyCount != null && propertyCount! > 0;

  /// هل المؤشر إيجابي؟
  bool get isPositive => level == MarketInsightLevel.positive;

  /// هل المؤشر تحذيري؟
  bool get isWarning => level == MarketInsightLevel.warning;

  /// هل المؤشر سلبي؟
  bool get isNegative => level == MarketInsightLevel.negative;

  /// هل المؤشر معلوماتي؟
  bool get isInfo => level == MarketInsightLevel.info;

  /// إنشاء نسخة جديدة مع تغيير القيم المطلوبة فقط.
  MarketInsight copyWith({
    MarketInsightType? type,
    MarketInsightLevel? level,
    String? title,
    String? description,
    double? value,
    String? city,
    String? areaName,
    int? propertyCount,
    bool clearValue = false,
    bool clearCity = false,
    bool clearAreaName = false,
    bool clearPropertyCount = false,
  }) {
    return MarketInsight(
      type: type ?? this.type,
      level: level ?? this.level,
      title: title ?? this.title,
      description: description ?? this.description,
      value: clearValue ? null : (value ?? this.value),
      city: clearCity ? null : (city ?? this.city),
      areaName: clearAreaName ? null : (areaName ?? this.areaName),
      propertyCount:
          clearPropertyCount ? null : (propertyCount ?? this.propertyCount),
    );
  }

  /// مؤشر عام بدون بيانات إضافية.
  factory MarketInsight.general({
    required String title,
    required String description,
    MarketInsightLevel level = MarketInsightLevel.info,
  }) {
    return MarketInsight(
      type: MarketInsightType.general,
      level: level,
      title: title,
      description: description,
    );
  }

  /// مؤشر يستخدم عندما تكون البيانات محدودة.
  factory MarketInsight.limitedData({
    required String description,
    int? propertyCount,
  }) {
    return MarketInsight(
      type: MarketInsightType.limitedData,
      level: MarketInsightLevel.warning,
      title: 'بيانات محدودة',
      description: description,
      propertyCount: propertyCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is MarketInsight &&
        other.type == type &&
        other.level == level &&
        other.title == title &&
        other.description == description &&
        other.value == value &&
        other.city == city &&
        other.areaName == areaName &&
        other.propertyCount == propertyCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      level,
      title,
      description,
      value,
      city,
      areaName,
      propertyCount,
    );
  }

  @override
  String toString() {
    return 'MarketInsight('
        'type: $type, '
        'level: $level, '
        'title: $title, '
        'description: $description, '
        'value: $value, '
        'city: $city, '
        'areaName: $areaName, '
        'propertyCount: $propertyCount'
        ')';
  }
}
