import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/iraqi_phone_service.dart';

void main() {
  test('normalizes supported Iraqi mobile formats', () {
    const expected = '+9647801234567';
    const inputs = [
      '07801234567',
      '7801234567',
      '+9647801234567',
      '009647801234567',
      '9647801234567',
      '٠٧٨٠١٢٣٤٥٦٧',
      '۰۷۸۰۱۲۳۴۵۶۷',
      '0780 123 4567',
    ];
    for (final input in inputs) {
      expect(IraqiPhoneService.normalize(input), expected);
    }
  });

  test('rejects invalid Iraqi mobile numbers', () {
    expect(IraqiPhoneService.normalize('077123'), isNull);
    expect(IraqiPhoneService.normalize('12345678901'), isNull);
    expect(IraqiPhoneService.normalize(''), isNull);
  });
}
