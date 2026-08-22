import 'map_property.dart';

/// مجموعة من العقارات المتقاربة جغرافيًا.
///
/// تستخدم لإظهار Marker واحد يحمل عدد العقارات
/// بدل عرض عدد كبير من العلامات فوق بعضها.
class MapCluster {
  final String id;

  final double latitude;
  final double longitude;

  final List<MapProperty> properties;

  const MapCluster({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.properties,
  });

  int get count => properties.length;

  bool get isCluster => count > 1;

  bool get isSingle => count == 1;

  MapProperty? get singleProperty {
    if (!isSingle) {
      return null;
    }

    return properties.first;
  }

  bool containsProperty(String propertyId) {
    return properties.any(
      (property) => property.id == propertyId,
    );
  }

  List<String> get propertyIds {
    return List<String>.unmodifiable(
      properties.map((property) => property.id),
    );
  }

  MapCluster copyWith({
    String? id,
    double? latitude,
    double? longitude,
    List<MapProperty>? properties,
  }) {
    return MapCluster(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is MapCluster && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MapCluster('
        'id: $id, '
        'count: $count, '
        'latitude: $latitude, '
        'longitude: $longitude'
        ')';
  }
}
