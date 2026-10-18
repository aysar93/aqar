class PropertyRequestData {
  // ==================================================
  // الخطوة 1 - نوع الطلب
  // ==================================================

  /// شراء أو إيجار
  String? requestType;

  // ==================================================
  // الخطوة 2 - نوع العقار
  // ==================================================

  /// بيت، شقة، أرض، محل، عمارة، مزرعة
  String? propertyType;

  // ==================================================
  // الخطوة 3 - الموقع
  // ==================================================

  String city = "";

  String district = "";

  /// أقرب نقطة دالة أو تفاصيل إضافية للموقع
  String landmark = "";

  // ==================================================
  // الخطوة 4 - المواصفات المطلوبة
  // ==================================================

  /// أقل مساحة مطلوبة بالمتر المربع
  double? minArea;

  /// أعلى مساحة مطلوبة بالمتر المربع
  double? maxArea;

  /// أقل ميزانية
  double? minPrice;

  /// أعلى ميزانية
  double? maxPrice;

  /// عدد الغرف المطلوب
  int? rooms;

  /// عدد الحمامات المطلوب
  int? bathrooms;

  /// عدد المجالس المطلوب
  int? livingRooms;

  /// عدد مواقف السيارات المطلوب
  int? parking;

  /// أقل عدد طوابق مطلوب
  int? minFloors;

  /// أعلى عدد طوابق مطلوب
  int? maxFloors;

  /// الطابق المطلوب للشقة
  int? apartmentFloor;

  /// وصف إضافي لما يبحث عنه المستخدم
  String description = "";

  // ==================================================
  // الخطوة 5 - معلومات التواصل
  // ==================================================

  String phone = "";

  String whatsapp = "";

  // ==================================================
  // تنظيف الحقول غير المستخدمة حسب نوع العقار
  // ==================================================

  void clearFieldsNotUsedByPropertyType() {
    switch (propertyType) {
      case "أرض":
        rooms = null;
        bathrooms = null;
        livingRooms = null;
        parking = null;
        minFloors = null;
        maxFloors = null;
        apartmentFloor = null;
        break;

      case "محل":
        rooms = null;
        bathrooms = null;
        livingRooms = null;
        apartmentFloor = null;
        break;

      case "عمارة":
        rooms = null;
        bathrooms = null;
        livingRooms = null;
        apartmentFloor = null;
        break;

      case "شقة":
        minFloors = null;
        maxFloors = null;
        break;

      case "بيت":
      case "مزرعة":
        apartmentFloor = null;
        break;

      default:
        break;
    }
  }

  // ==================================================
  // التحقق من نطاق المساحة
  // ==================================================

  bool get hasValidAreaRange {
    if (minArea == null || maxArea == null) {
      return true;
    }

    return minArea! <= maxArea!;
  }

  // ==================================================
  // التحقق من نطاق الميزانية
  // ==================================================

  bool get hasValidPriceRange {
    if (minPrice == null || maxPrice == null) {
      return true;
    }

    return minPrice! <= maxPrice!;
  }

  // ==================================================
  // الموقع
  // ==================================================

  bool get hasLocation {
    return city.trim().isNotEmpty && district.trim().isNotEmpty;
  }

  // ==================================================
  // معلومات التواصل
  // ==================================================

  bool get hasPhone {
    return phone.trim().isNotEmpty;
  }
}
