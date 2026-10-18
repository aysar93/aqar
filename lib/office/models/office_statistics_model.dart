import 'package:cloud_firestore/cloud_firestore.dart';

/// إحصائيات المكتب.
///
/// هذا النموذج مخصص لتجميع الأرقام التي يحتاجها صاحب المكتب
/// ولوحة الإدارة، دون خلطها مع بيانات المكتب الأساسية.
class OfficeStatisticsModel {
  final String officeId;

  // ─────────────────────────────────────────────
  // العقارات
  // ─────────────────────────────────────────────

  final int totalProperties;
  final int activeProperties;
  final int pendingProperties;
  final int rejectedProperties;
  final int soldProperties;
  final int rentedProperties;

  // ─────────────────────────────────────────────
  // الظهور
  // ─────────────────────────────────────────────

  final int totalViews;
  final int totalFavorites;
  final int totalShares;

  // ─────────────────────────────────────────────
  // المتابعون والتقييمات
  // ─────────────────────────────────────────────

  final int followersCount;
  final int reviewsCount;
  final double averageRating;

  // ─────────────────────────────────────────────
  // التفاعل
  // ─────────────────────────────────────────────

  final int phoneClicks;
  final int whatsappClicks;
  final int locationClicks;
  final int contactClicks;

  // ─────────────────────────────────────────────
  // إحصائيات زمنية
  // ─────────────────────────────────────────────

  final int viewsToday;
  final int viewsThisWeek;
  final int viewsThisMonth;

  final int inquiriesToday;
  final int inquiriesThisWeek;
  final int inquiriesThisMonth;

  // ─────────────────────────────────────────────
  // آخر تحديث
  // ─────────────────────────────────────────────

  final DateTime? updatedAt;

  const OfficeStatisticsModel({
    required this.officeId,
    this.totalProperties = 0,
    this.activeProperties = 0,
    this.pendingProperties = 0,
    this.rejectedProperties = 0,
    this.soldProperties = 0,
    this.rentedProperties = 0,
    this.totalViews = 0,
    this.totalFavorites = 0,
    this.totalShares = 0,
    this.followersCount = 0,
    this.reviewsCount = 0,
    this.averageRating = 0,
    this.phoneClicks = 0,
    this.whatsappClicks = 0,
    this.locationClicks = 0,
    this.contactClicks = 0,
    this.viewsToday = 0,
    this.viewsThisWeek = 0,
    this.viewsThisMonth = 0,
    this.inquiriesToday = 0,
    this.inquiriesThisWeek = 0,
    this.inquiriesThisMonth = 0,
    this.updatedAt,
  });

  // ═════════════════════════════════════════════
  // Firestore → Model
  // ═════════════════════════════════════════════

