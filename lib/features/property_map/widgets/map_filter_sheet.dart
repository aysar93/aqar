import 'package:flutter/material.dart';

import '../../../data/anbar_locations.dart';
import '../models/map_filter.dart';
import '../utils/map_validators.dart';

class MapFilterSheet extends StatefulWidget {
  final MapFilter initialFilter;

  const MapFilterSheet({
    super.key,
    required this.initialFilter,
  });

  static Future<MapFilter?> show(
    BuildContext context, {
    required MapFilter initialFilter,
  }) {
    return showModalBottomSheet<MapFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapFilterSheet(
        initialFilter: initialFilter,
      ),
    );
  }

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  static const Color _gold = Color(0xFFC5A16B);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _card => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _onSurface => _isDark ? Colors.white : const Color(0xFF0F172A);

  late String? _city;
  late String? _district;
  late String? _adType;
  late bool _featuredOnly;

  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  String? _rangeError;

  @override
  void initState() {
    super.initState();

    _city = widget.initialFilter.city;
    _district = widget.initialFilter.district;
    _adType = widget.initialFilter.adType;
    _featuredOnly = widget.initialFilter.featuredOnly;

    _minPriceController = TextEditingController(
      text: _numberText(
        widget.initialFilter.minPrice,
      ),
    );

    _maxPriceController = TextEditingController(
      text: _numberText(
        widget.initialFilter.maxPrice,
      ),
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final districts = AnbarLocations.areasForCity(_city);

    return Container(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: _onSurface.withValues(
                alpha: 0.18,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'فلترة العقارات',
                    style: TextStyle(
                      color: _onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text(
                    'إعادة تعيين',
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                4,
                20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    title: 'نوع الإعلان',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SelectionButton(
                          label: 'الكل',
                          selected: _adType == null,
                          onTap: () {
                            setState(() {
                              _adType = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SelectionButton(
                          label: 'للبيع',
                          selected: _adType == 'للبيع',
                          onTap: () {
                            setState(() {
                              _adType = 'للبيع';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SelectionButton(
                          label: 'للإيجار',
                          selected: _adType == 'للإيجار',
                          onTap: () {
                            setState(() {
                              _adType = 'للإيجار';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    title: 'الموقع',
                  ),
                  const SizedBox(height: 10),
                  _DropdownField(
                    label: 'المدينة',
                    value: _validCityValue(),
                    items: AnbarLocations.cities,
                    onChanged: (value) {
                      setState(() {
                        _city = value;
                        _district = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _DropdownField(
                    label: 'المنطقة أو الحي',
                    value: _validDistrictValue(
                      districts,
                    ),
                    items: districts,
                    enabled: _city != null,
                    onChanged: (value) {
                      setState(() {
                        _district = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    title: 'السعر',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceField(
                          controller: _minPriceController,
                          label: 'من',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PriceField(
                          controller: _maxPriceController,
                          label: 'إلى',
                        ),
                      ),
                    ],
                  ),
                  if (_rangeError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _rangeError!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _onSurface.withValues(
                          alpha: 0.06,
                        ),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'العقارات المميزة فقط',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'إظهار الإعلانات المميزة فقط',
                          style: TextStyle(
                            color: _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                        value: _featuredOnly,
                        activeThumbColor: _gold,
                        onChanged: (value) {
                          setState(() {
                            _featuredOnly = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: _card,
              border: Border(
                top: BorderSide(
                  color: _onSurface.withValues(
                    alpha: 0.06,
                  ),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'عرض النتائج',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validCityValue() {
    if (_city == null) {
      return null;
    }

    return AnbarLocations.cities.contains(_city) ? _city : null;
  }

  String? _validDistrictValue(
    List<String> districts,
  ) {
    if (_district == null) {
      return null;
    }

    return districts.contains(_district) ? _district : null;
  }

  void _apply() {
    final minPrice = _parseNumber(
      _minPriceController.text,
    );

    final maxPrice = _parseNumber(
      _maxPriceController.text,
    );

    if (!MapValidators.isValidPriceRange(
      minPrice: minPrice,
      maxPrice: maxPrice,
    )) {
      setState(() {
        _rangeError = 'تأكد أن الحد الأدنى للسعر لا يتجاوز الحد الأعلى.';
      });
      return;
    }

    setState(() {
      _rangeError = null;
    });

    var filter = widget.initialFilter.copyWith(
      featuredOnly: _featuredOnly,
    );

    filter = _city == null
        ? filter.copyWith(
            clearCity: true,
            clearDistrict: true,
          )
        : filter.copyWith(
            city: _city,
          );

    filter = _district == null
        ? filter.copyWith(
            clearDistrict: true,
          )
        : filter.copyWith(
            district: _district,
          );

    filter = _adType == null
        ? filter.copyWith(
            clearAdType: true,
          )
        : filter.copyWith(
            adType: _adType,
          );

    filter = minPrice == null
        ? filter.copyWith(
            clearMinPrice: true,
          )
        : filter.copyWith(
            minPrice: minPrice,
          );

    filter = maxPrice == null
        ? filter.copyWith(
            clearMaxPrice: true,
          )
        : filter.copyWith(
            maxPrice: maxPrice,
          );

    Navigator.of(context).pop(filter);
  }

  void _reset() {
    setState(() {
      _city = null;
      _district = null;
      _adType = null;
      _featuredOnly = false;
      _rangeError = null;

      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  double? _parseNumber(String value) {
    final normalized = value.replaceAll(',', '').replaceAll('٬', '').trim();

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  String _numberText(double? value) {
    if (value == null) {
      return '';
    }

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Text(
      title,
      style: TextStyle(
        color: onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SelectionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFC5A16B)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC5A16B)
                  : onSurface.withValues(
                      alpha: 0.08,
                    ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF0F172A) : onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: cardColor,
      iconEnabledColor: const Color(0xFFC5A16B),
      style: TextStyle(
        color: onSurface,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontSize: 12,
        ),
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: onSurface.withValues(
              alpha: 0.08,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFC5A16B),
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
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _PriceField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      style: TextStyle(
        color: onSurface,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'د.ع',
        suffixStyle: const TextStyle(
          color: Color(0xFFC5A16B),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontSize: 12,
        ),
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: onSurface.withValues(
              alpha: 0.08,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFC5A16B),
          ),
        ),
      ),
    );
  }
}
