import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapTestScreen extends StatelessWidget {
  const MapTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار الخارطة'),
      ),
      body: FlutterMap(
        options: const MapOptions(
          // الرمادي - الأنبار
          initialCenter: LatLng(33.4255, 43.2997),
          initialZoom: 13.0,
          minZoom: 5.0,
          maxZoom: 18.0,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.drag |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.aqar',
            maxNativeZoom: 18,
            maxZoom: 18,
          ),
        ],
      ),
    );
  }
}
