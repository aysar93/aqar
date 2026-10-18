import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/anbar_locations.dart';
import '../data/anbar_map_coordinates.dart';
import '../models/property_location.dart';

class LocationPickerScreen extends StatefulWidget {
  final PropertyLocation? initialLocation;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();

  late LatLng _selectedPosition;

  double _currentZoom = AnbarMapCoordinates.cityZoom;
  bool _isMoving = false;
  bool _isLocating = false;

  String? _selectedCity;
  String? _selectedArea;

  @override
  void initState() {
    super.initState();

    _initializeLocationSelections();
    _initializeMapPosition();
  }

  void _initializeLocationSelections() {
    final initialCity = widget.initialLocation?.city;
    final initialArea = widget.initialLocation?.district;

    final normalizedCity = AnbarLocations.normalizeCity(initialCity);

    if (normalizedCity != null) {
      _selectedCity = normalizedCity;

      final normalizedArea = AnbarLocations.normalizeArea(
        city: normalizedCity,
        area: initialArea,
      );

      if (AnbarLocations.containsArea(
        city: normalizedCity,
        area: normalizedArea,
      )) {
        _selectedArea = normalizedArea;
      }
    }

    _selectedCity ??= 'الرمادي';

    final areas = AnbarLocations.areasForCity(_selectedCity);

    if (_selectedArea == null && areas.isNotEmpty) {
      _selectedArea = areas.first;
    }
  }

  void _initializeMapPosition() {
    final latitude = widget.initialLocation?.latitude ?? 0;

    final longitude = widget.initialLocation?.longitude ?? 0;

    final hasCoordinates = latitude != 0 && longitude != 0;

    if (hasCoordinates) {
      _selectedPosition = LatLng(latitude, longitude);

      _currentZoom = AnbarMapCoordinates.areaZoom;

      return;
    }

    final center = AnbarMapCoordinates.locationCenter(
          city: _selectedCity,
          area: _selectedArea,
        ) ??
        AnbarMapCoordinates.defaultCenter;

    _selectedPosition = center;

    _currentZoom = AnbarMapCoordinates.zoomFor(
      city: _selectedCity,
      area: _selectedArea,
    );
  }

  List<String> get _availableAreas {
    return AnbarLocations.areasForCity(
      _selectedCity,
    );
  }

