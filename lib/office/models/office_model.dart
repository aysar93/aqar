import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج المكتب العقاري في تطبيق عقار.
///
/// هذا النموذج مستقل عن نموذج المستخدم.
/// صاحب المكتب هو مستخدم عادي مرتبط بالمكتب عن طريق ownerId.
class OfficeModel {
  final String id;
  final String ownerId;

  // ─────────────────────────────────────────────
  // المعلومات الأساسية
  // ─────────────────────────────────────────────

  final String name;
  final String description;
  final String logoUrl;
  final String coverImageUrl;
  final List<String> galleryImages;

  // ─────────────────────────────────────────────
  // معلومات التواصل
  // ─────────────────────────────────────────────

  final String phone;
  final String whatsapp;
  final String email;
  final String website;

  // ─────────────────────────────────────────────
  // روابط التواصل الاجتماعي
  // ─────────────────────────────────────────────

  final String facebook;
  final String instagram;
  final String telegram;
  final String tiktok;
  final String youtube;

  // ─────────────────────────────────────────────
  // الموقع
  // ─────────────────────────────────────────────

  final String city;
  final String district;
  final String areaName;
  final String address;
  final double latitude;
  final double longitude;

  // ─────────────────────────────────────────────
  // معلومات المكتب
  // ─────────────────────────────────────────────

  final List<String> services;
  final Map<String, String> workingHours;
  final int? establishedYear;
  final String licenseNumber;

  // ─────────────────────────────────────────────
  // التوثيق
  // ─────────────────────────────────────────────

  final bool isVerified;
  final String verificationStatus;
  final String verificationNote;
  final String licenseImageUrl;

  // ─────────────────────────────────────────────
  // حالة المكتب
  // ─────────────────────────────────────────────

  final String status;

  // ─────────────────────────────────────────────
  // الظهور والمميزات
  // ─────────────────────────────────────────────

  final bool isFeatured;
  final DateTime? featuredUntil;

  // ─────────────────────────────────────────────
  // الإحصائيات
  // ─────────────────────────────────────────────

  final int propertiesCount;
  final int followersCount;
  final int viewsCount;
  final int reviewsCount;

  // ─────────────────────────────────────────────
  // التقييم
  // ─────────────────────────────────────────────

  final double rating;

  // ─────────────────────────────────────────────
  // الاشتراك
  // ─────────────────────────────────────────────

  final String subscriptionId;
  final String subscriptionStatus;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  // ─────────────────────────────────────────────
// حدود ومزايا الاشتراك
// ─────────────────────────────────────────────

  final int maxProperties;
  final int maxFeaturedProperties;
  final bool canFeatureProperties;
  final bool canAppearInFeaturedOffices;
  final bool canUseAdvancedStatistics;

