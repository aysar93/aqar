import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/push_logout_policy.dart';

void main() {
  test('offline cleanup errors still clear notifications and sign out',
      () async {
    final calls = <String>[];
    await completePrivacyLogout(
      stopActivity: () async {
        calls.add('stop');
        throw StateError('offline');
      },
      detach: () async {
        calls.add('persist revocation');
        throw StateError('offline');
      },
      clearNotifications: () async {
        calls.add('clear');
      },
      signOut: () async {
        calls.add('sign out');
      },
      onCleanupError: (_) {},
    );
    expect(calls, ['stop', 'persist revocation', 'clear', 'sign out']);
  });
  test('auth sign-out error is surfaced and not mistaken for successful logout',
      () async {
    await expectLater(
        completePrivacyLogout(
          stopActivity: () async {},
          detach: () async {},
          clearNotifications: () async {},
          signOut: () async {
            throw StateError('auth failure');
          },
          onCleanupError: (_) {},
        ),
        throwsStateError);
  });
}
