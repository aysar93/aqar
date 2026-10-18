import 'package:cloud_firestore/cloud_firestore.dart';

/// البيانات المؤقتة المستخدمة أثناء إنشاء طلب الانضمام إلى المكتب.
///
/// يتم جمع البيانات على عدة خطوات ثم تستخدم في:
/// - مراجعة الطلب قبل الإرسال.
/// - إنشاء طلب داخل officeRequests.
/// - إنشاء OfficeModel بعد الموافقة من الإدارة.
class JoinOfficeData {
  // ═════════════════════════════════════════════
  // معلومات المالك
  // ═════════════════════════════════════════════

  String ownerId;

  // ═════════════════════════════════════════════
  // معلومات المكتب الأساسية
  // ═════════════════════════════════════════════

  String name;
  String description;

  String logoUrl;
  String coverImageUrl;

  List<String> galleryImages;

  // ═════════════════════════════════════════════
  // معلومات التواصل
  // ═════════════════════════════════════════════

  String phone;
  String whatsapp;
  String email;
  String website;

  // ═════════════════════════════════════════════
  // مواقع التواصل الاجتماعي
  // ═════════════════════════════════════════════

  String facebook;
  String instagram;
  String telegram;
  String tiktok;
  String youtube;

  // ═════════════════════════════════════════════
  // الموقع
  // ═════════════════════════════════════════════

  String city;
  String district;
  String areaName;
  String address;

  double latitude;
  double longitude;

  // ═════════════════════════════════════════════
  // معلومات إضافية عن المكتب
  // ═════════════════════════════════════════════

  List<String> services;

  Map<String, String> workingHours;

  int? establishedYear;

  String licenseNumber;
  String licenseImageUrl;

  // ═════════════════════════════════════════════
  // المنشئ
  // ═════════════════════════════════════════════

  JoinOfficeData({
    this.ownerId = '',
    this.name = '',
    this.description = '',
    this.logoUrl = '',
    this.coverImageUrl = '',
    List<String>? galleryImages,
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
    List<String>? services,
    Map<String, String>? workingHours,
    this.establishedYear,
    this.licenseNumber = '',
    this.licenseImageUrl = '',
  })  : galleryImages = List<String>.from(galleryImages ?? const []),
        services = List<String>.from(services ?? const []),
        workingHours = Map<String, String>.from(
          workingHours ?? const {},
        );

  // ═════════════════════════════════════════════
  // نسخ البيانات
  // ═════════════════════════════════════════════

  JoinOfficeData copyWith({
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
    String? licenseImageUrl,
  }) {
    return JoinOfficeData(
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
      licenseImageUrl: licenseImageUrl ?? this.licenseImageUrl,
    );
  }

  // ═════════════════════════════════════════════
  // التحقق من البيانات الأساسية
  // ═════════════════════════════════════════════

  bool get hasBasicInfo {
    return name.trim().isNotEmpty;
  }

  bool get hasContactInfo {
    return phone.trim().isNotEmpty ||
        whatsapp.trim().isNotEmpty ||
        email.trim().isNotEmpty;
  }

  bool get hasLocation {
    return city.trim().isNotEmpty && address.trim().isNotEmpty;
  }

  bool get isReadyForSubmission {
    return ownerId.trim().isNotEmpty &&
        name.trim().isNotEmpty &&
        hasContactInfo &&
        city.trim().isNotEmpty;
  }

  // ═════════════════════════════════════════════
  // تحويل إلى Firestore
  // ═════════════════════════════════════════════

  Map<String, dynamic> toFirestore({
    bool includeStatus = true,
  }) {
    final data = <String, dynamic>{
      'ownerId': ownerId.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'logoUrl': logoUrl.trim(),
      'coverImageUrl': coverImageUrl.trim(),
      'galleryImages': List<String>.from(galleryImages),
      'phone': phone.trim(),
      'whatsapp': whatsapp.trim(),
      'email': email.trim(),
      'website': website.trim(),
      'facebook': facebook.trim(),
      'instagram': instagram.trim(),
      'telegram': telegram.trim(),
      'tiktok': tiktok.trim(),
      'youtube': youtube.trim(),
      'city': city.trim(),
      'district': district.trim(),
      'areaName': areaName.trim(),
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'services': List<String>.from(services),
      'workingHours': Map<String, String>.from(
        workingHours,
      ),
      'establishedYear': establishedYear,
      'licenseNumber': licenseNumber.trim(),
      'licenseImageUrl': licenseImageUrl.trim(),
    };

    if (includeStatus) {
      data.addAll({
        'status': 'pending',
        'isVerified': false,
        'verificationStatus': 'not_requested',
        'verificationNote': '',
        'isFeatured': false,
        'propertiesCount': 0,
        'followersCount': 0,
        'viewsCount': 0,
        'reviewsCount': 0,
        'rating': 0,
        'subscriptionId': '',
        'subscriptionStatus': 'none',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return data;
  }

  // ═════════════════════════════════════════════
  // تحويل من Firestore
  // ═════════════════════════════════════════════

  factory JoinOfficeData.fromMap(
    Map<String, dynamic> map,
  ) {
    return JoinOfficeData(
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
      coverImageUrl: map['coverImageUrl'] as String? ?? '',
      galleryImages: _stringList(
        map['galleryImages'],
      ),
      phone: map['phone'] as String? ?? '',
      whatsapp: map['whatsapp'] as String? ?? '',
      email: map['email'] as String? ?? '',
      website: map['website'] as String? ?? '',
      facebook: map['facebook'] as String? ?? '',
      instagram: map['instagram'] as String? ?? '',
      telegram: map['telegram'] as String? ?? '',
      tiktok: map['tiktok'] as String? ?? '',
      youtube: map['youtube'] as String? ?? '',
      city: map['city'] as String? ?? '',
      district: map['district'] as String? ?? '',
      areaName: map['areaName'] as String? ?? '',
      address: map['address'] as String? ?? '',
      latitude: _doubleValue(
        map['latitude'],
      ),
      longitude: _doubleValue(
        map['longitude'],
      ),
      services: _stringList(
        map['services'],
      ),
      workingHours: _stringMap(
        map['workingHours'],
      ),
      establishedYear: _intValue(
        map['establishedYear'],
      ),
      licenseNumber: map['licenseNumber'] as String? ?? '',
      licenseImageUrl: map['licenseImageUrl'] as String? ?? '',
    );
  }

  // ═════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════

  static List<String> _stringList(
    dynamic value,
  ) {
    if (value is Iterable) {
      return value
          .map(
            (item) => item.toString(),
          )
          .toList();
    }

    return <String>[];
  }

  static Map<String, String> _stringMap(
    dynamic value,
  ) {
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(
          key.toString(),
          value.toString(),
        ),
      );
    }

    return <String, String>{};
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

  static int? _intValue(
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
    );
  }
}
