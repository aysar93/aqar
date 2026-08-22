import 'package:flutter/material.dart';

/// صلاحيات صاحب المكتب داخل نظام المكاتب.
///
/// مهم:
/// هذا الملف يحدد الصلاحيات على مستوى الواجهة والمنطق المحلي فقط.
/// الحماية الحقيقية للبيانات سنطبقها لاحقًا في Firestore Security Rules
/// وطبقة الخدمات.
///
/// لا يوجد نظام موظفين في مشروعنا.
/// صاحب المكتب هو المستخدم الوحيد الذي يدير المكتب.
enum OfficePermission {
  viewOffice,
  editOffice,
  manageProperties,
  viewStatistics,
  manageReviews,
  manageFollowers,
  viewSubscription,
  manageSubscription,
}

/// مجموعة الصلاحيات المتاحة للمكتب.
class OfficePermissions {
  final bool viewOffice;
  final bool editOffice;
  final bool manageProperties;
  final bool viewStatistics;
  final bool manageReviews;
  final bool manageFollowers;
  final bool viewSubscription;
  final bool manageSubscription;

  const OfficePermissions({
    this.viewOffice = false,
    this.editOffice = false,
    this.manageProperties = false,
    this.viewStatistics = false,
    this.manageReviews = false,
    this.manageFollowers = false,
    this.viewSubscription = false,
    this.manageSubscription = false,
  });

  /// الصلاحيات الكاملة لصاحب المكتب.
  ///
  /// صاحب المكتب يستطيع إدارة ملف مكتبه وعقاراته
  /// ومتابعة الإحصائيات والمراجعات والاشتراك.
  const OfficePermissions.owner()
      : viewOffice = true,
        editOffice = true,
        manageProperties = true,
        viewStatistics = true,
        manageReviews = true,
        manageFollowers = true,
        viewSubscription = true,
        manageSubscription = true;

  /// لا توجد صلاحيات.
  const OfficePermissions.none()
      : viewOffice = false,
        editOffice = false,
        manageProperties = false,
        viewStatistics = false,
        manageReviews = false,
        manageFollowers = false,
        viewSubscription = false,
        manageSubscription = false;

  /// إنشاء الصلاحيات من Map.
  factory OfficePermissions.fromMap(
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return const OfficePermissions.none();
    }

    return OfficePermissions(
      viewOffice: data['viewOffice'] == true,
      editOffice: data['editOffice'] == true,
      manageProperties: data['manageProperties'] == true,
      viewStatistics: data['viewStatistics'] == true,
      manageReviews: data['manageReviews'] == true,
      manageFollowers: data['manageFollowers'] == true,
      viewSubscription: data['viewSubscription'] == true,
      manageSubscription: data['manageSubscription'] == true,
    );
  }

  /// تحويل الصلاحيات إلى Map.
  Map<String, dynamic> toMap() {
    return {
      'viewOffice': viewOffice,
      'editOffice': editOffice,
      'manageProperties': manageProperties,
      'viewStatistics': viewStatistics,
      'manageReviews': manageReviews,
      'manageFollowers': manageFollowers,
      'viewSubscription': viewSubscription,
      'manageSubscription': manageSubscription,
    };
  }

  /// هل يملك صلاحية محددة؟
  bool hasPermission(
    OfficePermission permission,
  ) {
    switch (permission) {
      case OfficePermission.viewOffice:
        return viewOffice;

      case OfficePermission.editOffice:
        return editOffice;

      case OfficePermission.manageProperties:
        return manageProperties;

      case OfficePermission.viewStatistics:
        return viewStatistics;

      case OfficePermission.manageReviews:
        return manageReviews;

      case OfficePermission.manageFollowers:
        return manageFollowers;

      case OfficePermission.viewSubscription:
        return viewSubscription;

      case OfficePermission.manageSubscription:
        return manageSubscription;
    }
  }

  /// هل يستطيع المستخدم إدارة المكتب؟
  bool get canManageOffice {
    return editOffice;
  }

  /// هل يستطيع إدارة العقارات التابعة للمكتب؟
  bool get canManageOfficeProperties {
    return manageProperties;
  }

  /// هل يستطيع مشاهدة الإحصائيات؟
  bool get canViewStatistics {
    return viewStatistics;
  }

  /// هل يستطيع إدارة المراجعات؟
  bool get canManageReviews {
    return manageReviews;
  }

  /// هل يستطيع مشاهدة المتابعين؟
  bool get canViewFollowers {
    return manageFollowers;
  }

  /// هل يستطيع مشاهدة الاشتراك؟
  bool get canViewSubscription {
    return viewSubscription;
  }

  /// هل يستطيع إدارة الاشتراك؟
  bool get canManageSubscription {
    return manageSubscription;
  }

  /// نسخ الصلاحيات مع تعديل قيمة أو أكثر.
  OfficePermissions copyWith({
    bool? viewOffice,
    bool? editOffice,
    bool? manageProperties,
    bool? viewStatistics,
    bool? manageReviews,
    bool? manageFollowers,
    bool? viewSubscription,
    bool? manageSubscription,
  }) {
    return OfficePermissions(
      viewOffice: viewOffice ?? this.viewOffice,
      editOffice: editOffice ?? this.editOffice,
      manageProperties: manageProperties ?? this.manageProperties,
      viewStatistics: viewStatistics ?? this.viewStatistics,
      manageReviews: manageReviews ?? this.manageReviews,
      manageFollowers: manageFollowers ?? this.manageFollowers,
      viewSubscription: viewSubscription ?? this.viewSubscription,
      manageSubscription: manageSubscription ?? this.manageSubscription,
    );
  }
}

