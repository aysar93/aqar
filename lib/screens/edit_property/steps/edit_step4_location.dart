import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/edit_property_data.dart';
import '../../../features/property_map/models/property_location.dart';
import '../../../features/property_map/screens/location_picker_screen.dart';

class EditStep4Location extends StatefulWidget {
  final EditPropertyData property;
  final VoidCallback onChanged;

  const EditStep4Location({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<EditStep4Location> createState() => _EditStep4LocationState();
}

class _EditStep4LocationState extends State<EditStep4Location> {
  late final TextEditingController cityController;
  late final TextEditingController districtController;
  late final TextEditingController landmarkController;
  late final TextEditingController latitudeController;
  late final TextEditingController longitudeController;

  @override
  void initState() {
    super.initState();

    cityController = TextEditingController(
      text: widget.property.city,
    );

    districtController = TextEditingController(
      text: widget.property.district,
    );

    landmarkController = TextEditingController(
      text: widget.property.landmark,
    );

    latitudeController = TextEditingController(
      text: _coordinateText(
        widget.property.latitude,
      ),
    );

    longitudeController = TextEditingController(
      text: _coordinateText(
        widget.property.longitude,
      ),
    );
  }

  String _coordinateText(double? value) {
    if (value == null || value == 0) {
      return '';
    }

    return value.toString();
  }

  @override
  void dispose() {
    cityController.dispose();
    districtController.dispose();
    landmarkController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  void _updateCoordinates() {
    widget.property.latitude = double.tryParse(
      latitudeController.text.trim(),
    );

    widget.property.longitude = double.tryParse(
      longitudeController.text.trim(),
    );

    widget.onChanged();

    setState(() {});
  }

// مسح الموقع القديم عند تغيير المدينة أو المنطقة
  void _clearCoordinates() {
    widget.property.latitude = null;
    widget.property.longitude = null;

    latitudeController.clear();
    longitudeController.clear();
  }

  Future<void> _openLocationPicker() async {
    final city = widget.property.city.trim();
    final district = widget.property.district.trim();

    if (city.isEmpty || district.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل المدينة والمنطقة أولاً',
            textAlign: TextAlign.right,
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final initialLocation = PropertyLocation(
      latitude: widget.property.latitude ?? 0,
      longitude: widget.property.longitude ?? 0,
      city: city,
      district: district,
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

      cityController.text = result.city;
      districtController.text = result.district;
      landmarkController.text = result.landmark;

      latitudeController.text = result.latitude.toString();

      longitudeController.text = result.longitude.toString();
    });

    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'موقع العقار',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'راجع معلومات موقع العقار وعدّلها عند الحاجة',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 28),
        _textField(
          controller: cityController,
          label: 'المدينة',
          icon: Icons.location_city_rounded,
          onChanged: (value) {
            final newValue = value.trim();

            if (widget.property.city != newValue) {
              setState(() {
                widget.property.city = newValue;
                _clearCoordinates();
              });

              widget.onChanged();
            }
          },
        ),
        const SizedBox(height: 15),
        _textField(
          controller: districtController,
          label: 'المنطقة',
          icon: Icons.map_outlined,
          onChanged: (value) {
            final newValue = value.trim();

            if (widget.property.district != newValue) {
              setState(() {
                widget.property.district = newValue;
                _clearCoordinates();
              });

              widget.onChanged();
            }
          },
        ),
        const SizedBox(height: 15),
        _textField(
          controller: landmarkController,
          label: 'أقرب معلم',
          icon: Icons.place_outlined,
          onChanged: (value) {
            widget.property.landmark = value.trim();
            widget.onChanged();
          },
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xff1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.property.hasMapLocation
                  ? const Color(0xffD4AF37).withValues(alpha: .45)
                  : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xffD4AF37),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'إحداثيات الموقع',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.property.hasMapLocation)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xffD4AF37),
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.property.hasMapLocation
                    ? 'يوجد موقع محفوظ لهذا العقار'
                    : 'لا يوجد موقع محفوظ لهذا العقار',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _coordinateField(
                      controller: longitudeController,
                      label: 'خط الطول',
                      onChanged: (_) {
                        _updateCoordinates();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _coordinateField(
                      controller: latitudeController,
                      label: 'خط العرض',
                      onChanged: (_) {
                        _updateCoordinates();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _openLocationPicker,
            icon: Icon(
              widget.property.hasMapLocation
                  ? Icons.edit_location_alt_rounded
                  : Icons.add_location_alt_rounded,
            ),
            label: Text(
              widget.property.hasMapLocation
                  ? 'تعديل الموقع على الخريطة'
                  : 'تحديد الموقع على الخريطة',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.property.hasMapLocation
                  ? const Color(0xff1E293B)
                  : const Color(0xffD4AF37),
              foregroundColor: widget.property.hasMapLocation
                  ? const Color(0xffD4AF37)
                  : Colors.black,
              side: widget.property.hasMapLocation
                  ? const BorderSide(
                      color: Color(0xffD4AF37),
                    )
                  : BorderSide.none,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white60,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xffD4AF37),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _coordinateField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'^-?\d*\.?\d*'),
        ),
      ],
      onChanged: onChanged,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
        ),
        filled: true,
        fillColor: const Color(0xff0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
