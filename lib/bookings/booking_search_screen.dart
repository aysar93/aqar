import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_filters.dart';
import 'booking_screen.dart';
import 'booking_widgets.dart';

/// Dedicated advanced search screen for bookable venues in Anbar.
/// Supports venue type, city/region, price range, date/shift, capacity, and amenities.
class BookingSearchScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  final ValueChanged<Map<String, dynamic>>? onVenueSelected;
  final bool embedded;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;

  const BookingSearchScreen({
    super.key,
    this.initialFilters,
    this.onVenueSelected,
    this.embedded = false,
    this.stream,
  });

  @override
  State<BookingSearchScreen> createState() => _BookingSearchScreenState();
}

class _BookingSearchScreenState extends State<BookingSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = ''; // '' = all, chalet, farm, hall, other
  String _selectedCity = '';
  RangeValues _priceRange = const RangeValues(0, 1500000);
  DateTime? _selectedDate;
  String _selectedShift = ''; // '', morning, evening, fullDay
  int? _minCapacity;
  final Set<String> _selectedAmenities = {};

  static const _cities = [
    'الكل',
    'الرمادي',
    'الفلوجة',
    'الحبانية',
    'هيت',
    'حديثة',
    'الكرمة',
    'القائم',
    'عنه',
    'راوة',
    'الرطبة',
  ];

  static const _categories = [
    {'id': '', 'label': 'الكل', 'icon': Icons.apps},
    {'id': 'chalet', 'label': 'شاليهات', 'icon': Icons.pool_outlined},
    {'id': 'farm', 'label': 'مزارع', 'icon': Icons.nature_people_outlined},
    {'id': 'hall', 'label': 'قاعات', 'icon': Icons.celebration_outlined},
    {'id': 'other', 'label': 'أخرى', 'icon': Icons.holiday_village_outlined},
  ];

  static const _shifts = [
    {'id': '', 'label': 'أي وقت'},
    {'id': 'morning', 'label': 'صباحي'},
    {'id': 'evening', 'label': 'مسائي'},
    {'id': 'fullDay', 'label': 'يوم كامل'},
  ];

  static const _amenitiesList = [
    {'id': 'pool', 'label': 'مسبح', 'icon': Icons.pool},
    {'id': 'parking', 'label': 'موقف سيارات', 'icon': Icons.local_parking},
    {'id': 'wifi', 'label': 'واي فاي', 'icon': Icons.wifi},
    {'id': 'airConditioning', 'label': 'تكييف', 'icon': Icons.ac_unit},
    {'id': 'kitchen', 'label': 'مطبخ مجهز', 'icon': Icons.kitchen},
    {'id': 'playground', 'label': 'ألعاب أطفال', 'icon': Icons.child_care},
    {'id': 'bbq', 'label': 'مكان شواء', 'icon': Icons.outdoor_grill},
    {'id': 'accessible', 'label': 'سهولة الوصول', 'icon': Icons.accessible},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFilters != null) {
      _selectedCategory = widget.initialFilters!['category'] ?? '';
      _selectedCity = widget.initialFilters!['city'] ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = '';
      _selectedCity = '';
      _priceRange = const RangeValues(0, 1500000);
      _selectedDate = null;
      _selectedShift = '';
      _minCapacity = null;
      _selectedAmenities.clear();
    });
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_searchController.text.trim().isNotEmpty) count++;
    if (_selectedCategory.isNotEmpty) count++;
    if (_selectedCity.isNotEmpty && _selectedCity != 'الكل') count++;
    if (_priceRange.start > 0 || _priceRange.end < 1500000) count++;
    if (_selectedDate != null) count++;
    if (_selectedShift.isNotEmpty) count++;
    if (_minCapacity != null) count++;
    count += _selectedAmenities.length;
    return count;
  }

  bool _matchesFilters(Map<String, dynamic> venue) {
    final name = venue['name']?.toString() ?? '';
    final location = venue['location']?.toString() ?? '';
    final complex = venue['complexName']?.toString() ?? '';
    final query = _searchController.text.trim();

    if (query.isNotEmpty) {
      final combined = bookingNormalize('$name $location $complex');
      if (!combined.contains(bookingNormalize(query))) return false;
    }

    if (_selectedCategory.isNotEmpty && venue['category'] != _selectedCategory) {
      return false;
    }

    if (_selectedCity.isNotEmpty && _selectedCity != 'الكل') {
      if (!location.contains(_selectedCity) && !name.contains(_selectedCity)) {
        return false;
      }
    }

    final price = bookingStartingPrice(venue);
    if (price > 0) {
      if (price < _priceRange.start || price > _priceRange.end) {
        return false;
      }
    }

    if (_minCapacity != null && _minCapacity! > 0) {
      final cap = venue['capacity'] is num ? (venue['capacity'] as num).toInt() : 0;
      if (cap < _minCapacity!) return false;
    }

    if (_selectedAmenities.isNotEmpty) {
      final venueAmenities = List<String>.from(venue['amenities'] ?? []);
      for (final required in _selectedAmenities) {
        if (!venueAmenities.contains(required)) return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final content = Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم المكان، المدينة، أو المجمع...',
                        prefixIcon: const Icon(Icons.search, color: bookingGold),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: bookingGold, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  if (_activeFiltersCount > 0 && widget.embedded) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'إعادة ضبط الفلاتر',
                      icon: const Icon(Icons.refresh, color: bookingGold),
                      onPressed: _resetFilters,
                    ),
                  ],
                ],
              ),
            ),

            // Main Content: Filters Expansion + Results List
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Filter Control Panel
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Card(
                        elevation: 0,
                        color: surfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: cardBorder),
                        ),
                        child: Theme(
                          data: theme.copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.tune_rounded, color: bookingGold),
                                if (_activeFiltersCount > 0)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: bookingGold,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$_activeFiltersCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              'فلاتر البحث المتقدم (${_activeFiltersCount > 0 ? "$_activeFiltersCount نشطة" : "تخصيص"})',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'النوع، الموقع، السعر، التواريخ، السعة، والخدمات',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    // 1. Categories
                                    _buildSectionLabel('نوع المكان'),
                                    const SizedBox(height: 8),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _categories.map((c) {
                                          final selected = _selectedCategory == c['id'];
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: ChoiceChip(
                                              avatar: Icon(
                                                c['icon'] as IconData,
                                                size: 16,
                                                color: selected ? Colors.white : bookingGold,
                                              ),
                                              label: Text(c['label'] as String),
                                              selected: selected,
                                              selectedColor: bookingGold,
                                              labelStyle: TextStyle(
                                                color: selected ? Colors.white : null,
                                                fontWeight: selected ? FontWeight.bold : null,
                                              ),
                                              onSelected: (val) {
                                                setState(() {
                                                  _selectedCategory = val ? (c['id'] as String) : '';
                                                });
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // 2. City
                                    _buildSectionLabel('الموقع / المدينة'),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _cities.map((city) {
                                        final isAll = city == 'الكل';
                                        final selected = isAll
                                            ? _selectedCity.isEmpty || _selectedCity == 'الكل'
                                            : _selectedCity == city;
                                        return FilterChip(
                                          label: Text(city),
                                          selected: selected,
                                          selectedColor: bookingGold.withValues(alpha: 0.2),
                                          checkmarkColor: bookingGold,
                                          labelStyle: TextStyle(
                                            color: selected ? bookingGold : null,
                                            fontWeight: selected ? FontWeight.bold : null,
                                            fontSize: 12,
                                          ),
                                          onSelected: (val) {
                                            setState(() {
                                              _selectedCity = isAll ? '' : (val ? city : '');
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),

                                    // 3. Price Range Slider
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildSectionLabel('السعر التقريبي (د.ع)'),
                                        Text(
                                          '${_priceRange.start.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} - ${_priceRange.end.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                          style: const TextStyle(
                                            color: bookingGold,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    RangeSlider(
                                      values: _priceRange,
                                      min: 0,
                                      max: 2000000,
                                      divisions: 20,
                                      activeColor: bookingGold,
                                      inactiveColor: isDark ? Colors.white24 : Colors.black12,
                                      labels: RangeLabels(
                                        '${(_priceRange.start / 1000).toInt()}k',
                                        '${(_priceRange.end / 1000).toInt()}k',
                                      ),
                                      onChanged: (vals) => setState(() => _priceRange = vals),
                                    ),
                                    const SizedBox(height: 16),

                                    // 4. Shift & Date
                                    _buildSectionLabel('الفترة وموعد الحجز'),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: _selectedDate ?? DateTime.now(),
                                                firstDate: DateTime.now(),
                                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                                locale: const Locale('ar'),
                                              );
                                              if (picked != null) {
                                                setState(() => _selectedDate = picked);
                                              }
                                            },
                                            icon: const Icon(Icons.event, size: 18),
                                            label: Text(
                                              _selectedDate != null
                                                  ? '${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}'
                                                  : 'اختر التاريخ',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                        if (_selectedDate != null)
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 18),
                                            onPressed: () => setState(() => _selectedDate = null),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: _shifts.map((s) {
                                        final selected = _selectedShift == s['id'];
                                        return ChoiceChip(
                                          label: Text(s['label']!),
                                          selected: selected,
                                          selectedColor: bookingGold,
                                          labelStyle: TextStyle(
                                            color: selected ? Colors.white : null,
                                            fontSize: 12,
                                          ),
                                          onSelected: (val) {
                                            setState(() => _selectedShift = val ? s['id']! : '');
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),

                                    // 5. Capacity
                                    _buildSectionLabel('سعة المكان (الحد الأدنى لعدد الضيوف)'),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        {'label': 'الكل', 'val': null},
                                        {'label': '10+', 'val': 10},
                                        {'label': '25+', 'val': 25},
                                        {'label': '50+', 'val': 50},
                                        {'label': '100+', 'val': 100},
                                      ].map((cap) {
                                        final val = cap['val'] as int?;
                                        final selected = _minCapacity == val;
                                        return ChoiceChip(
                                          label: Text(cap['label'] as String),
                                          selected: selected,
                                          selectedColor: bookingGold,
                                          labelStyle: TextStyle(
                                            color: selected ? Colors.white : null,
                                            fontSize: 12,
                                          ),
                                          onSelected: (selectedVal) {
                                            setState(() => _minCapacity = selectedVal ? val : null);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),

                                    // 6. Amenities
                                    _buildSectionLabel('الميزات والخدمات المطلوبة'),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _amenitiesList.map((a) {
                                        final id = a['id'] as String;
                                        final selected = _selectedAmenities.contains(id);
                                        return FilterChip(
                                          avatar: Icon(
                                            a['icon'] as IconData,
                                            size: 16,
                                            color: selected ? bookingGold : null,
                                          ),
                                          label: Text(a['label'] as String),
                                          selected: selected,
                                          selectedColor: bookingGold.withValues(alpha: 0.18),
                                          checkmarkColor: bookingGold,
                                          labelStyle: TextStyle(
                                            color: selected ? bookingGold : null,
                                            fontWeight: selected ? FontWeight.bold : null,
                                            fontSize: 11,
                                          ),
                                          onSelected: (val) {
                                            setState(() {
                                              if (val) {
                                                _selectedAmenities.add(id);
                                              } else {
                                                _selectedAmenities.remove(id);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Results Stream
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.stream ??
                        (Firebase.apps.isNotEmpty
                            ? FirebaseFirestore.instance
                                .collection('booking_venues')
                                .where('active', isEqualTo: true)
                                .snapshots()
                            : const Stream.empty()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: CircularProgressIndicator(color: bookingGold),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'تعذر تحميل نتائج البحث: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      final allVenues = snapshot.data?.docs ?? [];
                      final filtered = allVenues
                          .where((doc) => _matchesFilters(doc.data()))
                          .map((doc) => <String, dynamic>{
                                ...doc.data(),
                                'id': doc.id,
                              })
                          .toList();

                      if (filtered.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 64,
                                    color: Colors.grey.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'لم يتم العثور على أماكن مطابقة',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'جرّب تغيير كلمات البحث، توسيع نطاق السعر، أو إزالة بعض الفلاتر.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _resetFilters,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('إعادة ضبط الفلاتر'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: bookingGold,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'النتائج المتاحة (${filtered.length})',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_activeFiltersCount > 0)
                                      Text(
                                        '$_activeFiltersCount فلاتر مطبقة',
                                        style: const TextStyle(
                                          color: bookingGold,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }

                            final venue = filtered[index - 1];
                            final venueId = venue['id'] as String;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: BookingVenueCard(
                                venue: venue,
                                onTap: () {
                                  if (widget.onVenueSelected != null) {
                                    widget.onVenueSelected!(venue);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingRequestScreen(
                                          venueId: venueId,
                                          venue: venue,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                          childCount: filtered.length + 1,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );

    if (widget.embedded) {
      return Material(color: Colors.transparent, child: content);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('بحث الحجوزات'),
        centerTitle: true,
        actions: [
          if (_activeFiltersCount > 0)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh, size: 18, color: bookingGold),
              label: const Text(
                'إعادة ضبط',
                style: TextStyle(color: bookingGold, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
