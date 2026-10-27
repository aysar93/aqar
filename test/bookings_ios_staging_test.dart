import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings_ios_staging_main.dart';

void main() {
  test(
      'dedicated iOS entry rejects absent config before Firebase initialization',
      () {
    expect(bookingIosStagingOptions, throwsStateError);
  });
}
