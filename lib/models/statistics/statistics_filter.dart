/// الفترات الزمنية المتاحة لتحليل سوق العقارات.
enum StatisticsPeriod {
  last7Days,
  last30Days,
  last90Days,
  last6Months,
  lastYear,
  allTime,
}

/// فلتر موحد يستخدمه نظام إحصائيات العقارات.
///
/// القيم null تعني أن الفلتر غير محدد، مثل:
/// city == null => جميع المدن
/// propertyType == null => جميع أنواع العقارات
class StatisticsFilter {
  final String? adType;
  final String? propertyType;
  final String? city;
  final String? areaName;
  final StatisticsPeriod period;

  const StatisticsFilter({
    this.adType,
    this.propertyType,
    this.city,
    this.areaName,
    this.period = StatisticsPeriod.last30Days,
  });

  /// الفلتر الافتراضي عند فتح شاشة الإحصائيات.
  static const StatisticsFilter initial = StatisticsFilter();

  /// إنشاء نسخة جديدة مع تغيير بعض القيم فقط.
  StatisticsFilter copyWith({
    String? adType,
    String? propertyType,
    String? city,
    String? areaName,
    StatisticsPeriod? period,
    bool clearAdType = false,
    bool clearPropertyType = false,
    bool clearCity = false,
    bool clearAreaName = false,
  }) {
    return StatisticsFilter(
      adType: clearAdType ? null : (adType ?? this.adType),
      propertyType:
          clearPropertyType ? null : (propertyType ?? this.propertyType),
      city: clearCity ? null : (city ?? this.city),
      areaName: clearAreaName ? null : (areaName ?? this.areaName),
      period: period ?? this.period,
    );
  }

  /// إزالة جميع الفلاتر وإرجاع الحالة الافتراضية.
  StatisticsFilter reset() {
    return const StatisticsFilter();
  }

  /// هل يوجد فلتر إعلان محدد؟
  bool get hasAdType => adType != null && adType!.trim().isNotEmpty;

  /// هل يوجد نوع عقار محدد؟
  bool get hasPropertyType =>
      propertyType != null && propertyType!.trim().isNotEmpty;

  /// هل توجد مدينة محددة؟
  bool get hasCity => city != null && city!.trim().isNotEmpty;

  /// هل توجد منطقة محددة؟
  bool get hasArea => areaName != null && areaName!.trim().isNotEmpty;

  /// عدد الفلاتر الفعالة.
  ///
  /// الفترة الزمنية محسوبة دائمًا كفلتر فعال ما لم تكن "كل الوقت".
  int get activeFiltersCount {
    var count = 0;

    if (hasAdType) {
      count++;
    }

    if (hasPropertyType) {
      count++;
    }

    if (hasCity) {
      count++;
    }

    if (hasArea) {
      count++;
    }

    if (period != StatisticsPeriod.allTime) {
      count++;
    }

    return count;
  }

  /// بداية الفترة الحالية.
  ///
  /// تعيد null عند اختيار "كل الوقت".
  DateTime? startDate([DateTime? now]) {
    final current = now ?? DateTime.now();

    switch (period) {
      case StatisticsPeriod.last7Days:
        return current.subtract(
          const Duration(days: 7),
        );

      case StatisticsPeriod.last30Days:
        return current.subtract(
          const Duration(days: 30),
        );

      case StatisticsPeriod.last90Days:
        return current.subtract(
          const Duration(days: 90),
        );

      case StatisticsPeriod.last6Months:
        return DateTime(
          current.year,
          current.month - 6,
          current.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );

      case StatisticsPeriod.lastYear:
        return DateTime(
          current.year - 1,
          current.month,
          current.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );

      case StatisticsPeriod.allTime:
        return null;
    }
  }

  /// بداية الفترة السابقة التي سنستخدمها لحساب نسبة التغير.
  ///
  /// مثال:
  /// آخر 30 يومًا:
  /// الفترة الحالية = من اليوم إلى 30 يومًا سابقًا.
  /// الفترة السابقة = الـ30 يومًا التي تسبقها.
  DateTime? previousPeriodStart([DateTime? now]) {
    final current = now ?? DateTime.now();
    final currentStart = startDate(current);

    if (currentStart == null) {
      return null;
    }

    switch (period) {
      case StatisticsPeriod.last7Days:
        return currentStart.subtract(
          const Duration(days: 7),
        );

      case StatisticsPeriod.last30Days:
        return currentStart.subtract(
          const Duration(days: 30),
        );

      case StatisticsPeriod.last90Days:
        return currentStart.subtract(
          const Duration(days: 90),
        );

      case StatisticsPeriod.last6Months:
        return DateTime(
          currentStart.year,
          currentStart.month - 6,
          currentStart.day,
          currentStart.hour,
          currentStart.minute,
          currentStart.second,
          currentStart.millisecond,
          currentStart.microsecond,
        );

      case StatisticsPeriod.lastYear:
        return DateTime(
          currentStart.year - 1,
          currentStart.month,
          currentStart.day,
          currentStart.hour,
          currentStart.minute,
          currentStart.second,
          currentStart.millisecond,
          currentStart.microsecond,
        );

      case StatisticsPeriod.allTime:
        return null;
    }
  }

  /// نهاية الفترة السابقة.
  ///
  /// وهي نفس بداية الفترة الحالية.
  DateTime? previousPeriodEnd([DateTime? now]) {
    return startDate(now);
  }

  /// الاسم العربي للفترة.
  String get periodLabel {
    switch (period) {
      case StatisticsPeriod.last7Days:
        return 'آخر 7 أيام';

      case StatisticsPeriod.last30Days:
        return 'آخر 30 يوم';

      case StatisticsPeriod.last90Days:
        return 'آخر 90 يوم';

      case StatisticsPeriod.last6Months:
        return 'آخر 6 أشهر';

      case StatisticsPeriod.lastYear:
        return 'آخر سنة';

      case StatisticsPeriod.allTime:
        return 'كل الوقت';
    }
  }

  /// وصف مختصر للفلاتر الحالية.
  String get summary {
    final values = <String>[];

    if (hasAdType) {
      values.add(adType!);
    }

    if (hasPropertyType) {
      values.add(propertyType!);
    }

    if (hasCity) {
      values.add(city!);
    }

    if (hasArea) {
      values.add(areaName!);
    }

    values.add(periodLabel);

    return values.join(' • ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is StatisticsFilter &&
        other.adType == adType &&
        other.propertyType == propertyType &&
        other.city == city &&
        other.areaName == areaName &&
        other.period == period;
  }

  @override
  int get hashCode {
    return Object.hash(
      adType,
      propertyType,
      city,
      areaName,
      period,
    );
  }

  @override
  String toString() {
    return 'StatisticsFilter('
        'adType: $adType, '
        'propertyType: $propertyType, '
        'city: $city, '
        'areaName: $areaName, '
        'period: $period'
        ')';
  }
}
