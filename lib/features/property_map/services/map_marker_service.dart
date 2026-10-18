import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_cluster.dart';
import '../models/map_property.dart';

typedef PropertyMarkerTap = void Function(
  MapProperty property,
);

typedef ClusterMarkerTap = void Function(
  MapCluster cluster,
);

/// مسؤول عن إنشاء Markers الخاصة بخريطة العقارات.
///
/// يدعم:
/// - Marker لعقار منفرد.
/// - Marker دائري للـ Cluster مع العدد.
/// - Marker مختلف للعقار المحدد.
/// - الضغط على العقار أو المجموعة.
///
/// مع flutter_map لا نحتاج BitmapDescriptor؛
/// كل Marker يحتوي Widget Flutter مباشرة.
class MapMarkerService {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);

  const MapMarkerService();

  List<Marker> buildMarkers({
    required List<MapCluster> clusters,
    String? selectedPropertyId,
    PropertyMarkerTap? onPropertyTap,
    ClusterMarkerTap? onClusterTap,
  }) {
    final markers = <Marker>[];

    for (final cluster in clusters) {
      if (cluster.isSingle) {
        final property = cluster.singleProperty;

        if (property == null) {
          continue;
        }

        final isSelected = property.id == selectedPropertyId;

        final size = isSelected ? 62.0 : 54.0;

        markers.add(
          Marker(
            point: LatLng(
              property.latitude,
              property.longitude,
            ),
            width: size,
            height: size,
            alignment: Alignment.center,
            child: _PropertyMarker(
              selected: isSelected,
              featured: property.isFeatured,
              onTap: () {
                onPropertyTap?.call(property);
              },
            ),
          ),
        );

        continue;
      }

      final size = _clusterSize(
        _clusterBucket(cluster.count),
      );

      markers.add(
        Marker(
          point: LatLng(
            cluster.latitude,
            cluster.longitude,
          ),
          width: size,
          height: size,
          alignment: Alignment.center,
          child: _ClusterMarker(
            label: _clusterLabel(cluster.count),
            size: size,
            onTap: () {
              onClusterTap?.call(cluster);
            },
          ),
        ),
      );
    }

    return markers;
  }

  int _clusterBucket(int count) {
    if (count < 10) {
      return 1;
    }

    if (count < 50) {
      return 2;
    }

    if (count < 100) {
      return 3;
    }

    if (count < 500) {
      return 4;
    }

    return 5;
  }

  String _clusterLabel(int count) {
    if (count < 1000) {
      return '$count';
    }

    final thousands = count / 1000;

    if (thousands >= 10) {
      return '${thousands.floor()}K';
    }

    return '${thousands.toStringAsFixed(1)}K';
  }

  double _clusterSize(int bucket) {
    switch (bucket) {
      case 1:
        return 58;
      case 2:
        return 64;
      case 3:
        return 70;
      case 4:
        return 76;
      default:
        return 82;
    }
  }
}

class _PropertyMarker extends StatelessWidget {
  final bool selected;
  final bool featured;
  final VoidCallback onTap;

  const _PropertyMarker({
    required this.selected,
    required this.featured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 58.0 : 50.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          width: size,
          height: size,
          padding: EdgeInsets.all(
            selected ? 4 : 5,
          ),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MapMarkerService._card,
            border: Border.all(
              color: MapMarkerService._gold,
              width: selected ? 3.5 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.30,
                ),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
              if (selected)
                BoxShadow(
                  color: MapMarkerService._gold.withValues(
                    alpha: 0.28,
                  ),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Icon(
                        Icons.location_on_rounded,
                        color: MapMarkerService._gold,
                        size: 26,
                      );
                    },
                  ),
                ),
              ),

              // شارة صغيرة للعقار المميز.
              if (featured)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      color: MapMarkerService._gold,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MapMarkerService._card,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 11,
                      color: MapMarkerService._dark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  final String label;
  final double size;
  final VoidCallback onTap;

  const _ClusterMarker({
    required this.label,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Container(
          width: size - 6,
          height: size - 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MapMarkerService._gold,
            border: Border.all(
              color: MapMarkerService._gold.withValues(
                alpha: 0.35,
              ),
              width: 5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.32,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MapMarkerService._dark,
              fontSize: _fontSize,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  double get _fontSize {
    if (size <= 58) {
      return 17;
    }

    if (size <= 64) {
      return 18;
    }

    if (size <= 70) {
      return 19;
    }

    if (size <= 76) {
      return 20;
    }

    return 21;
  }
}
