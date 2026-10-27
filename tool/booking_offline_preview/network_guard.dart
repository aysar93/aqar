import 'dart:io';

class OfflineHttpGuard extends HttpOverrides {
  static int blocked = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    blocked++;
    throw StateError('OFFLINE_PREVIEW_NETWORK_DENIED');
  }
}
