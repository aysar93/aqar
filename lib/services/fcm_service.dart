class FCMService {
 static Future<void> initialize() async {}
 static Future<void> saveTokens() async {}
 static Future<bool> requestNotificationPermission() async => false;
 static Future<bool> isSystemNotificationPermissionGranted() async => false;
 static Future<bool> enableNotifications() async => false;
 static Future<bool> disableNotifications() async => true;
}