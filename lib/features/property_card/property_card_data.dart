/// بيانات بطاقة العقار — تُمرَّر من شاشة تفاصيل العقار
class PropertyCardData {
  const PropertyCardData({
    required this.id,
    required this.number,
    required this.title,
    required this.imageUrl,
    required this.images,
    required this.propertyType,
    required this.adType,
    required this.price,
    required this.negotiable,
    required this.location,
    required this.city,
    required this.areaName,
    required this.landmark,
    required this.rooms,
    required this.bathrooms,
    required this.livingRooms,
    required this.parking,
    required this.area,
    this.frontage,
    this.depth,
    this.floors,
    this.apartmentFloor,
    this.unitsCount,
    required this.buildYear,
    required this.documentType,
    required this.furnitureStatus,
    required this.availabilityStatus,
    required this.features,
    required this.description,
    required this.contactName,
    required this.contactPhone,
    required this.contactWhatsapp,
    required this.isOffice,
    required this.isVerified,
    required this.isFeatured,
    required this.cardDate,
  });

  final String id;
  final int number;
  final String title;

  /// الصورة الرئيسية
  final String imageUrl;

  /// قائمة الصور الكاملة (تشمل الرئيسية)
  final List<String> images;

  final String propertyType;
  final String adType;
  final double price;
  final bool negotiable;

  final String location;
  final String city;
  final String areaName;
  final String landmark;

  final int rooms;
  final int bathrooms;
  final int livingRooms;
  final int parking;
  final int area;
  final double? frontage;
  final double? depth;
  final int? floors;
  final int? apartmentFloor;
  final int? unitsCount;
  final int buildYear;

  final String documentType;
  final String furnitureStatus;
  final String availabilityStatus;

  final List<dynamic> features;
  final String description;

  final String contactName;
  final String contactPhone;
  final String contactWhatsapp;
  final bool isOffice;

  final bool isVerified;
  final bool isFeatured;

  /// تاريخ إنشاء البطاقة — يُستخدم في الـ Footer
  final DateTime cardDate;

  /// رابط صفحة العقار على الويب
  String get publicUrl =>
      'https://aysar93.github.io/aqar-pages/property/?id=${Uri.encodeComponent(id)}';

  /// الأنواع التي لا تستخدم غرف النوم والحمامات وغرف المعيشة والكراج
  static const _landTypes = {'أرض', 'land', 'ارض'};

  bool get isLandType =>
      _landTypes.contains(propertyType.toLowerCase().trim()) ||
      propertyType.trim() == 'أرض';

  /// يعيد تسمية نوع الإعلان باللغة العربية
  String get adTypeLabel => switch (adType.toLowerCase().trim()) {
        'sell' || 'sale' || 'بيع' => 'بيع',
        'rent' || 'rental' || 'إيجار' || 'ايجار' => 'إيجار',
        'مراوس' || 'invest' || 'investment' => 'مراوس',
        _ => adType,
      };

  /// حالة العقار باللغة العربية
  String get statusLabel => switch (availabilityStatus.toLowerCase().trim()) {
        'sold' => 'تم البيع',
        'rented' => 'تم التأجير',
        'available' || '' => 'متوفر',
        _ => availabilityStatus,
      };
}
