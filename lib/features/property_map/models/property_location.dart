import 'package:cloud_firestore/cloud_firestore.dart';

/// يمثل الموقع الجغرافي الكامل للعقار.
///
/// هذا الـ Model هو المرجع الموحد للموقع داخل نظام الخرائط:
/// - عند تحديد الموقع أثناء إضافة العقار.
/// - عند حفظ الموقع في Firestore.
/// - عند عرض موقع العقار.
/// - عند البحث بالخريطة.
class PropertyLocation {
  final String governorate;
  final String city;
  final String district;
  final String landmark;

  final double latitude;
  final double longitude;

  const PropertyLocation({
    this.governorate = 'الأنبار',
    required this.city,
    required this.district,
    this.landmark = '',
    required this.latitude,
    required this.longitude,
  });

  /// هل توجد إحداثيات صالحة مبدئيًا؟
  bool get hasCoordinates {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  /// GeoPoint لاستخدامه عند التعامل مع Firestore.
  GeoPoint get geoPoint => GeoPoint(latitude, longitude);

  /// اسم الموقع المناسب للعرض.
  String get displayName {
    final parts = <String>[
      city.trim(),
      district.trim(),
    ].where((value) => value.isNotEmpty).toList();

    return parts.join(' - ');
  }

  /// الاسم الكامل للموقع.
  String get fullDisplayName {
    final parts = <String>[
      governorate.trim(),
      city.trim(),
      district.trim(),
      landmark.trim(),
    ].where((value) => value.isNotEmpty).toList();

    return parts.join(' - ');
  }

  PropertyLocation copyWith({
    String? governorate,
    String? city,
    String? district,
    String? landmark,
    double? latitude,
    double? longitude,
  }) {
    return PropertyLocation(
      governorate: governorate ?? this.governorate,
      city: city ?? this.city,
      district: district ?? this.district,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'governorate': governorate,
      'city': city,
      'district': district,
      'landmark': landmark,
      'latitude': latitude,
      'longitude': longitude,
      'geoPoint': geoPoint,
    };
  }

  factory PropertyLocation.fromMap(Map<String, dynamic> map) {
    final geoPoint = map['geoPoint'];

    final latitude = _toDouble(map['latitude']) ??
        (geoPoint is GeoPoint ? geoPoint.latitude : null);

    final longitude = _toDouble(map['longitude']) ??
        (geoPoint is GeoPoint ? geoPoint.longitude : null);

    return PropertyLocation(
      governorate: _toString(map['governorate'], fallback: 'الأنبار'),
      city: _toString(map['city']),
      district: _toString(
        map['district'] ?? map['areaName'],
      ),
      landmark: _toString(map['landmark']),
      latitude: latitude ?? 0,
      longitude: longitude ?? 0,
    );
  }

  /// يدعم أيضًا شكل بيانات العقارات الحالي الذي تكون فيه
  /// latitude و longitude في المستوى الرئيسي للمستند.
  factory PropertyLocation.fromPropertyMap(
    Map<String, dynamic> map,
  ) {
    final nestedLocation = map['propertyLocation'];

    if (nestedLocation is Map) {
      return PropertyLocation.fromMap(
        Map<String, dynamic>.from(nestedLocation),
      );
    }

    return PropertyLocation.fromMap(map);
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  static String _toString(
    dynamic value, {
    String fallback = '',
  }) {
    final result = value?.toString().trim() ?? '';

    return result.isEmpty ? fallback : result;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PropertyLocation &&
        other.governorate == governorate &&
        other.city == city &&
        other.district == district &&
        other.landmark == landmark &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return Object.hash(
      governorate,
      city,
      district,
      landmark,
      latitude,
      longitude,
    );
  }

  @override
  String toString() {
    return 'PropertyLocation('
        'governorate: $governorate, '
        'city: $city, '
        'district: $district, '
        'landmark: $landmark, '
        'latitude: $latitude, '
        'longitude: $longitude'
        ')';
  }
}
