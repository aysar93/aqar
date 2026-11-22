import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings_test_main.dart' as testing;

void main() {
  test('test entry refuses to start without the isolated Android flavor',
      () async {
    await expectLater(testing.main(), throwsA(isA<StateError>()));
  });
}
