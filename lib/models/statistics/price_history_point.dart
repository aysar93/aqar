/// نقطة زمنية واحدة ضمن سجل حركة أسعار العقارات.
///
/// تستخدم لاحقًا في الرسم البياني لعرض تغير الأسعار
/// خلال الأيام أو الأشهر حسب الفترة المختارة.
class PriceHistoryPoint {
  /// بداية الفترة التي تمثلها هذه النقطة.
  final DateTime date;

  /// متوسط أسعار العقارات خلال هذه الفترة.
  final double averagePrice;

  /// وسيط أسعار العقارات خلال هذه الفترة.
  final double medianPrice;

  /// متوسط سعر المتر المربع.
  ///
  /// يكون صفرًا إذا لم تتوفر عقارات بمساحة صالحة للحساب.
  final double averagePricePerSquareMeter;

  /// عدد العقارات التي دخلت في حساب هذه النقطة.
  final int propertyCount;

  const PriceHistoryPoint({
    required this.date,
    required this.averagePrice,
    required this.medianPrice,
    required this.averagePricePerSquareMeter,
    required this.propertyCount,
  });

  /// هل تحتوي النقطة على بيانات فعلية؟
  bool get hasData => propertyCount > 0;

  /// هل يوجد سعر متر صالح؟
  bool get hasPricePerSquareMeter => averagePricePerSquareMeter > 0;

  /// إنشاء نسخة جديدة مع تعديل القيم المطلوبة فقط.
  PriceHistoryPoint copyWith({
    DateTime? date,
    double? averagePrice,
    double? medianPrice,
    double? averagePricePerSquareMeter,
    int? propertyCount,
  }) {
    return PriceHistoryPoint(
      date: date ?? this.date,
      averagePrice: averagePrice ?? this.averagePrice,
      medianPrice: medianPrice ?? this.medianPrice,
      averagePricePerSquareMeter:
          averagePricePerSquareMeter ?? this.averagePricePerSquareMeter,
      propertyCount: propertyCount ?? this.propertyCount,
    );
  }

  /// نقطة فارغة يمكن استخدامها عند الحاجة
  /// إلى تمثيل فترة لا تحتوي عقارات.
  factory PriceHistoryPoint.empty({
    required DateTime date,
  }) {
    return PriceHistoryPoint(
      date: date,
      averagePrice: 0,
      medianPrice: 0,
      averagePricePerSquareMeter: 0,
      propertyCount: 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PriceHistoryPoint &&
        other.date == date &&
        other.averagePrice == averagePrice &&
        other.medianPrice == medianPrice &&
        other.averagePricePerSquareMeter == averagePricePerSquareMeter &&
        other.propertyCount == propertyCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      date,
      averagePrice,
      medianPrice,
      averagePricePerSquareMeter,
      propertyCount,
    );
  }

  @override
  String toString() {
    return 'PriceHistoryPoint('
        'date: $date, '
        'averagePrice: $averagePrice, '
        'medianPrice: $medianPrice, '
        'averagePricePerSquareMeter: '
        '$averagePricePerSquareMeter, '
        'propertyCount: $propertyCount'
        ')';
  }
}
