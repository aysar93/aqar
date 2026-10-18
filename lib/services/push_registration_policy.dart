/// FCM registration must not depend on OneSignal availability or account quota.
Future<void> registerDeviceWithOptionalFallback({
  required Future<void> Function() registerFcm,
  required Future<void> Function()? bindFallback,
  required bool Function() stillCurrentAccount,
  required void Function(Object) onFallbackError,
}) async {
  await registerFcm();
  if (bindFallback == null || !stillCurrentAccount()) return;
  try {
    await bindFallback();
  } catch (error) {
    onFallbackError(error);
  }
}
