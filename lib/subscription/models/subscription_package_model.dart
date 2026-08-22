import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج باقة اشتراك المكاتب.
///
/// الباقة يتم التحكم بها من لوحة الإدارة لاحقًا.
/// صاحب المكتب يختار الباقة المتاحة له، بينما الإدارة
/// هي التي تحدد السعر والمدة والمزايا وحالة الباقة.
class SubscriptionPackageModel {
  final String id;

  /// اسم الباقة.
  final String name;

  /// وصف مختصر للباقة.
  final String description;

  /// السعر.
  final double price;

  /// العملة.
  final String currency;

  /// مدة الاشتراك بالأيام.
  final int durationDays;

  /// هل الباقة متاحة للاشتراك؟
  final bool isActive;

  /// هل الباقة مميزة في شاشة الباقات؟
  final bool isFeatured;

  /// ترتيب ظهور الباقة.
  final int sortOrder;

  /// عدد العقارات المسموح بها.
  ///
  /// null = غير محدود.
  final int? maxProperties;

  /// عدد العقارات المميزة المسموح بها.
  ///
  /// null = غير محدود.
  final int? maxFeaturedProperties;

  /// عدد الصور المسموح بها لكل عقار.
  ///
  /// null = غير محدود.
  final int? maxImagesPerProperty;

  /// المزايا النصية التي تظهر للمستخدم.
  final List<String> features;

  /// هل تسمح الباقة بإحصائيات المكتب؟
  final bool statisticsEnabled;

  /// هل تسمح الباقة بظهور المكتب في قسم المكاتب؟
  final bool officeProfileEnabled;

  /// هل تسمح الباقة بتثبيت عقارات مميزة؟
  final bool featuredPropertiesEnabled;

  /// هل تسمح الباقة بظهور المكتب في النتائج المميزة؟
  final bool featuredOfficeEnabled;

  /// هل تسمح الباقة بالشارة الموثقة؟
  ///
  /// هذه ليست موافقة تلقائية على التوثيق.
  /// التوثيق الفعلي يبقى خاضعًا لنظام الإدارة.
  final bool verifiedBadgeEnabled;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubscriptionPackageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.isActive,
    required this.isFeatured,
    required this.sortOrder,
    required this.maxProperties,
    required this.maxFeaturedProperties,
    required this.maxImagesPerProperty,
    required this.features,
    required this.statisticsEnabled,
    required this.officeProfileEnabled,
    required this.featuredPropertiesEnabled,
    required this.featuredOfficeEnabled,
    required this.verifiedBadgeEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  // ═════════════════════════════════════════════
  // إنشاء من Firestore
  // ═════════════════════════════════════════════

