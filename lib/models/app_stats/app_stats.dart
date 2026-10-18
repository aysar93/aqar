/// نموذج يمثل الإحصائيات العامة لمنصة "عقار".
///
/// هذا النموذج لا يتعامل مباشرة مع Firebase أو واجهة المستخدم.
/// مهمته فقط الاحتفاظ بالقيم التي يتم جلبها من [AppStatsService].
class AppStats {
  /// عدد العقارات التي نريد إظهارها للمستخدمين.
  final int propertiesCount;

  /// إجمالي عدد المستخدمين المسجلين.
  final int usersCount;

  const AppStats({
    required this.propertiesCount,
    required this.usersCount,
  });

  /// حالة فارغة تستخدم كقيمة ابتدائية عند الحاجة.
  static const AppStats empty = AppStats(
    propertiesCount: 0,
    usersCount: 0,
  );

  /// هل توجد أي بيانات إحصائية؟
  bool get hasData => propertiesCount > 0 || usersCount > 0;

  /// إنشاء نسخة مع تغيير قيمة أو أكثر.
  AppStats copyWith({
    int? propertiesCount,
    int? usersCount,
  }) {
    return AppStats(
      propertiesCount: propertiesCount ?? this.propertiesCount,
      usersCount: usersCount ?? this.usersCount,
    );
  }

  /// مفيد للمقارنات والتسجيل أثناء التطوير.
  @override
  String toString() {
    return 'AppStats('
        'propertiesCount: $propertiesCount, '
        'usersCount: $usersCount'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppStats &&
        other.propertiesCount == propertiesCount &&
        other.usersCount == usersCount;
  }

  @override
  int get hashCode => Object.hash(
        propertiesCount,
        usersCount,
      );
}
