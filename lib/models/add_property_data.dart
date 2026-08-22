import 'dart:io';

class AddPropertyData {
// =========================
// الخطوة 1 - نوع الإعلان
// =========================

  String? adType;

// =========================
// الخطوة 2 - نوع العقار
// =========================

  String? propertyType;

// =========================
// الخطوة 3 - تفاصيل العقار
// =========================

  String title = "";

  /// عدد الغرف
  int? rooms;

  /// عدد الحمامات
  int? bathrooms;

  /// عدد المجالس
  int? livingRooms;

  /// عدد مواقف السيارات
  int? parking;

  /// المساحة الكلية بالمتر المربع
  double? area;

  /// الواجهة بالمتر
  double? frontage;

  /// النزال / العمق بالمتر
  double? depth;

  /// عدد الطوابق للبيت والمحل والعمارة والمزرعة
  int? floors;

  /// الطابق الذي تقع فيه الشقة
  int? apartmentFloor;

  /// عدد الشقق / الوحدات في العمارة
  int? unitsCount;

  /// سنة البناء
  int? buildYear;

  /// نوع السند
  String? documentType;

  /// حالة الأثاث
  String? furnitureStatus;

// =========================
// الخطوة 4 - الموقع والوصف
// =========================

  String city = "";

  String district = "";

  String landmark = "";

  double? latitude;

  double? longitude;

  String description = "";

  List<String> features = [];

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
// الخطوة 5 - السعر
// =========================

  double? price;

  bool negotiable = false;

// =========================
// الخطوة 6 - الصور
// =========================

  List<String> imageUrls = [];

  List<File> selectedImages = [];

// =========================
// الخطوة 7 - التواصل
// =========================

  String phone = "";

  String whatsapp = "";

// =========================
// تنظيف التفاصيل حسب النوع
// =========================

  void clearFieldsNotUsedByPropertyType() {
    switch (propertyType) {
      case "أرض":
// الأرض لا تحتوي على تفاصيل بناء.
        rooms = null;
        bathrooms = null;
        livingRooms = null;
        parking = null;
        floors = null;
        apartmentFloor = null;
        unitsCount = null;
        buildYear = null;
        furnitureStatus = null;
        break;

      case "محل":
        // المحل لا يستخدم تفاصيل العقار السكني.
        rooms = null;
        bathrooms = null;
        livingRooms = null;
        apartmentFloor = null;
        unitsCount = null;
        furnitureStatus = null;
        break;

      case "عمارة":
        // العمارة تعتمد على الطوابق والوحدات بدل غرف بيت واحد.
        rooms = null;
        bathrooms = null;
        livingRooms = null;
        apartmentFloor = null;
        furnitureStatus = null;
        break;

      case "شقة":
        // الشقة لها طابق موقعها، وليس عدد طوابق العقار.
        floors = null;
        unitsCount = null;

        // الواجهة والنزال يخصان الأرض/البناء ككل،
        // وليس الشقة نفسها.
        frontage = null;
        depth = null;
        break;

      case "بيت":
      case "مزرعة":
        // البيت والمزرعة يستخدمان عدد الطوابق،
        // ولا يحتاجان حقول الشقة أو العمارة.
        apartmentFloor = null;
        unitsCount = null;
        break;

      default:
        break;
    }
  }
}
