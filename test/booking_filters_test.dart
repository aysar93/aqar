import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_filters.dart';

void main() {
  test('Arabic search, old records, price modes and combined filters', () {
    final f = BookingFilters()..search = 'انبار';
    final v = <String, dynamic>{'name': 'شاليه الأَنْبَار', 'price': 100000};
    expect(f.matches(v), isTrue);
    f.capacity = 6;
    expect(f.matches(v), isFalse);
    v.addAll({
      'capacity': 8,
      'bedrooms': 2,
      'amenities': ['pool', 'parking'],
      'pricingMode': 'shifts',
      'shifts': [
        {'price': 90000},
        {'price': 120000}
      ]
    });
    f
      ..maxPrice = 100000
      ..bedrooms = 2;
    f.amenities.add('pool');
    expect(f.matches(v), isTrue);
    f.amenities.add('wifi');
    expect(f.matches(v), isFalse);
    expect(
        bookingStartingPrice({
          'price': 100001,
          'offer': {
            'percent': 10,
            'until': DateTime.now().millisecondsSinceEpoch + 60000
          }
        }),
        90000);
    expect(
        bookingStartingPrice(
            {'pricingMode': 'hourly', 'hourlyPrice': 25000, 'price': 50000}),
        25000);
  });
}
