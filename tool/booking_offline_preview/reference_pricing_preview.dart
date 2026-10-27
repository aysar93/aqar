// Local design preview only. Never imported by production main.
import 'package:flutter/material.dart';
import 'package:aqar/bookings/booking_pricing_draft.dart';
import 'package:aqar/bookings/booking_venue_details.dart';

class BookingReferencePricingPreview extends StatelessWidget {
  const BookingReferencePricingPreview({super.key, required this.policy});
  final Map<String, dynamic> policy;
  @override
  Widget build(BuildContext context) {
    final draft = BookingPricingDraft(policy),
        days = List<int>.from(draft.data['weekendDays']);
    const names = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('معاينة تسعير محلية — غير مفعّلة للحجز',
          style: TextStyle(fontWeight: FontWeight.w700)),
      for (final weekend in [false, true])
        Card(
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          weekend
                              ? 'أسعار عطلة نهاية الأسبوع'
                              : 'أسعار الأيام العادية',
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                          [
                            for (var i = 0; i < 7; i++)
                              if (days.contains(i) == weekend) names[i]
                          ].join('، '),
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 12),
                      BookingVenuePrices(localPreview: true, venue: {
                        'pricingMode': 'shifts',
                        'deposit': draft.data['deposit'],
                        'shifts': [
                          for (final s in draft.data['shifts'])
                            if (s['enabled'] == true)
                              {
                                'id': s['kind'],
                                'name': const {
                                  'morning': 'الصباحي',
                                  'evening': 'المسائي',
                                  'full_day': 'يوم كامل'
                                }[s['kind']],
                                'checkInMinute': s['startMinute'],
                                'checkOutMinute': s['endMinute'],
                                'price':
                                    s[weekend ? 'weekendPrice' : 'weekdayPrice']
                              }
                        ]
                      })
                    ])))
    ]);
  }
}
