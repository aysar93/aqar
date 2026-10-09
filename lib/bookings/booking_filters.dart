import 'package:flutter/material.dart';

const bookingAmenities = {
  'pool': 'مسبح',
  'parking': 'موقف سيارات',
  'wifi': 'إنترنت',
  'airConditioning': 'تكييف',
  'kitchen': 'مطبخ',
  'playground': 'ألعاب أطفال',
  'accessible': 'سهولة الوصول'
};
String bookingNormalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي');
num bookingStartingPrice(Map<String, dynamic> v) {
  num price;
  if (v['pricingMode'] == 'shifts' && (v['shifts'] as List? ?? []).isNotEmpty) {
    price = (v['shifts'] as List)
        .map((s) => (s['price'] as num?) ?? 0)
        .reduce((a, b) => a < b ? a : b);
  } else {
    price =
        (v[v['pricingMode'] == 'hourly' ? 'hourlyPrice' : 'price'] as num?) ??
            0;
  }
  final offer = v['offer'];
  if (offer is Map &&
      offer['percent'] is int &&
      offer['percent'] >= 0 &&
      offer['percent'] <= 50 &&
      offer['until'] is num &&
      offer['until'] >= DateTime.now().millisecondsSinceEpoch) {
    price = (price * (100 - offer['percent']) / 100).floor();
  }
  return price;
}

class BookingFilters {
  String search = '', category = '', sort = 'name';
  int? maxPrice, capacity, bedrooms;
  final Set<String> amenities = {};
  bool matches(Map<String, dynamic> v) =>
      bookingNormalize(
              '${v['name']} ${v['location']} ${v['complexName'] ?? ''} ${v['unitName'] ?? ''}')
          .contains(bookingNormalize(search.trim())) &&
      (category.isEmpty || v['category'] == category) &&
      (maxPrice == null || bookingStartingPrice(v) <= maxPrice!) &&
      (capacity == null || ((v['capacity'] as num?) ?? 0) >= capacity!) &&
      (bedrooms == null || ((v['bedrooms'] as num?) ?? 0) >= bedrooms!) &&
      amenities.every((a) => (v['amenities'] as List? ?? []).contains(a));
  int compare(Map<String, dynamic> a, Map<String, dynamic> b) => sort == 'price'
      ? bookingStartingPrice(a).compareTo(bookingStartingPrice(b))
      : bookingNormalize('${a['name']}')
          .compareTo(bookingNormalize('${b['name']}'));
}

class BookingFilterBar extends StatelessWidget {
  const BookingFilterBar(
      {super.key, required this.filters, required this.onChanged});
  final BookingFilters filters;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
        TextField(
            decoration: const InputDecoration(
                labelText: 'اسم المكان أو المدينة أو الوحدة',
                prefixIcon: Icon(Icons.search)),
            onChanged: (s) {
              filters.search = s;
              onChanged();
            }),
        Wrap(spacing: 8, children: [
          for (final e in {
            '': 'الكل',
            'chalet': 'شاليه',
            'farm': 'مزرعة',
            'hall': 'قاعة'
          }.entries)
            ChoiceChip(
                label: Text(e.value),
                selected: filters.category == e.key,
                onSelected: (_) {
                  filters.category = e.key;
                  onChanged();
                }),
          TextButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('السعر والسعة والمرافق'),
              onPressed: () async {
                final price = TextEditingController(
                        text: filters.maxPrice?.toString() ?? ''),
                    capacity = TextEditingController(
                        text: filters.capacity?.toString() ?? ''),
                    rooms = TextEditingController(
                        text: filters.bedrooms?.toString() ?? '');
                final selected = Set<String>.from(filters.amenities);
                await showDialog(
                    context: context,
                    builder: (context) => StatefulBuilder(
                        builder: (context, setState) => AlertDialog(
                                title: const Text('تصفية النتائج'),
                                content: SingleChildScrollView(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      const Text(
                                          'السعر للشفت أو للحجز الثابت أو للساعة حسب المكان؛ السعر النهائي عند اختيار الموعد.'),
                                      for (final e in {
                                        price: 'أقصى سعر بالدينار',
                                        capacity: 'الحد الأدنى للضيوف',
                                        rooms: 'الحد الأدنى للغرف'
                                      }.entries)
                                        TextField(
                                            controller: e.key,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                                labelText: e.value)),
                                      Wrap(children: [
                                        for (final e
                                            in bookingAmenities.entries)
                                          FilterChip(
                                              label: Text(e.value),
                                              selected:
                                                  selected.contains(e.key),
                                              onSelected: (yes) => setState(() {
                                                    if (yes) {
                                                      selected.add(e.key);
                                                    } else {
                                                      selected.remove(e.key);
                                                    }
                                                  }))
                                      ])
                                    ])),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('إلغاء')),
                                  TextButton(
                                      onPressed: () {
                                        final values = [
                                          price.text,
                                          capacity.text,
                                          rooms.text
                                        ];
                                        if (values.any((s) =>
                                            s.isNotEmpty &&
                                            (int.tryParse(s) == null ||
                                                int.parse(s) < 0))) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'أدخل أرقامًا موجبة')));
                                          return;
                                        }
                                        filters.maxPrice =
                                            int.tryParse(price.text);
                                        filters.capacity =
                                            int.tryParse(capacity.text);
                                        filters.bedrooms =
                                            int.tryParse(rooms.text);
                                        filters.amenities
                                          ..clear()
                                          ..addAll(selected);
                                        onChanged();
                                        Navigator.pop(context);
                                      },
                                      child: const Text('تطبيق'))
                                ])));
                price.dispose();
                capacity.dispose();
                rooms.dispose();
              }),
          ChoiceChip(
              label: const Text('الأقل سعرًا'),
              selected: filters.sort == 'price',
              onSelected: (yes) {
                filters.sort = yes ? 'price' : 'name';
                onChanged();
              })
        ])
      ]);
}