  factory SubscriptionPackageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return SubscriptionPackageModel(
      id: doc.id,
      name: _stringValue(data['name']),
      description: _stringValue(
        data['description'],
      ),
      price: _doubleValue(data['price']),
      currency: _stringValue(
        data['currency'],
        fallback: 'IQD',
      ),
      durationDays: _intValue(
        data['durationDays'],
      ),
      isActive: data['isActive'] != false,
      isFeatured: data['isFeatured'] == true,
      sortOrder: _intValue(
        data['sortOrder'],
      ),
      maxProperties: _nullableInt(
        data['maxProperties'],
      ),
      maxFeaturedProperties: _nullableInt(
        data['maxFeaturedProperties'],
      ),
      maxImagesPerProperty: _nullableInt(
        data['maxImagesPerProperty'],
      ),
      features: _stringList(
        data['features'],
      ),
      statisticsEnabled: data['statisticsEnabled'] != false,
      officeProfileEnabled: data['officeProfileEnabled'] != false,
      featuredPropertiesEnabled: data['featuredPropertiesEnabled'] == true,
      featuredOfficeEnabled: data['featuredOfficeEnabled'] == true,
      verifiedBadgeEnabled: data['verifiedBadgeEnabled'] == true,
      createdAt: _dateValue(
        data['createdAt'],
      ),
      updatedAt: _dateValue(
        data['updatedAt'],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // إنشاء من Map
  // ═════════════════════════════════════════════

  factory SubscriptionPackageModel.fromMap(
    Map<String, dynamic> data, {
    String? id,
  }) {
    return SubscriptionPackageModel(
      id: id ?? _stringValue(data['id']),
      name: _stringValue(data['name']),
      description: _stringValue(
        data['description'],
      ),
      price: _doubleValue(data['price']),
      currency: _stringValue(
        data['currency'],
        fallback: 'IQD',
      ),
      durationDays: _intValue(
        data['durationDays'],
      ),
      isActive: data['isActive'] != false,
      isFeatured: data['isFeatured'] == true,
      sortOrder: _intValue(
        data['sortOrder'],
      ),
      maxProperties: _nullableInt(
        data['maxProperties'],
      ),
      maxFeaturedProperties: _nullableInt(
        data['maxFeaturedProperties'],
      ),
      maxImagesPerProperty: _nullableInt(
        data['maxImagesPerProperty'],
      ),
      features: _stringList(
        data['features'],
      ),
      statisticsEnabled: data['statisticsEnabled'] != false,
      officeProfileEnabled: data['officeProfileEnabled'] != false,
      featuredPropertiesEnabled: data['featuredPropertiesEnabled'] == true,
      featuredOfficeEnabled: data['featuredOfficeEnabled'] == true,
      verifiedBadgeEnabled: data['verifiedBadgeEnabled'] == true,
      createdAt: _dateValue(
        data['createdAt'],
      ),
      updatedAt: _dateValue(
        data['updatedAt'],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // تحويل إلى Map
  // ═════════════════════════════════════════════

  Map<String, dynamic> toMap({
    bool useServerTimestamp = false,
  }) {
    return {
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'durationDays': durationDays,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'sortOrder': sortOrder,
      'maxProperties': maxProperties,
      'maxFeaturedProperties': maxFeaturedProperties,
      'maxImagesPerProperty': maxImagesPerProperty,
      'features': features,
      'statisticsEnabled': statisticsEnabled,
      'officeProfileEnabled': officeProfileEnabled,
      'featuredPropertiesEnabled': featuredPropertiesEnabled,
      'featuredOfficeEnabled': featuredOfficeEnabled,
      'verifiedBadgeEnabled': verifiedBadgeEnabled,
      'createdAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : createdAt == null
              ? null
              : Timestamp.fromDate(createdAt!),
      'updatedAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : updatedAt == null
              ? null
              : Timestamp.fromDate(updatedAt!),
    };
  }

  // ═════════════════════════════════════════════
  // نسخ مع التعديل
  // ═════════════════════════════════════════════

  SubscriptionPackageModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? currency,
    int? durationDays,
    bool? isActive,
    bool? isFeatured,
    int? sortOrder,
    int? maxProperties,
    int? maxFeaturedProperties,
    int? maxImagesPerProperty,
    List<String>? features,
    bool? statisticsEnabled,
    bool? officeProfileEnabled,
    bool? featuredPropertiesEnabled,
    bool? featuredOfficeEnabled,
    bool? verifiedBadgeEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPackageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      durationDays: durationDays ?? this.durationDays,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      sortOrder: sortOrder ?? this.sortOrder,
      maxProperties: maxProperties ?? this.maxProperties,
      maxFeaturedProperties:
          maxFeaturedProperties ?? this.maxFeaturedProperties,
      maxImagesPerProperty: maxImagesPerProperty ?? this.maxImagesPerProperty,
      features: features ?? this.features,
      statisticsEnabled: statisticsEnabled ?? this.statisticsEnabled,
      officeProfileEnabled: officeProfileEnabled ?? this.officeProfileEnabled,
      featuredPropertiesEnabled:
          featuredPropertiesEnabled ?? this.featuredPropertiesEnabled,
      featuredOfficeEnabled:
          featuredOfficeEnabled ?? this.featuredOfficeEnabled,
      verifiedBadgeEnabled: verifiedBadgeEnabled ?? this.verifiedBadgeEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ═════════════════════════════════════════════
  // التحقق من صلاحية الباقة
  // ═════════════════════════════════════════════

  bool get isValid {
    return isActive && durationDays > 0 && price >= 0;
  }

  /// هل تسمح الباقة بإضافة عقار جديد؟
  bool canAddProperty(
    int currentPropertiesCount,
  ) {
    if (!isActive) {
      return false;
    }

    if (maxProperties == null) {
      return true;
    }

    return currentPropertiesCount < maxProperties!;
  }

  /// هل تسمح الباقة بإضافة عقار مميز؟
  bool canAddFeaturedProperty(
    int currentFeaturedCount,
  ) {
    if (!isActive || !featuredPropertiesEnabled) {
      return false;
    }

    if (maxFeaturedProperties == null) {
      return true;
    }

    return currentFeaturedCount < maxFeaturedProperties!;
  }

  /// هل يسمح بعدد صور معين؟
  bool canUseImages(
    int imageCount,
  ) {
    if (imageCount < 0) {
      return false;
    }

    if (maxImagesPerProperty == null) {
      return true;
    }

    return imageCount <= maxImagesPerProperty!;
  }

  // ═════════════════════════════════════════════
  // أدوات التحويل
  // ═════════════════════════════════════════════

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  static double _doubleValue(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static int _intValue(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static int? _nullableInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static List<String> _stringList(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(
          (item) => item.toString().trim(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toList();
  }

  static DateTime? _dateValue(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
