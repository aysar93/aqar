import 'package:flutter/material.dart';

import '../../data/anbar_locations.dart';
import '../../features/property_map/models/property_location.dart';
import '../../features/property_map/screens/location_picker_screen.dart';
import '../../models/add_property_data.dart';

class Step4Location extends StatefulWidget {
  final AddPropertyData property;
  final VoidCallback? onChanged;

  const Step4Location({
    super.key,
    required this.property,
    this.onChanged,
  });

  @override
  State<Step4Location> createState() => _Step4LocationState();
}

class _Step4LocationState extends State<Step4Location> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _background = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _secondary = Color(0xFF94A3B8);
  static const Color _success = Color(0xFF22C55E);
  static const String _otherOption = 'أخرى';
  static const List<String> _availableFeatures = [
    'حديقة',
    'مسبح',
    'مصعد',
    'كراج',
    'كاميرات مراقبة',
    'مولدة',
    'بئر ماء',
    'سياج',
    'مكيفات',
    'طاقة شمسية',
  ];

  late final TextEditingController _landmarkController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _customCityController;
  late final TextEditingController _customAreaController;

  bool _customCity = false;
  bool _customArea = false;

  @override
  void initState() {
    super.initState();

    _landmarkController = TextEditingController(
      text: widget.property.landmark,
    );

    _descriptionController = TextEditingController(
      text: widget.property.description,
    );

    final normalizedCity = AnbarLocations.normalizeCity(
      widget.property.city,
    );

    _customCity =
        widget.property.city.trim().isNotEmpty && normalizedCity == null;

    _customCityController = TextEditingController(
      text: _customCity ? widget.property.city.trim() : '',
    );

    final normalizedArea = normalizedCity == null
        ? ''
        : AnbarLocations.normalizeArea(
            city: normalizedCity,
            area: widget.property.district,
          );

    final knownAreas = AnbarLocations.areasForCity(
      normalizedCity,
    );

    _customArea = widget.property.district.trim().isNotEmpty &&
        (_customCity ||
            normalizedArea.isEmpty ||
            !knownAreas.contains(normalizedArea));

    _customAreaController = TextEditingController(
      text: _customArea ? widget.property.district.trim() : '',
    );
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    _descriptionController.dispose();
    _customCityController.dispose();
    _customAreaController.dispose();
    super.dispose();
  }

  String? get _knownCity {
    return AnbarLocations.normalizeCity(
      widget.property.city,
    );
  }

  String? get _selectedCityOption {
    if (_customCity) {
      return _otherOption;
    }
    return _knownCity;
  }

  String? get _effectiveCity {
    final value = widget.property.city.trim();
    return value.isEmpty ? null : value;
  }

  List<String> get _availableAreas {
    if (_customCity) {
      return const <String>[];
    }
    return AnbarLocations.areasForCity(_knownCity);
  }

  String? get _selectedAreaOption {
    if (_customArea) {
      return _otherOption;
    }

    final city = _knownCity;
    if (city == null) {
      return null;
    }

    final area = AnbarLocations.normalizeArea(
      city: city,
      area: widget.property.district,
    );

    if (area.isEmpty || !_availableAreas.contains(area)) {
      return null;
    }
    return area;
  }

  String? get _effectiveArea {
    final value = widget.property.district.trim();
    return value.isEmpty ? null : value;
  }

  bool get _hasMapLocation {
    return widget.property.hasMapLocation;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        18,
        16,
        18,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.location_on_rounded,
            title: 'موقع العقار',
            subtitle: 'حدد المدينة والمنطقة ثم اختر الموقع الدقيق على الخريطة',
          ),
          const SizedBox(height: 18),
          _buildCityField(),
          if (_customCity) ...[
            const SizedBox(height: 12),
            _buildCustomCityField(),
          ],
          const SizedBox(height: 12),
          _buildAreaField(),
          if (_customArea || _customCity) ...[
            const SizedBox(height: 12),
            _buildCustomAreaField(),
          ],
          const SizedBox(height: 16),
          _buildMapLocationCard(),
          const SizedBox(height: 16),
          _buildLandmarkField(),
          const SizedBox(height: 28),
          _buildDivider(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            icon: Icons.description_rounded,
            title: 'وصف العقار',
            subtitle: 'أضف وصفًا واضحًا يساعد الباحث على معرفة تفاصيل العقار',
          ),
          const SizedBox(height: 16),
          _buildDescriptionField(),
          const SizedBox(height: 28),
          _buildDivider(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'مميزات العقار',
            subtitle: 'اختر المميزات المتوفرة في العقار',
          ),
          const SizedBox(height: 16),
          _buildFeatures(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _gold.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(
            icon,
            color: _gold,
            size: 24,
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
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCityField() {
    final items = <String>{
      ...AnbarLocations.cities,
      _otherOption,
    }.toList();

    return DropdownButtonFormField<String>(
      key: ValueKey(
        'city_${_selectedCityOption ?? 'none'}',
      ),
      initialValue: _selectedCityOption,
      isExpanded: true,
      dropdownColor: _card,
      iconEnabledColor: _gold,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: 'المدينة / القضاء',
        icon: Icons.location_city_rounded,
      ),
      hint: const Text(
        'اختر المدينة',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
        ),
      ),
      items: items
          .map(
            (city) => DropdownMenuItem<String>(
              value: city,
              child: Text(
                city,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (city) {
        if (city == null) {
          return;
        }

        setState(() {
          if (city == _otherOption) {
            _customCity = true;
            _customArea = true;

            widget.property.city = _customCityController.text.trim();

            widget.property.district = _customAreaController.text.trim();

            _clearCoordinates();
          } else {
            final cityChanged = widget.property.city != city || _customCity;

            _customCity = false;
            _customArea = false;

            _customCityController.clear();
            _customAreaController.clear();

            widget.property.city = city;

            if (cityChanged) {
              widget.property.district = '';
              _clearCoordinates();
            }
          }
        });

        widget.onChanged?.call();
      },
    );
  }

  Widget _buildCustomCityField() {
    return TextFormField(
      controller: _customCityController,
      textInputAction: TextInputAction.next,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: 'اسم المدينة / القضاء',
        icon: Icons.edit_location_alt_rounded,
        hint: 'اكتب اسم المدينة أو القضاء',
      ),
      onChanged: (value) {
        final next = value.trim();

        setState(() {
          if (widget.property.city != next) {
            widget.property.city = next;
            _clearCoordinates();
          }
        });

        widget.onChanged?.call();
      },
    );
  }

  Widget _buildAreaField() {
    final city = _effectiveCity;

    if (_customCity) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.holiday_village_rounded,
              color: _gold,
              size: 22,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'المنطقة / الحي — إدخال يدوي',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final items = <String>{
      ..._availableAreas,
      _otherOption,
    }.toList();

    return DropdownButtonFormField<String>(
      key: ValueKey(
        'area_${_knownCity ?? 'none'}_${_selectedAreaOption ?? 'none'}',
      ),
      initialValue: _selectedAreaOption,
      isExpanded: true,
      dropdownColor: _card,
      iconEnabledColor: _gold,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: 'المنطقة / الحي',
        icon: Icons.holiday_village_rounded,
      ),
      hint: Text(
        city == null ? 'اختر المدينة أولًا' : 'اختر المنطقة',
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
        ),
      ),
      items: city == null
          ? const <DropdownMenuItem<String>>[]
          : items
              .map(
                (area) => DropdownMenuItem<String>(
                  value: area,
                  child: Text(
                    area,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
      onChanged: city == null
          ? null
          : (area) {
              if (area == null) return;

              setState(() {
                if (area == _otherOption) {
                  _customArea = true;
                  widget.property.district = _customAreaController.text.trim();
                  _clearCoordinates();
                } else {
                  final areaChanged =
                      widget.property.district != area || _customArea;

                  _customArea = false;
                  _customAreaController.clear();
                  widget.property.district = area;

                  if (areaChanged) {
                    _clearCoordinates();
                  }
                }
              });

              widget.onChanged?.call();
            },
    );
  }

  Widget _buildCustomAreaField() {
    return TextFormField(
      controller: _customAreaController,
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: 'اسم المنطقة / الحي',
        icon: Icons.edit_road_rounded,
        hint: 'اكتب اسم المنطقة أو الحي',
      ),
      onChanged: (value) {
        final next = value.trim();

        setState(() {
          if (widget.property.district != next) {
            widget.property.district = next;
            _clearCoordinates();
          }
        });

        widget.onChanged?.call();
      },
    );
  }

  Widget _buildMapLocationCard() {
    final city = _effectiveCity;
    final area = _effectiveArea;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hasMapLocation
              ? _success.withValues(alpha: 0.35)
              : _gold.withValues(alpha: 0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.12,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _hasMapLocation
                      ? _success.withValues(
                          alpha: 0.12,
                        )
                      : _gold.withValues(
                          alpha: 0.12,
                        ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _hasMapLocation
                      ? Icons.check_circle_rounded
                      : Icons.map_rounded,
                  color: _hasMapLocation ? _success : _gold,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasMapLocation
                          ? 'تم تحديد الموقع'
                          : 'الموقع على الخريطة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mapLocationSubtitle(
                        city: city,
                        area: area,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _secondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasMapLocation) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CoordinateItem(
                      label: 'خط العرض',
                      value: widget.property.latitude!,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withValues(
                      alpha: 0.08,
                    ),
                  ),
                  Expanded(
                    child: _CoordinateItem(
                      label: 'خط الطول',
                      value: widget.property.longitude!,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed:
                  city != null && area != null ? _openLocationPicker : null,
              style: FilledButton.styleFrom(
                backgroundColor: _hasMapLocation ? _background : _gold,
                foregroundColor: _hasMapLocation ? _gold : _background,
                disabledBackgroundColor: const Color(0xFF334155),
                disabledForegroundColor: const Color(0xFF64748B),
                side: _hasMapLocation
                    ? const BorderSide(
                        color: _gold,
                      )
                    : BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: Icon(
                _hasMapLocation
                    ? Icons.edit_location_alt_rounded
                    : Icons.add_location_alt_rounded,
                size: 20,
              ),
              label: Text(
                _hasMapLocation
                    ? 'تعديل الموقع على الخريطة'
                    : 'تحديد الموقع على الخريطة',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (city == null || area == null) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFF59E0B),
                  size: 16,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'اختر المدينة والمنطقة أولًا لتحديد الموقع الدقيق',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLandmarkField() {
    return TextFormField(
      controller: _landmarkController,
      maxLength: 100,
      onChanged: (value) {
        widget.property.landmark = value.trim();
        widget.onChanged?.call();
      },
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      decoration: _inputDecoration(
        label: 'أقرب نقطة دالة (اختياري)',
        icon: Icons.near_me_rounded,
        hint: 'مثال: قرب مستشفى الرمادي',
      ).copyWith(
        counterText: '',
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      minLines: 4,
      maxLines: 7,
      maxLength: 1000,
      onChanged: (value) {
        widget.property.description = value.trim();
        widget.onChanged?.call();
      },
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        height: 1.6,
      ),
      decoration: _inputDecoration(
        label: 'وصف العقار',
        icon: Icons.notes_rounded,
        hint: 'اكتب أهم تفاصيل العقار وموقعه وحالته',
      ),
    );
  }

  Widget _buildFeatures() {
    const features = _availableFeatures;

    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 9,
      children: features.map((feature) {
        final selected = widget.property.features.contains(feature);

        return FilterChip(
          selected: selected,
          showCheckmark: false,
          avatar: selected
              ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: _background,
                )
              : null,
          label: Text(feature),
          labelStyle: TextStyle(
            color: selected ? _background : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          backgroundColor: _card,
          selectedColor: _gold,
          side: BorderSide(
            color: selected
                ? _gold
                : Colors.white.withValues(
                    alpha: 0.07,
                  ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          onSelected: (_) {
            setState(() {
              if (selected) {
                widget.property.features.remove(feature);
              } else {
                widget.property.features.add(feature);
              }
            });

            widget.onChanged?.call();
          },
        );
      }).toList(growable: false),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: _secondary,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: _gold,
        size: 21,
      ),
      filled: true,
      fillColor: _card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.white.withValues(
            alpha: 0.06,
          ),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: _gold,
          width: 1.2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.white.withValues(
            alpha: 0.03,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: double.infinity,
      height: 1,
      color: Colors.white.withValues(
        alpha: 0.06,
      ),
    );
  }

  String _mapLocationSubtitle({
    required String? city,
    required String? area,
  }) {
    if (_hasMapLocation) {
      final parts = <String>[
        if (city != null) city,
        if (area != null) area,
      ];

      if (parts.isNotEmpty) {
        return parts.join(' - ');
      }

      return 'تم حفظ الإحداثيات الجغرافية للعقار';
    }

    if (city == null || area == null) {
      return 'اختر المدينة والمنطقة أولًا';
    }

    return 'حدد النقطة الدقيقة للعقار داخل $city - $area';
  }

  Future<void> _openLocationPicker() async {
    final city = _effectiveCity;
    final area = _effectiveArea;

    if (city == null || area == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    final initialLocation = PropertyLocation(
      latitude: widget.property.latitude ?? 0,
      longitude: widget.property.longitude ?? 0,
      city: city,
      district: area,
      landmark: widget.property.landmark,
    );

    final result = await Navigator.of(context).push<PropertyLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: initialLocation,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      widget.property.city = result.city;
      widget.property.district = result.district;
      widget.property.landmark = result.landmark;

      widget.property.latitude = result.latitude;
      widget.property.longitude = result.longitude;

      _landmarkController.text = result.landmark;
    });

    widget.onChanged?.call();
  }

  void _clearCoordinates() {
    widget.property.latitude = null;
    widget.property.longitude = null;
  }
}

class _CoordinateItem extends StatelessWidget {
  final String label;
  final double value;

  const _CoordinateItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.toStringAsFixed(6),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
