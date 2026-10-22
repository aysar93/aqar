import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings_staging_main.dart' as staging;

void main() {
  testWidgets('offline notification cleanup cannot block local logout',
      (tester) async {
    final pending = Completer<void>();
    var signedOut = false;
    final done = staging.endBookingStagingSession(
      detachNotifications: () => pending.future,
      signOut: () async {
        signedOut = true;
      },
    );
    await tester.pump(const Duration(seconds: 4));
    await done;
    expect(signedOut, isTrue);
    pending.complete();
  });
  test('notification cleanup failure still signs out', () async {
    var signedOut = false;
    await staging.endBookingStagingSession(
      detachNotifications: () async {
        throw StateError('offline');
      },
      signOut: () async {
        signedOut = true;
      },
    );
    expect(signedOut, isTrue);
  });
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
