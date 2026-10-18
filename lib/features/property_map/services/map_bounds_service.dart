import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/anbar_map_config.dart';
import '../models/map_property.dart';
import '../models/property_location.dart';
import '../utils/map_validators.dart';

/// مسؤول عن العمليات المتعلقة بحدود الخريطة.
///
/// في المرحلة الحالية نعتمد الحدود التشغيلية الموجودة
/// في AnbarMapConfig. ويمكن لاحقًا استبدال التحقق
/// بمضلع Polygon دقيق لحدود محافظة الأنبار دون تغيير
/// بقية أجزاء النظام.
class MapBoundsService {
  const MapBoundsService();

  /// الحدود التشغيلية العامة لخريطة الأنبار.
  LatLngBounds get anbarBounds => AnbarMapConfig.cameraBounds;

  /// هل النقطة داخل النطاق التشغيلي لخريطة الأنبار؟
  bool containsLatLng(LatLng point) {
    return _contains(
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  /// هل موقع العقار صالح ويقع داخل النطاق؟
  bool containsLocation(PropertyLocation location) {
    if (!MapValidators.hasValidCoordinates(
      latitude: location.latitude,
      longitude: location.longitude,
    )) {
      return false;
    }

    return _contains(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  /// هل العقار يمتلك موقعًا صالحًا داخل النطاق؟
  bool containsProperty(MapProperty property) {
    return containsLocation(property.location);
  }

  /// تصفية العقارات وإبقاء المواقع الصالحة فقط.
  List<MapProperty> filterProperties(
    Iterable<MapProperty> properties,
  ) {
    return properties.where(containsProperty).toList(growable: false);
  }

  /// هل النقطة داخل حدود ظاهرة معينة من الخريطة؟
  bool containsInBounds({
    required LatLng point,
    required LatLngBounds bounds,
  }) {
    return _containsCustomBounds(
      latitude: point.latitude,
      longitude: point.longitude,
      bounds: bounds,
    );
  }

  /// العقارات الموجودة حاليًا داخل الجزء الظاهر من الخريطة.
  List<MapProperty> propertiesInsideBounds({
    required Iterable<MapProperty> properties,
    required LatLngBounds bounds,
  }) {
    return properties.where((property) {
      if (!containsProperty(property)) {
        return false;
      }

      return containsInBounds(
        point: LatLng(
          property.latitude,
          property.longitude,
        ),
        bounds: bounds,
      );
    }).toList(growable: false);
  }

  /// يحصر نقطة ضمن الحدود التشغيلية.
  ///
  /// مفيد إذا حاولت الخريطة أو محدد الموقع الخروج
  /// عن النطاق المسموح.
  LatLng clampToAnbarBounds(LatLng point) {
    final latitude = point.latitude.clamp(
      AnbarMapConfig.southWest.latitude,
      AnbarMapConfig.northEast.latitude,
    );

    final longitude = point.longitude.clamp(
      AnbarMapConfig.southWest.longitude,
      AnbarMapConfig.northEast.longitude,
    );

    return LatLng(
      latitude.toDouble(),
      longitude.toDouble(),
    );
  }

  bool _contains({
    required double latitude,
    required double longitude,
  }) {
    return latitude >= AnbarMapConfig.southWest.latitude &&
        latitude <= AnbarMapConfig.northEast.latitude &&
        longitude >= AnbarMapConfig.southWest.longitude &&
        longitude <= AnbarMapConfig.northEast.longitude;
  }

  bool _containsCustomBounds({
    required double latitude,
    required double longitude,
    required LatLngBounds bounds,
  }) {
    final south = bounds.south;
    final north = bounds.north;
    final west = bounds.west;
    final east = bounds.east;

    final insideLatitude = latitude >= south && latitude <= north;

    if (!insideLatitude) {
      return false;
    }

    // الحالة الطبيعية.
    if (west <= east) {
      return longitude >= west && longitude <= east;
    }

    // دعم الحدود التي تعبر خط التاريخ الدولي.
    return longitude >= west || longitude <= east;
  }
}
