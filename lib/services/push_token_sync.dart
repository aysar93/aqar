/// Synchronizes the two push providers independently. A slow or unavailable
/// Firebase/APNs token must not prevent saving the OneSignal subscription.
Future<void> synchronizePushTokens({
  required String? Function() currentUserId,
  required Future<String?> Function() readOneSignalId,
  required Future<String?> Function() readFcmToken,
  required Future<void> Function(String userId, Map<String, String> fields)
      write,
  required void Function(String provider, Object error) onError,
}) async {
  final userId = currentUserId();
  if (userId == null || userId.isEmpty) return;

  Future<void> sync(String field, Future<String?> Function() read) async {
    try {
      final token = await read();
      if (token == null || token.isEmpty || currentUserId() != userId) return;
      await write(userId, {field: token});
    } catch (error) {
      onError(field, error);
    }
  }

  await Future.wait([
    sync('oneSignalId', readOneSignalId),
    sync('fcmToken', readFcmToken),
  ]);
}

/// Apple requires APNs registration before the FCM token API can be called.
/// Retry briefly; token refresh and subsequent sign-ins can finish later.
Future<String?> readFcmTokenWhenReady({
  required bool requiresApns,
  required Future<String?> Function() readApnsToken,
  required Future<String?> Function() readFcmToken,
  Future<void> Function(Duration)? wait,
  int attempts = 8,
}) async {
  if (requiresApns) {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final apns = await readApnsToken();
      if (apns != null && apns.isNotEmpty) return readFcmToken();
      if (attempt + 1 < attempts) {
        await (wait ?? Future<void>.delayed)(const Duration(milliseconds: 500));
      }
    }
    return null;
  }
  return readFcmToken();
}
