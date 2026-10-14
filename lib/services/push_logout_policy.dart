/// Local authentication must finish even when push/presence cleanup is offline.
/// Remote revocation is persisted by [detach] before its bounded network retry.
Future<void> completePrivacyLogout({
  required Future<void> Function() stopActivity,
  required Future<void> Function() detach,
  required Future<void> Function() clearNotifications,
  required Future<void> Function() signOut,
  required void Function(Object error) onCleanupError,
}) async {
  for (final cleanup in [stopActivity, detach, clearNotifications]) {
    try {
      await cleanup().timeout(const Duration(seconds: 6));
    } catch (error) {
      onCleanupError(error);
    }
  }
  await signOut();
}
