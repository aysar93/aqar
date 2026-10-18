import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// طبقة الخرائط الموحدة لكل شاشات العقارات.
///
/// نستخدم إعدادًا واحدًا حتى لا تختلف خصائص الـTiles بين
/// خريطة البحث، محدد الموقع، وشاشة عرض موقع العقار.
class AqarMapTileLayer extends StatelessWidget {
  const AqarMapTileLayer({super.key});

  static const String urlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String userAgentPackageName = 'com.example.aqar';

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: userAgentPackageName,
      maxNativeZoom: 19,
      maxZoom: 19,
      keepBuffer: 5,
      panBuffer: 2,
    );
  }
}