  factory OfficeStatisticsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return OfficeStatisticsModel(
      officeId: data['officeId'] as String? ?? document.id,
      totalProperties: _intValue(data['totalProperties']),
      activeProperties: _intValue(data['activeProperties']),
      pendingProperties: _intValue(data['pendingProperties']),
      rejectedProperties: _intValue(data['rejectedProperties']),
      soldProperties: _intValue(data['soldProperties']),
      rentedProperties: _intValue(data['rentedProperties']),
      totalViews: _intValue(data['totalViews']),
      totalFavorites: _intValue(data['totalFavorites']),
      totalShares: _intValue(data['totalShares']),
      followersCount: _intValue(data['followersCount']),
      reviewsCount: _intValue(data['reviewsCount']),
      averageRating: _doubleValue(data['averageRating']),
      phoneClicks: _intValue(data['phoneClicks']),
      whatsappClicks: _intValue(data['whatsappClicks']),
      locationClicks: _intValue(data['locationClicks']),
      contactClicks: _intValue(data['contactClicks']),
      viewsToday: _intValue(data['viewsToday']),
      viewsThisWeek: _intValue(data['viewsThisWeek']),
      viewsThisMonth: _intValue(data['viewsThisMonth']),
      inquiriesToday: _intValue(data['inquiriesToday']),
      inquiriesThisWeek: _intValue(data['inquiriesThisWeek']),
      inquiriesThisMonth: _intValue(data['inquiriesThisMonth']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  // ═════════════════════════════════════════════
  // Model → Firestore
  // ═════════════════════════════════════════════

  Map<String, dynamic> toFirestore() {
    return {
      'officeId': officeId,
      'totalProperties': totalProperties,
      'activeProperties': activeProperties,
      'pendingProperties': pendingProperties,
      'rejectedProperties': rejectedProperties,
      'soldProperties': soldProperties,
      'rentedProperties': rentedProperties,
      'totalViews': totalViews,
      'totalFavorites': totalFavorites,
      'totalShares': totalShares,
      'followersCount': followersCount,
      'reviewsCount': reviewsCount,
      'averageRating': averageRating,
      'phoneClicks': phoneClicks,
      'whatsappClicks': whatsappClicks,
      'locationClicks': locationClicks,
      'contactClicks': contactClicks,
      'viewsToday': viewsToday,
      'viewsThisWeek': viewsThisWeek,
      'viewsThisMonth': viewsThisMonth,
      'inquiriesToday': inquiriesToday,
      'inquiriesThisWeek': inquiriesThisWeek,
      'inquiriesThisMonth': inquiriesThisMonth,
      'updatedAt': updatedAt,
    };
  }

  // ═════════════════════════════════════════════
  // إجمالي التفاعل
  // ═════════════════════════════════════════════

  int get totalInteractions {
    return totalFavorites +
        totalShares +
        phoneClicks +
        whatsappClicks +
        locationClicks +
        contactClicks;
  }

  // ═════════════════════════════════════════════
  // إجمالي الاستفسارات
  // ═════════════════════════════════════════════

  int get totalInquiries {
    return inquiriesToday + inquiriesThisWeek + inquiriesThisMonth;
  }

  // ═════════════════════════════════════════════
  // نسبة العقارات النشطة
  // ═════════════════════════════════════════════

  double get activePropertiesPercentage {
    if (totalProperties <= 0) {
      return 0;
    }

    return activeProperties / totalProperties;
  }

  // ═════════════════════════════════════════════
  // نسخة جديدة
  // ═════════════════════════════════════════════

  OfficeStatisticsModel copyWith({
    String? officeId,
    int? totalProperties,
    int? activeProperties,
    int? pendingProperties,
    int? rejectedProperties,
    int? soldProperties,
    int? rentedProperties,
    int? totalViews,
    int? totalFavorites,
    int? totalShares,
    int? followersCount,
    int? reviewsCount,
    double? averageRating,
    int? phoneClicks,
    int? whatsappClicks,
    int? locationClicks,
    int? contactClicks,
    int? viewsToday,
    int? viewsThisWeek,
    int? viewsThisMonth,
    int? inquiriesToday,
    int? inquiriesThisWeek,
    int? inquiriesThisMonth,
    DateTime? updatedAt,
  }) {
    return OfficeStatisticsModel(
      officeId: officeId ?? this.officeId,
      totalProperties: totalProperties ?? this.totalProperties,
      activeProperties: activeProperties ?? this.activeProperties,
      pendingProperties: pendingProperties ?? this.pendingProperties,
      rejectedProperties: rejectedProperties ?? this.rejectedProperties,
      soldProperties: soldProperties ?? this.soldProperties,
      rentedProperties: rentedProperties ?? this.rentedProperties,
      totalViews: totalViews ?? this.totalViews,
      totalFavorites: totalFavorites ?? this.totalFavorites,
      totalShares: totalShares ?? this.totalShares,
      followersCount: followersCount ?? this.followersCount,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      averageRating: averageRating ?? this.averageRating,
      phoneClicks: phoneClicks ?? this.phoneClicks,
      whatsappClicks: whatsappClicks ?? this.whatsappClicks,
      locationClicks: locationClicks ?? this.locationClicks,
      contactClicks: contactClicks ?? this.contactClicks,
      viewsToday: viewsToday ?? this.viewsToday,
      viewsThisWeek: viewsThisWeek ?? this.viewsThisWeek,
      viewsThisMonth: viewsThisMonth ?? this.viewsThisMonth,
      inquiriesToday: inquiriesToday ?? this.inquiriesToday,
      inquiriesThisWeek: inquiriesThisWeek ?? this.inquiriesThisWeek,
      inquiriesThisMonth: inquiriesThisMonth ?? this.inquiriesThisMonth,
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
