import 'property_location.dart';

/// نسخة خفيفة من العقار مخصصة لنظام الخرائط.
///
/// لا يمثل العقار بالكامل، بل يحتوي فقط على البيانات
/// اللازمة لعرضه والبحث عنه على الخريطة.
class MapProperty {
  final String id;
  final int propertyNumber;

  final String title;
  final String propertyType;
  final String adType;

  final double price;

  final String imageUrl;

  final PropertyLocation location;

  final String availabilityStatus;

  final bool isFeatured;

  const MapProperty({
    required this.id,
    this.propertyNumber = 0,
    required this.title,
    required this.propertyType,
    required this.adType,
    required this.price,
    this.imageUrl = '',
    required this.location,
    this.availabilityStatus = 'available',
    this.isFeatured = false,
  });

  double get latitude => location.latitude;

  double get longitude => location.longitude;

  String get city => location.city;

  String get district => location.district;

  bool get hasValidLocation => location.hasCoordinates;

  MapProperty copyWith({
    String? id,
    int? propertyNumber,
    String? title,
    String? propertyType,
    String? adType,
    double? price,
    String? imageUrl,
    PropertyLocation? location,
    String? availabilityStatus,
    bool? isFeatured,
  }) {
    return MapProperty(
      id: id ?? this.id,
      propertyNumber: propertyNumber ?? this.propertyNumber,
      title: title ?? this.title,
      propertyType: propertyType ?? this.propertyType,
      adType: adType ?? this.adType,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  factory MapProperty.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return MapProperty(
      id: id,
      propertyNumber: _toInt(
        map['adNumber'] ?? map['propertyNumber'],
      ),
      title: _toString(map['title']),
      propertyType: _toString(map['propertyType']),
      adType: _toString(map['adType']),
      price: _toDouble(map['price']),
      imageUrl: _extractImageUrl(map),
      location: PropertyLocation.fromPropertyMap(map),
      availabilityStatus: _toString(
        map['availabilityStatus'],
        fallback: 'available',
      ),
      isFeatured: map['isFeatured'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adNumber': propertyNumber,
      'title': title,
      'propertyType': propertyType,
      'adType': adType,
      'price': price,
      'imageUrl': imageUrl,
      'availabilityStatus': availabilityStatus,
      'isFeatured': isFeatured,
      'propertyLocation': location.toMap(),
    };
  }

  static String _extractImageUrl(
    Map<String, dynamic> map,
  ) {
    final images = map['images'];

    if (images is List && images.isNotEmpty) {
      final first = images.first?.toString().trim() ?? '';

      if (first.isNotEmpty) {
        return first;
      }
    }

    return _toString(map['imageUrl']);
  }

  static String _toString(
    dynamic value, {
    String fallback = '',
  }) {
    final result = value?.toString().trim() ?? '';

    return result.isEmpty ? fallback : result;
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is MapProperty && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MapProperty('
        'id: $id, '
        'propertyNumber: $propertyNumber, '
        'title: $title, '
        'city: $city, '
        'district: $district'
        ')';
  }
}
