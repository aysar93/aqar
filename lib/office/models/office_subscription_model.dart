import 'package:cloud_firestore/cloud_firestore.dart';

/// بيانات العرض الإداري المجمّعة من سجل الاشتراك ومستند المكتب الحقيقي.
/// لا تُحفظ هذه البيانات داخل [office_subscriptions] ولا تغيّر بنيته.
class OfficeSubscriptionAdminItem {
  const OfficeSubscriptionAdminItem({
    required this.subscription,
    required this.officeName,
    required this.officeImageUrl,
    required this.officeExists,
  });

  final OfficeSubscriptionModel subscription;
  final String officeName;
  final String officeImageUrl;
  final bool officeExists;

  String get officeId => subscription.officeId;

  String get searchableText => <String>[
        officeName,
        officeId,
        subscription.id,
        subscription.ownerId,
        subscription.packageName,
        subscription.packageId,
        subscription.paymentReference,
      ].join(' ').toLowerCase();
}

/// نموذج اشتراك المكتب.
///
/// الاشتراك مرتبط بمكتب محدد وليس بحساب المستخدم الشخصي.
/// تاريخ الانتهاء هو المرجع الأساسي لمعرفة صلاحية الاشتراك.
class OfficeSubscriptionModel {
  final String id;
  final String officeId;
  final String ownerId;

  // ─────────────────────────────────────────────
  // الباقة
  // ─────────────────────────────────────────────

  final String packageId;
  final String packageName;

  /// مدة الاشتراك بالأيام.
  final int durationDays;

  // ─────────────────────────────────────────────
  // المدة والتواريخ
  // ─────────────────────────────────────────────

  final DateTime? startDate;
  final DateTime? endDate;

  // ─────────────────────────────────────────────
  // حالة الاشتراك
  // ─────────────────────────────────────────────

  final String status;

  // ─────────────────────────────────────────────
  // الدفع
  // ─────────────────────────────────────────────

  final double price;
  final String currency;
  final String paymentStatus;
  final String paymentMethod;
  final String paymentReference;

  // ─────────────────────────────────────────────
  // التجديد
  // ─────────────────────────────────────────────

  final bool autoRenew;
  final String? previousSubscriptionId;

  // ─────────────────────────────────────────────
  // المزايا والحدود
  // ─────────────────────────────────────────────

  final int maxProperties;
  final int maxFeaturedProperties;

  /// عدد محاولات تمييز العقارات المستهلكة من هذه الباقة.
  /// المحاولة تُستهلك عند التمييز وكذلك عند إلغاء التمييز.
  final int featuredPropertiesUsed;

  final bool canFeatureProperties;
  final bool canAppearInFeaturedOffices;
  final bool canUseAdvancedStatistics;

  // ─────────────────────────────────────────────
  // التواريخ الإدارية
  // ─────────────────────────────────────────────

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OfficeSubscriptionModel({
    required this.id,
    required this.officeId,
    required this.ownerId,
    required this.packageId,
    required this.packageName,
    required this.durationDays,
    this.startDate,
    this.endDate,
    this.status = 'pending',
    this.price = 0,
    this.currency = 'IQD',
    this.paymentStatus = 'pending',
    this.paymentMethod = '',
    this.paymentReference = '',
    this.autoRenew = false,
    this.previousSubscriptionId,
    this.maxProperties = 0,
    this.maxFeaturedProperties = 0,
    this.featuredPropertiesUsed = 0,
    this.canFeatureProperties = false,
    this.canAppearInFeaturedOffices = false,
    this.canUseAdvancedStatistics = false,
    this.createdAt,
    this.updatedAt,
  });

  // ═════════════════════════════════════════════
  // إنشاء اشتراك جديد وحساب تاريخ الانتهاء
  // ═════════════════════════════════════════════

