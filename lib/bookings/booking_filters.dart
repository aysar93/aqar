import 'booking_discovery_design.dart';
import 'booking_pricing_draft.dart';
import 'package:flutter/material.dart';

const bookingAmenities = {
  'pool': 'مسبح',
  'playground': 'ألعاب أطفال',
  'wifi': 'إنترنت',
  'parking': 'موقف سيارات',
  'grill': 'شواية',
  'outdoorSeating': 'جلسات خارجية',
  'airConditioning': 'تكييف',
  'view': 'إطلالة',
  'heating': 'تدفئة',
  'kitchen': 'مطبخ مجهز',
  'sauna': 'ساونا',
  'jacuzzi': 'جاكوزي',
  'garden': 'حديقة',
  'generator': 'مولد كهربائي',
  'security': 'حراسة',
};
String bookingNormalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي');

num? bookingValidStartingPrice(Map<String, dynamic> v) {
  num? price;
  final v2 = BookingPricingDraft.fromVenue(v);
  if (v2 != null && v2.startingPrice != null && v2.startingPrice! > 0) {
    price = v2.startingPrice;
  } else if (v['pricingMode'] == 'shifts' &&
      (v['shifts'] as List? ?? []).isNotEmpty) {
    final validShiftPrices = <num>[
      for (final s in v['shifts'] as List)
        if (s is Map &&
            s['price'] is num &&
            (s['price'] as num).isFinite &&
            (s['price'] as num) > 0)
          s['price'] as num
    ];
    if (validShiftPrices.isNotEmpty) {
      price = validShiftPrices.reduce((a, b) => a < b ? a : b);
    }
  } else {
    final raw = v[v['pricingMode'] == 'hourly' ? 'hourlyPrice' : 'price'];
    if (raw is num && raw.isFinite && raw > 0) {
      price = raw;
    }
  }
  if (price == null || !price.isFinite || price <= 0) return null;
  final offer = v['offer'];
  if (offer is Map &&
      offer['percent'] is int &&
      offer['percent'] >= 0 &&
      offer['percent'] <= 50 &&
      offer['until'] is num &&
      offer['until'] >= DateTime.now().millisecondsSinceEpoch) {
    price = (price * (100 - offer['percent']) / 100).floor();
  }
  return price > 0 ? price : null;
}

num bookingStartingPrice(Map<String, dynamic> v) =>
    bookingValidStartingPrice(v) ?? 0;

class BookingFilters {
  String search = '', category = '', sort = 'name';
  int? maxPrice, capacity, bedrooms;
  final Set<String> amenities = {};
  bool matches(Map<String, dynamic> v) {
    final validPrice = bookingValidStartingPrice(v);
    return bookingNormalize(
                '${v['name']} ${v['location']} ${v['complexName'] ?? ''} ${v['unitName'] ?? ''}')
            .contains(bookingNormalize(search.trim())) &&
        (category.isEmpty || v['category'] == category) &&
        (maxPrice == null ||
            (validPrice != null && validPrice <= maxPrice!)) &&
        (capacity == null || ((v['capacity'] as num?) ?? 0) >= capacity!) &&
        (bedrooms == null || ((v['bedrooms'] as num?) ?? 0) >= bedrooms!) &&
        amenities.every((a) => (v['amenities'] as List? ?? []).contains(a));
  }

  int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (sort == 'price') {
      final pa = bookingValidStartingPrice(a);
      final pb = bookingValidStartingPrice(b);
      if (pa == null && pb == null) {
        return bookingNormalize('${a['name']}')
            .compareTo(bookingNormalize('${b['name']}'));
      }
      if (pa == null) return 1;
      if (pb == null) return -1;
      final c = pa.compareTo(pb);
      if (c != 0) return c;
    }
    return bookingNormalize('${a['name']}')
        .compareTo(bookingNormalize('${b['name']}'));
  }
}

