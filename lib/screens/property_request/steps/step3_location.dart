import 'package:flutter/material.dart';

import '../../../data/anbar_locations.dart';
import '../../../models/property_request_data.dart';
import '../widgets/request_glass_card.dart';

class Step3Location extends StatefulWidget {
  final PropertyRequestData request;
  final VoidCallback onChanged;

  const Step3Location({
    super.key,
    required this.request,
    required this.onChanged,
  });

  @override
  State<Step3Location> createState() => _Step3LocationState();
}

class _Step3LocationState extends State<Step3Location> {
  static const Color _gold = Color(0xffD4AF37);
  static const Color _card = Color(0xff1E293B);

  late final TextEditingController _landmarkController;

  @override
  void initState() {
    super.initState();

    _landmarkController = TextEditingController(
      text: widget.request.landmark,
    );
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    super.dispose();
  }

  String? get _selectedCity {
    final normalized = AnbarLocations.normalizeCity(
      widget.request.city,
    );

    if (normalized != null) {
      return normalized;
    }

    if (AnbarLocations.normalizeText(widget.request.city) ==
        AnbarLocations.normalizeText(AnbarLocations.other)) {
      return AnbarLocations.other;
    }

    return null;
  }

  String? get _selectedDistrict {
    final city = _selectedCity;

    if (city == null) {
      return null;
    }

    final district = AnbarLocations.normalizeArea(
      city: city,
      area: widget.request.district,
    );

    if (district.isEmpty) {
      return null;
    }

    final availableAreas = AnbarLocations.areasForCity(city);

    final exists = availableAreas.any(
      (item) =>
          AnbarLocations.normalizeText(item) ==
          AnbarLocations.normalizeText(district),
    );

    return exists ? district : null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCity = _selectedCity;
    final selectedDistrict = _selectedDistrict;

    final areas = selectedCity == null
        ? const <String>[]
        : AnbarLocations.areasForCity(selectedCity);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        const Text(
          "أين تبحث عن العقار؟",
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "حدد المدينة والمنطقة التي ترغب بالعثور على العقار فيها",
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        RequestGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.location_city_rounded,
                title: "المدينة",
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  "request_city_${selectedCity ?? 'none'}",
                ),
                initialValue: selectedCity,
                isExpanded: true,
                dropdownColor: _card,
                iconEnabledColor: _gold,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: _inputDecoration(
                  label: "اختر المدينة",
                  icon: Icons.location_city_rounded,
                ),
                items: AnbarLocations.cities.map((city) {
                  return DropdownMenuItem<String>(
                    value: city,
                    child: Text(
                      city,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    widget.request.city = value;

                    // عند تغيير المدينة نحذف المنطقة السابقة،
                    // لأنها قد لا تنتمي إلى المدينة الجديدة.
                    widget.request.district = "";
                  });

                  widget.onChanged();
                },
              ),
              const SizedBox(height: 18),
              const _SectionTitle(
                icon: Icons.place_rounded,
                title: "المنطقة",
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  "request_district_"
                  "${selectedCity ?? 'none'}_"
                  "${selectedDistrict ?? 'none'}",
                ),
                initialValue: selectedDistrict,
                isExpanded: true,
                dropdownColor: _card,
                iconEnabledColor: _gold,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: _inputDecoration(
                  label: selectedCity == null
                      ? "اختر المدينة أولًا"
                      : "اختر المنطقة",
                  icon: Icons.place_rounded,
                ),
                items: areas.map((area) {
                  return DropdownMenuItem<String>(
                    value: area,
                    child: Text(
                      area,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(growable: false),
                onChanged: selectedCity == null
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          widget.request.district = value;
                        });

                        widget.onChanged();
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RequestGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.near_me_rounded,
                title: "نقطة دالة",
              ),
              const SizedBox(height: 6),
              const Text(
                "اختياري — يمكنك كتابة موقع تقريبي أو نقطة معروفة",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _landmarkController,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                onChanged: (value) {
                  widget.request.landmark = value.trim();
                  widget.onChanged();
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: _inputDecoration(
                  label: "أقرب نقطة دالة",
                  icon: Icons.near_me_rounded,
                  hint: "مثال: قرب مستشفى الرمادي",
                ).copyWith(
                  counterText: "",
                ),
              ),
            ],
          ),
        ),
        if (selectedCity != null && selectedDistrict != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _gold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: _gold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "الموقع المطلوب: "
                    "$selectedCity - $selectedDistrict",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
        color: Colors.white60,
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
      fillColor: const Color(0xff0F172A).withValues(
        alpha: 0.55,
      ),
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
          color: Colors.white.withValues(alpha: 0.06),
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
          color: Colors.white.withValues(alpha: 0.03),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  static const Color _gold = Color(0xffD4AF37);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: _gold,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