/// أدوات مساعدة للصلاحيات.
class OfficePermissionUtils {
  const OfficePermissionUtils._();

  /// الاسم العربي للصلاحية.
  static String label(
    OfficePermission permission,
  ) {
    switch (permission) {
      case OfficePermission.viewOffice:
        return 'عرض المكتب';

      case OfficePermission.editOffice:
        return 'تعديل بيانات المكتب';

      case OfficePermission.manageProperties:
        return 'إدارة عقارات المكتب';

      case OfficePermission.viewStatistics:
        return 'عرض الإحصائيات';

      case OfficePermission.manageReviews:
        return 'إدارة المراجعات';

      case OfficePermission.manageFollowers:
        return 'عرض المتابعين';

      case OfficePermission.viewSubscription:
        return 'عرض الاشتراك';

      case OfficePermission.manageSubscription:
        return 'إدارة الاشتراك';
    }
  }

  /// وصف الصلاحية.
  static String description(
    OfficePermission permission,
  ) {
    switch (permission) {
      case OfficePermission.viewOffice:
        return 'عرض صفحة المكتب ومعلوماته.';

      case OfficePermission.editOffice:
        return 'تعديل بيانات المكتب وصوره ومعلومات التواصل.';

      case OfficePermission.manageProperties:
        return 'إدارة العقارات التابعة للمكتب.';

      case OfficePermission.viewStatistics:
        return 'مشاهدة إحصائيات المكتب والعقارات.';

      case OfficePermission.manageReviews:
        return 'متابعة وإدارة مراجعات المكتب.';

      case OfficePermission.manageFollowers:
        return 'مشاهدة عدد المتابعين ومعلومات المتابعة.';

      case OfficePermission.viewSubscription:
        return 'مشاهدة حالة الاشتراك وتاريخ انتهائه.';

      case OfficePermission.manageSubscription:
        return 'إدارة وتجديد اشتراك المكتب حسب النظام المتاح.';
    }
  }

  /// أيقونة الصلاحية.
  static IconData icon(
    OfficePermission permission,
  ) {
    switch (permission) {
      case OfficePermission.viewOffice:
        return Icons.business_outlined;

      case OfficePermission.editOffice:
        return Icons.business_outlined;

      case OfficePermission.manageProperties:
        return Icons.home_work_outlined;

      case OfficePermission.viewStatistics:
        return Icons.bar_chart_rounded;

      case OfficePermission.manageReviews:
        return Icons.rate_review_outlined;

      case OfficePermission.manageFollowers:
        return Icons.people_outline_rounded;

      case OfficePermission.viewSubscription:
        return Icons.card_membership_outlined;

      case OfficePermission.manageSubscription:
        return Icons.autorenew_rounded;
    }
  }

  /// هل الصلاحية مرتبطة بإدارة المكتب مباشرة؟
  static bool isOfficeManagementPermission(
    OfficePermission permission,
  ) {
    return permission == OfficePermission.editOffice ||
        permission == OfficePermission.manageProperties ||
        permission == OfficePermission.manageReviews;
  }

  /// جميع الصلاحيات.
  static const List<OfficePermission> all = [
    OfficePermission.viewOffice,
    OfficePermission.editOffice,
    OfficePermission.manageProperties,
    OfficePermission.viewStatistics,
    OfficePermission.manageReviews,
    OfficePermission.manageFollowers,
    OfficePermission.viewSubscription,
    OfficePermission.manageSubscription,
  ];
}
