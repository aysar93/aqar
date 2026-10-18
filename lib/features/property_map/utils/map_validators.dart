import '../models/property_location.dart';

/// جميع عمليات التحقق العامة المتعلقة بموقع العقار.
///
/// التحقق الهندسي من وجود النقطة داخل حدود الأنبار
/// سيكون داخل MapBoundsService.
class MapValidators {
  MapValidators._();

  static bool isValidLatitude(double latitude) {
    return latitude >= -90 && latitude <= 90;
  }

  static bool isValidLongitude(double longitude) {
    return longitude >= -180 && longitude <= 180;
  }

  static bool hasValidCoordinates({
    required double latitude,
    required double longitude,
  }) {
    return isValidLatitude(latitude) &&
        isValidLongitude(longitude) &&
        !isZeroCoordinate(
          latitude: latitude,
          longitude: longitude,
        );
  }

  /// يمنع اعتبار 0,0 موقعًا صالحًا لعقار.
  ///
  /// PropertyLocation قد يستخدم الصفر عند قراءة بيانات قديمة
  /// لا تحتوي إحداثيات، لذلك نميزه هنا كموقع غير محدد.
  static bool isZeroCoordinate({
    required double latitude,
    required double longitude,
  }) {
    return latitude == 0 && longitude == 0;
  }

  static bool hasCity(PropertyLocation location) {
    return location.city.trim().isNotEmpty;
  }

  static bool hasDistrict(PropertyLocation location) {
    return location.district.trim().isNotEmpty;
  }

  static bool hasRequiredAddress(
    PropertyLocation location,
  ) {
    return hasCity(location) && hasDistrict(location);
  }

  static bool isLocationComplete(
    PropertyLocation location,
  ) {
    return hasRequiredAddress(location) &&
        hasValidCoordinates(
          latitude: location.latitude,
          longitude: location.longitude,
        );
  }

  /// يعيد رسالة مناسبة للواجهة، أو null إذا كانت
  /// البيانات الأساسية صحيحة.
  ///
  /// لا يتحقق هنا من كون النقطة داخل الأنبار؛
  /// تلك مسؤولية MapBoundsService.
  static String? validateLocation(
    PropertyLocation location,
  ) {
    if (!hasCity(location)) {
      return 'يرجى اختيار المدينة';
    }

    if (!hasDistrict(location)) {
      return 'يرجى اختيار المنطقة أو الحي';
    }

    if (!hasValidCoordinates(
      latitude: location.latitude,
      longitude: location.longitude,
    )) {
      return 'يرجى تحديد موقع العقار على الخريطة';
    }

    return null;
  }

  static bool isValidPriceRange({
    double? minPrice,
    double? maxPrice,
  }) {
    if (minPrice != null && minPrice < 0) {
      return false;
    }

    if (maxPrice != null && maxPrice < 0) {
      return false;
    }

    if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
      return false;
    }

    return true;
  }

  static bool isValidAreaRange({
    double? minArea,
    double? maxArea,
  }) {
    if (minArea != null && minArea < 0) {
      return false;
    }

    if (maxArea != null && maxArea < 0) {
      return false;
    }

    if (minArea != null && maxArea != null && minArea > maxArea) {
      return false;
    }

    return true;
  }
}