  factory OfficeSubscriptionModel.create({
    required String id,
    required String officeId,
    required String ownerId,
    required String packageId,
    required String packageName,
    required int durationDays,
    required double price,
    String currency = 'IQD',
    String paymentStatus = 'pending',
    String paymentMethod = '',
    String paymentReference = '',
    bool autoRenew = false,
    String? previousSubscriptionId,
    int maxProperties = 0,
    int maxFeaturedProperties = 0,
    int featuredPropertiesUsed = 0,
    bool canFeatureProperties = false,
    bool canAppearInFeaturedOffices = false,
    bool canUseAdvancedStatistics = false,
    DateTime? startDate,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();

    // إذا لم يتم تحديد startDate فهذا يعني أن الطلب
    // لم يتم تفعيله بعد.
    final actualStartDate = startDate;

    final actualEndDate = actualStartDate?.add(
      Duration(days: durationDays),
    );

    return OfficeSubscriptionModel(
      id: id,
      officeId: officeId,
      ownerId: ownerId,
      packageId: packageId,
      packageName: packageName,
      durationDays: durationDays,
      startDate: actualStartDate,
      endDate: actualEndDate,
      status: actualStartDate == null ? 'pending' : 'active',
      price: price,
      currency: currency,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      autoRenew: autoRenew,
      previousSubscriptionId: previousSubscriptionId,
      maxProperties: maxProperties,
      maxFeaturedProperties: maxFeaturedProperties,
      featuredPropertiesUsed: featuredPropertiesUsed,
      canFeatureProperties: canFeatureProperties,
      canAppearInFeaturedOffices: canAppearInFeaturedOffices,
      canUseAdvancedStatistics: canUseAdvancedStatistics,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ═════════════════════════════════════════════
  // Firestore → Model
  // ═════════════════════════════════════════════

  factory OfficeSubscriptionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return OfficeSubscriptionModel(
      id: document.id,
      officeId: data['officeId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      packageId: data['packageId'] as String? ?? '',
      packageName: data['packageName'] as String? ?? '',
      durationDays: _intValue(data['durationDays']),
      startDate: _dateValue(data['startDate']),
      endDate: _dateValue(data['endDate']),
      status: data['status'] as String? ?? 'pending',
      price: _doubleValue(data['price']),
      currency: data['currency'] as String? ?? 'IQD',
      paymentStatus: data['paymentStatus'] as String? ?? 'pending',
      paymentMethod: data['paymentMethod'] as String? ?? '',
      paymentReference: data['paymentReference'] as String? ?? '',
      autoRenew: data['autoRenew'] as bool? ?? false,
      previousSubscriptionId: data['previousSubscriptionId'] as String?,
      maxProperties: _intValue(data['maxProperties']),
      maxFeaturedProperties: _intValue(data['maxFeaturedProperties']),
      featuredPropertiesUsed: _intValue(data['featuredPropertiesUsed']),
      canFeatureProperties: data['canFeatureProperties'] as bool? ?? false,
      canAppearInFeaturedOffices:
          data['canAppearInFeaturedOffices'] as bool? ?? false,
      canUseAdvancedStatistics:
          data['canUseAdvancedStatistics'] as bool? ?? false,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  // ═════════════════════════════════════════════
  // Model → Firestore
  // ═════════════════════════════════════════════

  Map<String, dynamic> toFirestore() {
    return {
      'officeId': officeId,
      'ownerId': ownerId,
      'packageId': packageId,
      'packageName': packageName,
      'durationDays': durationDays,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'price': price,
      'currency': currency,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'autoRenew': autoRenew,
      'previousSubscriptionId': previousSubscriptionId,
      'maxProperties': maxProperties,
      'maxFeaturedProperties': maxFeaturedProperties,
      'featuredPropertiesUsed': featuredPropertiesUsed,
      'canFeatureProperties': canFeatureProperties,
      'canAppearInFeaturedOffices': canAppearInFeaturedOffices,
      'canUseAdvancedStatistics': canUseAdvancedStatistics,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك فعال الآن؟
  // ═════════════════════════════════════════════

  bool get isActive {
    if (startDate == null || endDate == null) {
      return false;
    }

    final now = DateTime.now();

    return status == 'active' &&
        !now.isBefore(startDate!) &&
        now.isBefore(endDate!);
  }

  // ═════════════════════════════════════════════
  // هل انتهى؟
  // ═════════════════════════════════════════════

  bool get isExpired {
    if (endDate == null) {
      return false;
    }

    return !DateTime.now().isBefore(endDate!);
  }

  // ═════════════════════════════════════════════
  // هل لم يبدأ بعد؟
  // ═════════════════════════════════════════════

  bool get isPendingStart {
    if (startDate == null) {
      return false;
    }

    return DateTime.now().isBefore(startDate!);
  }

  // ═════════════════════════════════════════════
  // الأيام المتبقية
  // ═════════════════════════════════════════════

  int get remainingDays {
    if (endDate == null) {
      return 0;
    }

    final difference = endDate!.difference(DateTime.now());

    if (difference.isNegative) {
      return 0;
    }

    return difference.inDays;
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك قريب من الانتهاء؟
  // ═════════════════════════════════════════════

  bool get isExpiringSoon {
    if (!isActive) {
      return false;
    }

    return remainingDays <= 7;
  }

  // ═════════════════════════════════════════════
  // هل يستطيع إضافة عقارات؟
  // ═════════════════════════════════════════════

  bool canAddProperty(int currentPropertiesCount) {
    if (!isActive) {
      return false;
    }

    if (maxProperties <= 0) {
      return true;
    }

    return currentPropertiesCount < maxProperties;
  }

  // ═════════════════════════════════════════════
  // هل يستطيع تمييز عقار؟
  // ═════════════════════════════════════════════

  bool canFeatureProperty([
    int? currentFeaturedPropertiesCount,
  ]) {
    if (!isActive || !canFeatureProperties) {
      return false;
    }

    final used = currentFeaturedPropertiesCount ?? featuredPropertiesUsed;

    if (maxFeaturedProperties <= 0) {
      return true;
    }

    return used < maxFeaturedProperties;
  }

  /// عدد محاولات التمييز المتبقية.
  /// القيمة 0 في maxFeaturedProperties تعني غير محدود.
  int get remainingFeaturedAttempts {
    if (maxFeaturedProperties <= 0) {
      return -1;
    }

    final remaining = maxFeaturedProperties - featuredPropertiesUsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// يدمج محاولات التمييز المتبقية مع عدد محاولات باقة جديدة.
  /// القيمة 0 في أي من الحدّين تعني غير محدود.
  int mergedFeaturedLimit(int newPackageLimit) {
    if (newPackageLimit <= 0 || maxFeaturedProperties <= 0) {
      return 0;
    }

    return newPackageLimit + remainingFeaturedAttempts;
  }

  // ═════════════════════════════════════════════
  // تجديد الاشتراك
  //
  // إذا كان الاشتراك فعالًا:
  // نضيف المدة إلى تاريخ الانتهاء الحالي.
  //
  // إذا كان منتهيًا:
  // نبدأ من الآن.
  // ═════════════════════════════════════════════

  OfficeSubscriptionModel renew({
    required int additionalDays,
    DateTime? renewalDate,
  }) {
    final now = renewalDate ?? DateTime.now();

    final DateTime newStartDate;
    final DateTime baseDate;

    if (isActive && endDate != null) {
      newStartDate = startDate ?? now;
      baseDate = endDate!;
    } else {
      newStartDate = now;
      baseDate = now;
    }

    final newEndDate = baseDate.add(
      Duration(days: additionalDays),
    );

    return copyWith(
      startDate: newStartDate,
      endDate: newEndDate,
      durationDays: durationDays + additionalDays,
      status: 'active',
      paymentStatus: 'paid',
      updatedAt: now,
    );
  }

  // ═════════════════════════════════════════════
  // تحديث الحالة تلقائيًا حسب التاريخ
  // ═════════════════════════════════════════════

  String get calculatedStatus {
    if (startDate == null || endDate == null) {
      return status;
    }

    final now = DateTime.now();

    if (now.isBefore(startDate!)) {
      return 'pending';
    }

    if (!now.isBefore(endDate!)) {
      return 'expired';
    }

    return 'active';
  }

  // ═════════════════════════════════════════════
  // نسخة جديدة
  // ═════════════════════════════════════════════

  OfficeSubscriptionModel copyWith({
    String? id,
    String? officeId,
    String? ownerId,
    String? packageId,
    String? packageName,
    int? durationDays,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    double? price,
    String? currency,
    String? paymentStatus,
    String? paymentMethod,
    String? paymentReference,
    bool? autoRenew,
    String? previousSubscriptionId,
    int? maxProperties,
    int? maxFeaturedProperties,
    int? featuredPropertiesUsed,
    bool? canFeatureProperties,
    bool? canAppearInFeaturedOffices,
    bool? canUseAdvancedStatistics,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfficeSubscriptionModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      ownerId: ownerId ?? this.ownerId,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      durationDays: durationDays ?? this.durationDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      autoRenew: autoRenew ?? this.autoRenew,
      previousSubscriptionId:
          previousSubscriptionId ?? this.previousSubscriptionId,
      maxProperties: maxProperties ?? this.maxProperties,
      maxFeaturedProperties:
          maxFeaturedProperties ?? this.maxFeaturedProperties,
      featuredPropertiesUsed:
          featuredPropertiesUsed ?? this.featuredPropertiesUsed,
      canFeatureProperties: canFeatureProperties ?? this.canFeatureProperties,
      canAppearInFeaturedOffices:
          canAppearInFeaturedOffices ?? this.canAppearInFeaturedOffices,
      canUseAdvancedStatistics:
          canUseAdvancedStatistics ?? this.canUseAdvancedStatistics,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ═════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════

  static int _intValue(dynamic value) {
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

  static double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static DateTime? _dateValue(dynamic value) {
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
