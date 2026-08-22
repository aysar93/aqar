import 'dart:io';

class EditPropertyData {
  // =========================
  // هوية العقار
  // =========================

  final String docId;

  // =========================
  // نوع الإعلان والعقار
  // =========================

  String? adType;
  String? propertyType;

  // =========================
  // التفاصيل
  // =========================

  String title;

  int? rooms;
  int? bathrooms;
  int? livingRooms;
  int? parking;

  double? area;

  int? buildYear;

  String? documentType;
  String? furnitureStatus;

  // =========================
  // الموقع
  // =========================

  String city;
  String district;
  String landmark;

  double? latitude;
  double? longitude;

  bool get hasMapLocation {
    return latitude != null &&
        longitude != null &&
        latitude! >= -90 &&
        latitude! <= 90 &&
        longitude! >= -180 &&
        longitude! <= 180 &&
        !(latitude == 0 && longitude == 0);
  }

  // =========================
  // السعر
  // =========================

  double? price;
  bool negotiable;

  // =========================
  // الصور
  // =========================

  /// الصور الموجودة أصلًا في Firestore.
  List<String> existingImages;

  /// الصور الجديدة التي اختارها المستخدم من الجهاز.
  List<File> newImages;

  // =========================
  // المميزات
  // =========================

  List<String> features;

  // =========================
  // الوصف والتواصل
  // =========================

  String description;
  String phone;
  String whatsapp;

  // =========================
  // Constructor
  // =========================

  EditPropertyData({
    required this.docId,
    this.adType,
    this.propertyType,
    this.title = '',
    this.rooms,
    this.bathrooms,
    this.livingRooms,
    this.parking,
    this.area,
    this.buildYear,
    this.documentType,
    this.furnitureStatus,
    this.city = '',
    this.district = '',
    this.landmark = '',
    this.latitude,
    this.longitude,
    this.price,
    this.negotiable = false,
    List<String>? existingImages,
    List<File>? newImages,
    List<String>? features,
    this.description = '',
    this.phone = '',
    this.whatsapp = '',
  })  : existingImages = existingImages ?? [],
        newImages = newImages ?? [],
        features = features ?? [];

  // =========================
  // إنشاء بيانات التعديل
  // من بيانات Firestore الحالية
  // =========================

  factory EditPropertyData.fromMap({
    required String docId,
    required Map<String, dynamic> map,
  }) {
    return EditPropertyData(
      docId: docId,

      adType: map['adType']?.toString(),
      propertyType: map['propertyType']?.toString(),

      title: map['title']?.toString() ?? '',

      rooms: _toInt(map['rooms']),
      bathrooms: _toInt(map['bathrooms']),
      livingRooms: _toInt(map['livingRooms']),
      parking: _toInt(map['parking']),

      area: _toDouble(map['area']),

      buildYear: _toInt(map['buildYear']),

      documentType: map['documentType']?.toString(),
      furnitureStatus: map['furnitureStatus']?.toString(),

      city: map['city']?.toString() ?? '',

      // دعم district الحالي و areaName إن وجد في بيانات أخرى.
      district:
          map['district']?.toString() ?? map['areaName']?.toString() ?? '',

      landmark: map['landmark']?.toString() ?? '',

      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),

      price: _toDouble(map['price']),
      negotiable: map['negotiable'] == true,

      existingImages: _readImages(map),

      features: _readStringList(map['features']),

      description: map['description']?.toString() ?? '',

      phone: map['ownerPhone']?.toString() ?? map['phone']?.toString() ?? '',

      whatsapp:
          map['ownerWhatsapp']?.toString() ?? map['whatsapp']?.toString() ?? '',
    );
  }

  // =========================
  // تحويل البيانات للحفظ
  // =========================

  Map<String, dynamic> toUpdateMap({
    required List<String> finalImages,
  }) {
    return {
      'adType': adType,
      'propertyType': propertyType,

      'title': title,

      'rooms': rooms ?? 0,
      'bathrooms': bathrooms ?? 0,
      'livingRooms': livingRooms ?? 0,
      'parking': parking ?? 0,

      'area': area ?? 0,

      'buildYear': buildYear ?? 0,

      'documentType': documentType ?? '',
      'furnitureStatus': furnitureStatus ?? '',

      'city': city,
      'district': district,
      'landmark': landmark,

      'latitude': latitude,
      'longitude': longitude,

      'price': price ?? 0,
      'negotiable': negotiable,

      'images': finalImages,

      'imageUrl': finalImages.isNotEmpty ? finalImages.first : '',

      'features': features,

      'description': description,

      'ownerPhone': phone,
      'ownerWhatsapp': whatsapp,

      // أي تعديل يعيد العقار للمراجعة.
      'status': 'pending',
    };
  }

  // =========================
  // Helpers
  // =========================

  static int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .where((item) => item != null)
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _readImages(
    Map<String, dynamic> map,
  ) {
    final images = _readStringList(map['images']);

    if (images.isNotEmpty) {
      return images;
    }

    final imageUrl = map['imageUrl']?.toString() ?? '';

    if (imageUrl.isNotEmpty) {
      return [imageUrl];
    }

    return [];
  }
}