  void _moveMap(
    LatLng center,
    double zoom,
  ) {
    _selectedPosition = center;
    _currentZoom = zoom;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _mapController.move(
        center,
        zoom,
      );
    });
  }

  void _selectCity(String? city) {
    if (city == null || city == _selectedCity) {
      return;
    }

    final areas = AnbarLocations.areasForCity(city);

    final newArea = areas.isNotEmpty ? areas.first : null;

    setState(() {
      _selectedCity = city;
      _selectedArea = newArea;
      _isMoving = false;
    });

    // عند "أخرى" لا ننقل الخريطة إلى مكان وهمي.
    if (city == AnbarLocations.other) {
      return;
    }

    final center = AnbarMapCoordinates.cityCenter(city);

    if (center == null) {
      return;
    }

    _moveMap(
      center,
      AnbarMapCoordinates.cityZoom,
    );
  }

  void _selectArea(String? area) {
    if (area == null || area == _selectedArea) {
      return;
    }

    setState(() {
      _selectedArea = area;
      _isMoving = false;
    });

    // إذا اختار المستخدم "أخرى"، نبقي الخريطة
    // في موقعها الحالي ليحدد المكان يدويًا.
    if (area == AnbarLocations.other) {
      return;
    }

    final exactCenter = AnbarMapCoordinates.exactAreaCenter(
      city: _selectedCity,
      area: area,
    );

    if (exactCenter != null) {
      _moveMap(
        exactCenter,
        AnbarMapCoordinates.areaZoom,
      );

      return;
    }

    // المنطقة موجودة في القائمة لكن ليس لدينا
    // إحداثيات دقيقة لها، فنستخدم مركز المدينة.
    final cityCenter = AnbarMapCoordinates.cityCenter(
      _selectedCity,
    );

    if (cityCenter != null) {
      _moveMap(
        cityCenter,
        AnbarMapCoordinates.cityZoom,
      );
    }
  }

  void _onMapPositionChanged(
    MapCamera camera,
    bool hasGesture,
  ) {
    if (!hasGesture) {
      return;
    }

    _selectedPosition = camera.center;
    _currentZoom = camera.zoom;

    if (!_isMoving) {
      setState(() {
        _isMoving = true;
      });
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd) {
      _selectedPosition = event.camera.center;

      _currentZoom = event.camera.zoom;

      if (mounted) {
        setState(() {
          _isMoving = false;
        });
      }
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_isLocating) {
      return;
    }

    setState(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يرجى تشغيل خدمة الموقع GPS أولاً',
            ),
          ),
        );

        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم يتم منح صلاحية الوصول إلى الموقع',
            ),
          ),
        );

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'صلاحية الموقع مرفوضة بشكل دائم. يمكنك تفعيلها من إعدادات التطبيق',
            ),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: () {
                Geolocator.openAppSettings();
              },
            ),
          ),
        );

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _selectedPosition = location;
        _currentZoom = 16.0;
        _isMoving = false;
      });

      _mapController.move(
        location,
        16.0,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تحديد موقعك الحالي. حاول مرة أخرى',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _confirmLocation() {
    final city = _selectedCity?.trim() ?? '';
    final area = _selectedArea?.trim() ?? '';

    if (city.isEmpty || area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى اختيار المدينة والمنطقة أولاً',
          ),
        ),
      );

      return;
    }

    final result = PropertyLocation(
      governorate: AnbarLocations.governorate,
      city: city,
      district: area,
      landmark: widget.initialLocation?.landmark ?? '',
      latitude: _selectedPosition.latitude,
      longitude: _selectedPosition.longitude,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final areas = _availableAreas;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildLocationSelectors(
              areas,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedPosition,
                        initialZoom: _currentZoom,
                        minZoom: 5.0,
                        maxZoom: 18.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.drag |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom,
                        ),
                        onPositionChanged: _onMapPositionChanged,
                        onMapEvent: _onMapEvent,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.aqar',
                          maxNativeZoom: 18,
                          maxZoom: 18,
                        ),
                      ],
                    ),
                  ),
                  _buildCenterMarker(),
                  _buildMapActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterMarker() {
    return Center(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _isMoving ? -10 : 0,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // جسم المؤشر
              Container(
                width: 62,
                height: 62,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
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
                        color: Color(0xFFD4AF37),
                        size: 34,
                      );
                    },
                  ),
                ),
              ),

              // سنّ المؤشر
              Transform.translate(
                offset: const Offset(0, -3),
                child: const CustomPaint(
                  size: Size(20, 15),
                  painter: _MarkerTipPainter(),
                ),
              ),

              // ظل نقطة الموقع
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _isMoving ? 18 : 12,
                height: _isMoving ? 6 : 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: _isMoving ? 0.18 : 0.30,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapActions() {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              elevation: 6,
              child: InkWell(
                onTap: _isLocating ? null : _goToCurrentLocation,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  child: _isLocating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFFD4AF37),
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          color: Color(0xFFD4AF37),
                          size: 25,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _confirmLocation,
              icon: const Icon(
                Icons.check_circle_rounded,
              ),
              label: const Text(
                'تأكيد موقع العقار',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(
                0xFF1E293B,
              ),
              borderRadius: BorderRadius.circular(
                14,
              ),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(
                  0xFFD4AF37,
                ),
                size: 20,
              ),
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحديد موقع العقار',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'حرّك الخريطة حتى يصبح المؤشر فوق العقار',
                  style: TextStyle(
                    color: Color(
                      0xFF94A3B8,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSelectors(
    List<String> areas,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        4,
        14,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: _LocationDropdown(
              label: 'المدينة / القضاء',
              value: _selectedCity,
              items: AnbarLocations.cities,
              onChanged: _selectCity,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: _LocationDropdown(
              label: 'المنطقة / الحي',
              value: _selectedArea,
              items: areas,
              onChanged: _selectArea,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkerTipPainter extends CustomPainter {
  const _MarkerTipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _MarkerTipPainter oldDelegate,
  ) {
    return false;
  }
}

class _LocationDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final validValue = value != null && items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            right: 8,
            bottom: 5,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(
                0xFF94A3B8,
              ),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            color: const Color(
              0xFF1E293B,
            ),
            borderRadius: BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.08,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              isExpanded: true,
              dropdownColor: const Color(
                0xFF1E293B,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(
                  0xFFD4AF37,
                ),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              hint: const Text(
                'اختر',
                style: TextStyle(
                  color: Color(
                    0xFF94A3B8,
                  ),
                ),
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: items.isEmpty ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
