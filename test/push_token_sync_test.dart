import 'dart:async';
import 'package:aqar/services/push_token_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OneSignal is saved even when Firebase fails', () async {
    final writes = <Map<String, String>>[];
    final failures = <String>[];
    await synchronizePushTokens(
      currentUserId: () => 'owner',
      readOneSignalId: () async => 'onesignal-device',
      readFcmToken: () async => throw StateError('APNs unavailable'),
      write: (uid, data) async => writes.add(data),
      onError: (provider, error) => failures.add(provider),
    );
    expect(writes, [
      {'oneSignalId': 'onesignal-device'}
    ]);
    expect(failures, ['fcmToken']);
  });

  test('OneSignal is saved without waiting for slow Firebase registration',
      () async {
    final delayedFcm = Completer<String?>();
    final savedOneSignal = Completer<void>();
    final operation = synchronizePushTokens(
      currentUserId: () => 'owner',
      readOneSignalId: () async => 'onesignal-device',
      readFcmToken: () => delayedFcm.future,
      write: (uid, data) async {
        if (data.containsKey('oneSignalId')) savedOneSignal.complete();
      },
      onError: (_, __) {},
    );
    await savedOneSignal.future;
    expect(delayedFcm.isCompleted, isFalse);
    delayedFcm.complete('fcm-device');
    await operation;
  });

  test('failed OneSignal storage does not prevent FCM storage', () async {
    final saved = <String>[];
    await synchronizePushTokens(
      currentUserId: () => 'owner',
      readOneSignalId: () async => 'onesignal-device',
      readFcmToken: () async => 'fcm-device',
      write: (uid, data) async {
        if (data.containsKey('oneSignalId')) throw StateError('write failure');
        saved.add(data['fcmToken']!);
      },
      onError: (_, __) {},
    );
    expect(saved, ['fcm-device']);
  });

  test('tokens are not saved to a different user after an account change',
      () async {
    String? userId = 'first';
    var writes = 0;
    await synchronizePushTokens(
      currentUserId: () => userId,
      readOneSignalId: () async {
        userId = 'second';
        return 'device';
      },
      readFcmToken: () async => 'fcm',
      write: (uid, data) async {
        writes++;
      },
      onError: (_, __) {},
    );
    expect(writes, 0);
  });

  test('empty and absent tokens do not clear existing saved tokens', () async {
    var writes = 0;
    await synchronizePushTokens(
      currentUserId: () => 'owner',
      readOneSignalId: () async => null,
      readFcmToken: () async => '',
      write: (uid, data) async {
        writes++;
      },
      onError: (_, __) {},
    );
    expect(writes, 0);
  });

  test('Apple waits for APNs before requesting a Firebase token', () async {
    var apnsCalls = 0;
    var fcmCalls = 0;
    final result = await readFcmTokenWhenReady(
      requiresApns: true,
      readApnsToken: () async => ++apnsCalls == 3 ? 'apns-token' : null,
      readFcmToken: () async {
        fcmCalls++;
        expect(apnsCalls, 3);
        return 'fcm';
      },
      wait: (_) async {},
    );
    expect(result, 'fcm');
    expect(fcmCalls, 1);
  });

  test('missing APNs returns safely without calling Firebase token API',
      () async {
    var apnsCalls = 0;
    var fcmCalls = 0;
    final result = await readFcmTokenWhenReady(
      requiresApns: true,
      attempts: 3,
      readApnsToken: () async {
        apnsCalls++;
        return null;
      },
      readFcmToken: () async {
        fcmCalls++;
        return 'fcm';
      },
      wait: (_) async {},
    );
    expect(result, isNull);
    expect(apnsCalls, 3);
    expect(fcmCalls, 0);
  });

  test('Android requests Firebase token without waiting for APNs', () async {
    final result = await readFcmTokenWhenReady(
      requiresApns: false,
      readApnsToken: () async => throw StateError('APNs must not be read'),
      readFcmToken: () async => 'android-token',
    );
    expect(result, 'android-token');
  });
}
