import 'package:flutter/material.dart';
import 'package:aqar/bookings/booking_pricing_draft.dart';
import 'package:aqar/bookings/booking_venue_details.dart';

/// Only imported by the guarded offline diagnostic entry; never calls Firebase.
class BookingDraftPricingEditor extends StatefulWidget {
  const BookingDraftPricingEditor({super.key});
  @override
  State<BookingDraftPricingEditor> createState() =>
      _BookingDraftPricingEditorState();
}

class _BookingDraftPricingEditorState extends State<BookingDraftPricingEditor> {
  final days = <int>{};
  final shifts = <Map<String, dynamic>>[
    {
      'kind': 'morning',
      'enabled': true,
      'startMinute': 540,
      'endMinute': 1080,
      'endDayOffset': 0,
      'weekdayPrice': 100000,
      'weekendPrice': 150000
    },
    {
      'kind': 'evening',
      'enabled': true,
      'startMinute': 1140,
      'endMinute': 1380,
      'endDayOffset': 0,
      'weekdayPrice': 120000,
      'weekendPrice': 170000
    },
    {
      'kind': 'full_day',
      'enabled': false,
      'startMinute': 540,
      'endMinute': 540,
      'endDayOffset': 1,
      'weekdayPrice': 250000,
      'weekendPrice': 300000
    },
  ];
  String? result;
  Future<void> pick(Map<String, dynamic> s, String key) async {
    final old = s[key] as int;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: old ~/ 60, minute: old % 60),
        builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: false),
            child: w!));
    if (t != null && mounted) setState(() => s[key] = t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'مسودة محلية غير منشورة. هذه الأسعار لا تغيّر السعر الحالي أو الحجوزات، ولا تُرسل للخادم.',
            style: TextStyle(height: 1.8, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('حدد أيام عطلة نهاية الأسبوع — لا يوجد افتراض تلقائي'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in const {
            0: 'الأحد',
            1: 'الاثنين',
            2: 'الثلاثاء',
            3: 'الأربعاء',
            4: 'الخميس',
            5: 'الجمعة',
            6: 'السبت'
          }.entries)
            FilterChip(
                label: Text(e.value),
                selected: days.contains(e.key),
                onSelected: (yes) => setState(() {
                      yes ? days.add(e.key) : days.remove(e.key);
                    }))
        ]),
        for (final s in shifts)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(const {
                              'morning': 'الصباحي',
                              'evening': 'المسائي',
                              'full_day': 'اليوم الكامل'
                            }[s['kind']]!),
                            value: s['enabled'],
                            onChanged: (v) => setState(() => s['enabled'] = v)),
                        for (final key in ['weekdayPrice', 'weekendPrice'])
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                  key: ValueKey('${s['kind']}-$key'),
                                  initialValue: '${s[key]}',
                                  enabled: s['enabled'],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: key == 'weekdayPrice'
                                          ? 'الأيام العادية — د.ع'
                                          : 'عطلة نهاية الأسبوع — د.ع'),
                                  onChanged: (text) {
                                    s[key] = int.tryParse(text) ?? -1;
                                  })),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final key in ['startMinute', 'endMinute'])
                            OutlinedButton(
                                onPressed:
                                    s['enabled'] ? () => pick(s, key) : null,
                                child: Text(
                                    '${key == 'startMinute' ? 'الدخول' : 'الخروج'}: ${bookingClock12(s[key])}'))
                        ]),
                        DropdownButtonFormField<int>(
                            initialValue: s['endDayOffset'],
                            decoration:
                                const InputDecoration(labelText: 'يوم الخروج'),
                            items: const [
                              DropdownMenuItem(
                                  value: 0, child: Text('اليوم نفسه')),
                              DropdownMenuItem(
                                  value: 1, child: Text('اليوم التالي'))
                            ],
                            onChanged: s['enabled']
                                ? (v) => setState(() => s['endDayOffset'] = v)
                                : null),
                      ]))),
        const Text(
            'عربون هذه العينة: 20,000 د.ع ثابت. سياسة النسبة غير مدعومة في الخادم الحالي.'),
        FilledButton(
            onPressed: () {
              try {
                BookingPricingDraft({
                  'version': 2,
                  'timeZone': 'Asia/Baghdad',
                  'deposit': 20000,
                  'weekendDays': days.toList(),
                  'shifts': shifts
                });
                setState(() =>
                    result = 'المسودة صالحة محليًا — لم تُنشر أو تغيّر حجزًا.');
              } on FormatException catch (e) {
                setState(() => result = e.message);
              }
            },
            child: const Text('التحقق من المسودة محليًا')),
        if (result != null) Text(result!, style: const TextStyle(height: 1.8)),
      ]);
}
