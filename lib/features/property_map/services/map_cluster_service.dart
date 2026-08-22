import 'dart:math' as math;

import '../models/map_cluster.dart';
import '../models/map_property.dart';
import '../utils/map_constants.dart';

/// يبني مجموعات العقارات المتقاربة جغرافيًا حسب Zoom.
///
/// الخوارزمية الحالية Grid-based clustering:
/// سريعة، حتمية، ولا تحتاج مكتبة خارجية.
///
/// يمكن لاحقًا استبدالها بخوارزمية أكثر تقدمًا دون
/// تغيير Controller أو واجهة الخريطة.
class MapClusterService {
  const MapClusterService();

  List<MapCluster> createClusters({
    required List<MapProperty> properties,
    required double zoom,
  }) {
    if (properties.isEmpty) {
      return const [];
    }

    // عند التكبير العالي نعرض كل عقار منفردًا.
    if (zoom >= MapConstants.singleMarkerZoom) {
      return properties.map(_singlePropertyCluster).toList(growable: false);
    }

    final cellSize = _cellSizeForZoom(zoom);

    final buckets = <String, List<MapProperty>>{};

    for (final property in properties) {
      if (!property.hasValidLocation) {
        continue;
      }

      final x = (property.longitude / cellSize).floor();
      final y = (property.latitude / cellSize).floor();

      final key = '${x}_$y';

      buckets.putIfAbsent(key, () => <MapProperty>[]);
      buckets[key]!.add(property);
    }

    final clusters = <MapCluster>[];

    for (final entry in buckets.entries) {
      final bucketProperties = entry.value;

      if (bucketProperties.isEmpty) {
        continue;
      }

      if (bucketProperties.length < MapConstants.minimumClusterSize) {
        clusters.add(
          _singlePropertyCluster(bucketProperties.first),
        );
        continue;
      }

      final center = _calculateCenter(bucketProperties);

      clusters.add(
        MapCluster(
          id: '${MapConstants.clusterMarkerPrefix}${entry.key}',
          latitude: center.$1,
          longitude: center.$2,
          properties: List<MapProperty>.unmodifiable(
            bucketProperties,
          ),
        ),
      );
    }

    return List<MapCluster>.unmodifiable(clusters);
  }

  MapCluster _singlePropertyCluster(
    MapProperty property,
  ) {
    return MapCluster(
      id: '${MapConstants.propertyMarkerPrefix}${property.id}',
      latitude: property.latitude,
      longitude: property.longitude,
      properties: List<MapProperty>.unmodifiable(
        [property],
      ),
    );
  }

  (double, double) _calculateCenter(
    List<MapProperty> properties,
  ) {
    var latitudeSum = 0.0;
    var longitudeSum = 0.0;

    for (final property in properties) {
      latitudeSum += property.latitude;
      longitudeSum += property.longitude;
    }

    return (
      latitudeSum / properties.length,
      longitudeSum / properties.length,
    );
  }

  /// حجم الخلية الجغرافية يتناقص كلما زاد Zoom.
  ///
  /// نستخدم Web-Mercator zoom كمرجع تقريبي:
  /// عند Zoom منخفض تتجمع المدن والمناطق،
  /// وعند التكبير تنقسم المجموعات تدريجيًا.
  double _cellSizeForZoom(double zoom) {
    final safeZoom = zoom.clamp(4.0, 20.0).toDouble();

    final baseSize = 360.0 / math.pow(2.0, safeZoom);

    // نزيد مساحة التجميع قليلًا في المستويات البعيدة.
    if (safeZoom < 8) {
      return baseSize * 2.4;
    }

    if (safeZoom < MapConstants.detailedClusterZoom) {
      return baseSize * 1.8;
    }

    return baseSize * 1.25;
  }
}
