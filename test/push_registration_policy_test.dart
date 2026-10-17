import 'package:aqar/services/push_registration_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OneSignal failure does not roll back an accepted FCM registration',
      () async {
    final actions = <String>[];
    await registerDeviceWithOptionalFallback(
      registerFcm: () async {
        actions.add('registered');
      },
      bindFallback: () async {
        throw StateError('quota or provider unavailable');
      },
      stillCurrentAccount: () => true,
      onFallbackError: (_) => actions.add('fallback pending'),
    );
    expect(actions, ['registered', 'fallback pending']);
  });
  test('account switch prevents a stale fallback binding', () async {
    var attempted = false;
    await registerDeviceWithOptionalFallback(
      registerFcm: () async {},
      bindFallback: () async {
        attempted = true;
      },
      stillCurrentAccount: () => false,
      onFallbackError: (_) {},
    );
    expect(attempted, false);
  });
}
