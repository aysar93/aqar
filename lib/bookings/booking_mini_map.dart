import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../features/property_map/widgets/aqar_map_tile_layer.dart';
import 'booking_location.dart';
import 'booking_widgets.dart';

class BookingVenueMiniMap extends StatelessWidget {
  final LatLng point;
  final Map<String, dynamic> venue;

  const BookingVenueMiniMap({
    super.key,
    required this.point,
    required this.venue,
  });

  Widget? _buildSafeTileLayer() {
    try {
      return TileLayer(
        urlTemplate: AqarMapTileLayer.urlTemplate,
        userAgentPackageName: AqarMapTileLayer.userAgentPackageName,
        errorTileCallback: (tile, error, stackTrace) {
          // Silently fallback without crashing
        },
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final latLng = point;
    final tileLayer = _buildSafeTileLayer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('booking-venue-minimap'),
          height: 180,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 1. FlutterMap Tile Layer
              FlutterMap(
                options: MapOptions(
                  initialCenter: latLng,
                  initialZoom: 14.5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  if (tileLayer != null) tileLayer,
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: latLng,
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.location_pin,
                            color: Color(0xFFEF4444),
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 2. Coordinates overlay pill
              PositionedDirectional(
                bottom: 8,
                start: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF0F172A) : Colors.white)
                        .withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.my_location, size: 12, color: bookingGold),
                      const SizedBox(width: 4),
                      Text(
                        '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Open in Google Maps Action Button
        ElevatedButton.icon(
          key: const ValueKey('booking-open-google-maps'),
          onPressed: () async {
            final opened = await bookingOpenDirections(point);
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تعذر فتح الخريطة. يرجى التحقق من توفر تطبيق الخرائط أو اتصال الإنترنت.',
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.map_rounded, size: 20),
          label: const Text(
            'فتح في خرائط Google',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: bookingNavy,
            foregroundColor: Colors.white,
            elevation: 1,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
