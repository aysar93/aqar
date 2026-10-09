import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings_staging_main.dart' as staging;

void main() {
  test('staging refuses production flavor and project', () {
    expect(
        staging.bookingStagingAllowed(
            'bookingsStaging', 'aqar-bookings-test-20261009'),
        isTrue);
    expect(
        staging.bookingStagingAllowed(
            'production', 'aqar-bookings-test-20261009'),
        isFalse);
    expect(staging.bookingStagingAllowed('bookingsStaging', 'aqar-9f3f9'),
        isFalse);
    expect(staging.bookingStagingAllowed('bookingsTest', 'demo-aqar'), isFalse);
  });
  test('staging entry refuses initialization outside its own flavor', () async {
    await expectLater(staging.main(), throwsA(isA<StateError>()));
  });
}
