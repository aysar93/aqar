import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/analytics/services/presence_service.dart';

void main() {
  const staging = 'aqar-bookings-test-20261009';
  const production =
      'https://aqar-9f3f9-default-rtdb.asia-southeast1.firebasedatabase.app';
  test('non-production presence cannot fall back to production RTDB', () {
    expect(() => presenceDatabaseUrlForProject(staging, null), throwsStateError);
    expect(() => presenceDatabaseUrlForProject(staging, production),
        throwsStateError);
    expect(
        () => presenceDatabaseUrlForProject(staging,
            'https://$staging-default-rtdb.europe-west3.firebasedatabase.app.evil.invalid'),
        throwsStateError);
  });
  test('presence retains its project endpoint and existing production default',
      () {
    const url =
        'https://$staging-default-rtdb.europe-west3.firebasedatabase.app';
    expect(presenceDatabaseUrlForProject(staging, url), url);
    expect(presenceDatabaseUrlForProject('aqar-9f3f9', null), production);
  });
}