  // ─────────────────────────────────────────────
  // التواريخ
  // ─────────────────────────────────────────────

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OfficeModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.logoUrl = '',
    this.coverImageUrl = '',
    this.galleryImages = const [],
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.website = '',
    this.facebook = '',
    this.instagram = '',
    this.telegram = '',
    this.tiktok = '',
    this.youtube = '',
    this.city = '',
    this.district = '',
    this.areaName = '',
    this.address = '',
    this.latitude = 0,
    this.longitude = 0,
    this.services = const [],
    this.workingHours = const {},
    this.establishedYear,
    this.licenseNumber = '',
    this.isVerified = false,
    this.verificationStatus = 'not_requested',
    this.verificationNote = '',
    this.licenseImageUrl = '',
    this.status = 'pending',
    this.isFeatured = false,
    this.featuredUntil,
    this.propertiesCount = 0,
    this.followersCount = 0,
    this.viewsCount = 0,
    this.reviewsCount = 0,
    this.rating = 0,
    this.subscriptionId = '',
    this.subscriptionStatus = 'none',
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.maxProperties = 0,
    this.maxFeaturedProperties = 0,
    this.canFeatureProperties = false,
    this.canAppearInFeaturedOffices = false,
    this.canUseAdvancedStatistics = false,
    this.createdAt,
    this.updatedAt,
  });

  // ═════════════════════════════════════════════
  // Firestore → Model
  // ═════════════════════════════════════════════

  factory OfficeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return OfficeModel(
      id: document.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      logoUrl: data['logoUrl'] as String? ?? '',
      coverImageUrl: data['coverImageUrl'] as String? ?? '',
      galleryImages: _stringList(data['galleryImages']),
      phone: data['phone'] as String? ?? '',
      whatsapp: data['whatsapp'] as String? ?? '',
      email: data['email'] as String? ?? '',
      website: data['website'] as String? ?? '',
      facebook: data['facebook'] as String? ?? '',
      instagram: data['instagram'] as String? ?? '',
      telegram: data['telegram'] as String? ?? '',
      tiktok: data['tiktok'] as String? ?? '',
      youtube: data['youtube'] as String? ?? '',
      city: data['city'] as String? ?? '',
      district: data['district'] as String? ?? '',
      areaName: data['areaName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: _doubleValue(data['latitude']),
      longitude: _doubleValue(data['longitude']),
      services: _stringList(data['services']),
      workingHours: _stringMap(data['workingHours']),
      establishedYear: _intValue(data['establishedYear']),
      licenseNumber: data['licenseNumber'] as String? ?? '',
      isVerified: data['isVerified'] as bool? ?? false,
      verificationStatus:
          data['verificationStatus'] as String? ?? 'not_requested',
      verificationNote: data['verificationNote'] as String? ?? '',
      licenseImageUrl: data['licenseImageUrl'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      isFeatured: data['isFeatured'] as bool? ?? false,
      featuredUntil: _dateValue(data['featuredUntil']),
      propertiesCount: _intValue(data['propertiesCount']) ?? 0,
      followersCount: _intValue(data['followersCount']) ?? 0,
      viewsCount: _intValue(data['viewsCount']) ?? 0,
      reviewsCount: _intValue(data['reviewsCount']) ?? 0,
      rating: _doubleValue(data['rating']),
      subscriptionId: data['subscriptionId'] as String? ?? '',
      subscriptionStatus: data['subscriptionStatus'] as String? ?? 'none',
      subscriptionStartDate: _dateValue(data['subscriptionStartDate']),
      subscriptionEndDate: _dateValue(data['subscriptionEndDate']),
      maxProperties: _intValue(data['maxProperties']) ?? 0,
      maxFeaturedProperties: _intValue(data['maxFeaturedProperties']) ?? 0,
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
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'coverImageUrl': coverImageUrl,
      'galleryImages': galleryImages,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'website': website,
      'facebook': facebook,
      'instagram': instagram,
      'telegram': telegram,
      'tiktok': tiktok,
      'youtube': youtube,
      'city': city,
      'district': district,
      'areaName': areaName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'services': services,
      'workingHours': workingHours,
      'establishedYear': establishedYear,
      'licenseNumber': licenseNumber,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'verificationNote': verificationNote,
      'licenseImageUrl': licenseImageUrl,
      'status': status,
      'isFeatured': isFeatured,
      'featuredUntil': featuredUntil,
      'propertiesCount': propertiesCount,
      'followersCount': followersCount,
      'viewsCount': viewsCount,
      'reviewsCount': reviewsCount,
      'rating': rating,
      'subscriptionId': subscriptionId,
      'subscriptionStatus': subscriptionStatus,
      'subscriptionStartDate': subscriptionStartDate,
      'subscriptionEndDate': subscriptionEndDate,
      'maxProperties': maxProperties,
      'maxFeaturedProperties': maxFeaturedProperties,
      'canFeatureProperties': canFeatureProperties,
      'canAppearInFeaturedOffices': canAppearInFeaturedOffices,
      'canUseAdvancedStatistics': canUseAdvancedStatistics,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  factory OfficeModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return OfficeModel(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      logoUrl: data['logoUrl'] as String? ?? '',
      coverImageUrl: data['coverImageUrl'] as String? ?? '',
      galleryImages: _stringList(data['galleryImages']),
      phone: data['phone'] as String? ?? '',
      whatsapp: data['whatsapp'] as String? ?? '',
      email: data['email'] as String? ?? '',
      website: data['website'] as String? ?? '',
      facebook: data['facebook'] as String? ?? '',
      instagram: data['instagram'] as String? ?? '',
      telegram: data['telegram'] as String? ?? '',
      tiktok: data['tiktok'] as String? ?? '',
      youtube: data['youtube'] as String? ?? '',
      city: data['city'] as String? ?? '',
      district: data['district'] as String? ?? '',
      areaName: data['areaName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: _doubleValue(data['latitude']),
      longitude: _doubleValue(data['longitude']),
      services: _stringList(data['services']),
      workingHours: _stringMap(data['workingHours']),
      establishedYear: _intValue(data['establishedYear']),
      licenseNumber: data['licenseNumber'] as String? ?? '',
      isVerified: data['isVerified'] as bool? ?? false,
      verificationStatus:
          data['verificationStatus'] as String? ?? 'not_requested',
      verificationNote: data['verificationNote'] as String? ?? '',
      licenseImageUrl: data['licenseImageUrl'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      isFeatured: data['isFeatured'] as bool? ?? false,
      featuredUntil: _dateValue(data['featuredUntil']),
      propertiesCount: _intValue(data['propertiesCount']) ?? 0,
      followersCount: _intValue(data['followersCount']) ?? 0,
      viewsCount: _intValue(data['viewsCount']) ?? 0,
      reviewsCount: _intValue(data['reviewsCount']) ?? 0,
      rating: _doubleValue(data['rating']),
      subscriptionId: data['subscriptionId'] as String? ?? '',
      subscriptionStatus: data['subscriptionStatus'] as String? ?? 'none',
      subscriptionStartDate: _dateValue(data['subscriptionStartDate']),
      subscriptionEndDate: _dateValue(data['subscriptionEndDate']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  // ═════════════════════════════════════════════
  // نسخ النموذج مع تعديل بعض القيم
  // ═════════════════════════════════════════════

  OfficeModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? logoUrl,
    String? coverImageUrl,
    List<String>? galleryImages,
    String? phone,
    String? whatsapp,
    String? email,
    String? website,
    String? facebook,
    String? instagram,
    String? telegram,
    String? tiktok,
    String? youtube,
    String? city,
    String? district,
    String? areaName,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? services,
    Map<String, String>? workingHours,
    int? establishedYear,
    String? licenseNumber,
    bool? isVerified,
    String? verificationStatus,
    String? verificationNote,
    String? licenseImageUrl,
    String? status,
    bool? isFeatured,
    DateTime? featuredUntil,
    int? propertiesCount,
    int? followersCount,
    int? viewsCount,
    int? reviewsCount,
    double? rating,
    String? subscriptionId,
    String? subscriptionStatus,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    int? maxProperties,
    int? maxFeaturedProperties,
    bool? canFeatureProperties,
    bool? canAppearInFeaturedOffices,
    bool? canUseAdvancedStatistics,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfficeModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      website: website ?? this.website,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      telegram: telegram ?? this.telegram,
      tiktok: tiktok ?? this.tiktok,
      youtube: youtube ?? this.youtube,
      city: city ?? this.city,
      district: district ?? this.district,
      areaName: areaName ?? this.areaName,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      services: services ?? this.services,
      workingHours: workingHours ?? this.workingHours,
      establishedYear: establishedYear ?? this.establishedYear,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationNote: verificationNote ?? this.verificationNote,
      licenseImageUrl: licenseImageUrl ?? this.licenseImageUrl,
      status: status ?? this.status,
      isFeatured: isFeatured ?? this.isFeatured,
      featuredUntil: featuredUntil ?? this.featuredUntil,
      propertiesCount: propertiesCount ?? this.propertiesCount,
      followersCount: followersCount ?? this.followersCount,
      viewsCount: viewsCount ?? this.viewsCount,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      rating: rating ?? this.rating,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionStartDate:
          subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      maxProperties: maxProperties ?? this.maxProperties,
      maxFeaturedProperties:
          maxFeaturedProperties ?? this.maxFeaturedProperties,
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
  // التحقق من صلاحية الاشتراك
  // ═════════════════════════════════════════════

  bool get hasActiveSubscription {
    if (subscriptionStatus != 'active') {
      return false;
    }

    if (subscriptionEndDate == null) {
      return false;
    }

    return DateTime.now().isBefore(subscriptionEndDate!);
  }

  // ═════════════════════════════════════════════
  // هل انتهى الاشتراك؟
  // ═════════════════════════════════════════════

  bool get isSubscriptionExpired {
    if (subscriptionEndDate == null) {
      return false;
    }

    return !DateTime.now().isBefore(subscriptionEndDate!);
  }

  // ═════════════════════════════════════════════
  // عدد الأيام المتبقية
  // ═════════════════════════════════════════════

  int get remainingSubscriptionDays {
    if (subscriptionEndDate == null) {
      return 0;
    }

    final difference = subscriptionEndDate!.difference(DateTime.now()).inDays;

    return difference < 0 ? 0 : difference;
  }

  // ═════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value.whereType<String>().toList();
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) {
      return {};
    }

    return value.map(
      (key, value) => MapEntry(
        key.toString(),
        value?.toString() ?? '',
      ),
    );
  }

  static double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
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
