import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/anbar_map_config.dart';
import '../models/property_location.dart';
import '../widgets/location_summary_card.dart';

class PropertyLocationScreen extends StatelessWidget {
  final PropertyLocation location;
  final String? propertyTitle;

  const PropertyLocationScreen({
    super.key,
    required this.location,
    this.propertyTitle,
  });

  static const Color _background = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final position = LatLng(
      location.latitude,
      location.longitude,
    );

    return Scaffold(
      backgroundColor: _background,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // الخريطة تملأ كامل الشاشة.
            Directionality(
              textDirection: TextDirection.ltr,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: position,
                  initialZoom: AnbarMapConfig.propertyZoom,
                  minZoom: AnbarMapConfig.minZoom,
                  maxZoom: AnbarMapConfig.maxZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.aqar',
                    maxNativeZoom: 19,
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: position,
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        child: const _PropertyMarker(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // الشريط العلوي.
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: 0.16,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // عنوان الشاشة.
                                Expanded(
                                  child: Text(
                                    propertyTitle?.trim().isNotEmpty == true
                                        ? propertyTitle!
                                        : 'موقع العقار',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // فاصل.
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                ),

                                const SizedBox(width: 6),

                                // زر الاتجاهات.
                                _TopMapAction(
                                  icon: Icons.navigation_rounded,
                                  tooltip: 'الاتجاهات',
                                  onTap: () {
                                    _showLocationActions(
                                      context,
                                      location,
                                      propertyTitle,
                                    );
                                  },
                                ),

                                const SizedBox(width: 2),

                                // زر المشاركة.
                                _TopMapAction(
                                  icon: Icons.share_rounded,
                                  tooltip: 'مشاركة الموقع',
                                  onTap: () {
                                    _sharePropertyLocation(
                                      location,
                                      propertyTitle,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _BackButton(
                          onTap: () {
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // بيانات الموقع في الأسفل.
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 14,
              child: LocationSummaryCard(
                location: location,
                isInsideAnbar: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationActions(
    BuildContext context,
    PropertyLocation location,
    String? propertyTitle,
  ) {
    final latitude = location.latitude;
    final longitude = location.longitude;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'الاتجاهات والمشاركة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'اختر طريقة فتح موقع العقار أو مشاركته',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LocationActionTile(
                    icon: Icons.map_rounded,
                    title: 'فتح في Google Maps',
                    subtitle: 'عرض الموقع وبدء الاتجاهات',
                    onTap: () async {
                      Navigator.pop(sheetContext);

                      await _openGoogleMaps(
                        latitude,
                        longitude,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _LocationActionTile(
                    icon: Icons.navigation_rounded,
                    title: 'فتح في Waze',
                    subtitle: 'بدء الملاحة إلى موقع العقار',
                    onTap: () async {
                      Navigator.pop(sheetContext);

                      await _openWaze(
                        latitude,
                        longitude,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGoogleMaps(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=$latitude,$longitude',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openWaze(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse(
      'https://waze.com/ul'
      '?ll=$latitude,$longitude'
      '&navigate=yes',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _sharePropertyLocation(
    PropertyLocation location,
    String? propertyTitle,
  ) async {
    final latitude = location.latitude;
    final longitude = location.longitude;

    final title = propertyTitle?.trim().isNotEmpty == true
        ? propertyTitle!.trim()
        : 'موقع العقار';

    final city = location.city.trim();
    final district = location.district.trim();
    final landmark = location.landmark.trim();

    final address = [
      city,
      district,
    ].where((value) => value.isNotEmpty).join(' - ');

    final mapUrl = 'https://www.google.com/maps/search/?api=1'
        '&query=$latitude,$longitude';

    final buffer = StringBuffer()..writeln('📍 $title');

    if (address.isNotEmpty) {
      buffer.writeln(address);
    }

    if (landmark.isNotEmpty) {
      buffer.writeln('أقرب نقطة دالة: $landmark');
    }

    buffer
      ..writeln()
      ..writeln('عرض الموقع على الخريطة:')
      ..write(mapUrl);

    await Share.share(
      buffer.toString(),
    );
  }
}

class _TopMapAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopMapAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: const Color(0xFFD4AF37),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LocationActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.13,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.06,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFD4AF37),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF64748B),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyMarker extends StatelessWidget {
  const _PropertyMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PropertyLocationScreen._card,
        shape: BoxShape.circle,
        border: Border.all(
          color: PropertyLocationScreen._gold,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.30,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: PropertyLocationScreen._gold.withValues(
              alpha: 0.20,
            ),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          width: 50,
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return const Icon(
              Icons.location_on_rounded,
              color: PropertyLocationScreen._gold,
              size: 30,
            );
          },
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.06,
              ),
            ),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFD4AF37),
            size: 19,
          ),
        ),
      ),
    );
  }
}