class BookingFilterBar extends StatelessWidget {
  const BookingFilterBar(
      {super.key,
      required this.filters,
      required this.onChanged,
      this.welcome = false,
      this.heroAction});
  final bool welcome;
  final Widget? heroAction;
  final BookingFilters filters;
  final VoidCallback onChanged;
  Future<void> openFilters(BuildContext context) async {
    final price =
            TextEditingController(text: filters.maxPrice?.toString() ?? ''),
        capacity =
            TextEditingController(text: filters.capacity?.toString() ?? ''),
        rooms = TextEditingController(text: filters.bedrooms?.toString() ?? '');
    final selected = Set<String>.from(filters.amenities);
    String sortChoice = filters.sort;
    final route = DialogRoute<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              const gold = Color(0xFFD4AF37);
              const navy = Color(0xFF0F172A);
              return Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: const Row(
                    children: [
                      Icon(Icons.tune, color: gold, size: 22),
                      SizedBox(width: 8),
                      Text('تصفية النتائج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'السعر للشفت أو للحجز الثابت أو للساعة حسب المكان؛ السعر النهائي عند اختيار الموعد.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final e in {
                          price: 'أقصى سعر بالدينار',
                          capacity: 'الحد الأدنى للضيوف',
                          rooms: 'الحد الأدنى للغرف'
                        }.entries) ...[
                          TextField(
                            controller: e.key,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: e.value,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 6),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'ترتيب النتائج:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              key: const ValueKey('booking-sort-price'),
                              label: const Text('الأقل سعرًا'),
                              avatar: const Icon(Icons.arrow_downward, size: 16),
                              selected: sortChoice == 'price',
                              selectedColor: gold.withValues(alpha: 0.2),
                              side: BorderSide(color: sortChoice == 'price' ? gold : Colors.grey.withValues(alpha: 0.4)),
                              onSelected: (yes) => setState(() => sortChoice = yes ? 'price' : 'name'),
                            ),
                            ChoiceChip(
                              label: const Text('الافتراضي'),
                              avatar: const Icon(Icons.sort_by_alpha, size: 16),
                              selected: sortChoice != 'price',
                              selectedColor: gold.withValues(alpha: 0.2),
                              side: BorderSide(color: sortChoice != 'price' ? gold : Colors.grey.withValues(alpha: 0.4)),
                              onSelected: (yes) => setState(() => sortChoice = yes ? 'name' : 'price'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'المرافق والخدمات:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in bookingAmenities.entries)
                              FilterChip(
                                label: Text(e.value),
                                selected: selected.contains(e.key),
                                selectedColor: gold.withValues(alpha: 0.2),
                                side: BorderSide(color: selected.contains(e.key) ? gold : Colors.grey.withValues(alpha: 0.4)),
                                onSelected: (yes) => setState(() {
                                  if (yes) {
                                    selected.add(e.key);
                                  } else {
                                    selected.remove(e.key);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: gold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final values = [
                          price.text,
                          capacity.text,
                          rooms.text
                        ];
                        if (values.any((s) =>
                            s.isNotEmpty &&
                            (int.tryParse(s) == null || int.parse(s) < 0))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('أدخل أرقامًا موجبة')));
                          return;
                        }
                        filters.sort = sortChoice;
                        filters.maxPrice = int.tryParse(price.text);
                        filters.capacity = int.tryParse(capacity.text);
                        filters.bedrooms = int.tryParse(rooms.text);
                        filters.amenities
                          ..clear()
                          ..addAll(selected);
                        onChanged();
                        Navigator.pop(context);
                      },
                      child: const Text('تطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }));
    await Navigator.of(context).push(route);
    // The pop result precedes the reverse transition. Keep the
    // controllers alive until the dialog's fields are unmounted.
    await route.completed;
    price.dispose();
    capacity.dispose();
    rooms.dispose();
  }


  @override
  Widget build(BuildContext context) => Column(children: [
        if (welcome)
          BookingWelcomeSearch(
              toolbarAction: heroAction,
              search: TextField(
                  key: const ValueKey('booking-search-field'),
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                      hintText: 'ابحث عن مكان أو مدينة',
                      suffixIcon: Padding(
                          padding: const EdgeInsets.all(6),
                          child: IconButton.filled(
                              tooltip: 'تصفية النتائج',
                              style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white),
                              onPressed: () => openFilters(context),
                              icon: const Icon(Icons.tune, size: 20))),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF0F172A))),
                  onChanged: (s) {
                    filters.search = s;
                    onChanged();
                  }))
        else ...[
          TextField(
              key: const ValueKey('booking-search-field'),
              decoration: const InputDecoration(
                  hintText: 'ابحث عن مكان أو مدينة',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (s) {
                filters.search = s;
                onChanged();
              }),
          const SizedBox(height: 8),
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('السعر والسعة والمرافق'),
                        onPressed: () => openFilters(context)),
                  ])),
        ],
        const SizedBox(height: 12),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: welcome ? 20 : 0),
            child: BookingCategoryStrip(
                selected: filters.category,
                onSelected: (category) {
                  filters.category = category;
                  onChanged();
                })),
        const SizedBox(height: 4),
      ]);
}
