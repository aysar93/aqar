import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_migration.dart';

class PushDeviceService {
  static Future<void> _queue = Future.value();

  static Future<String> _installationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('fcm_installation_v1');
    if (id == null) {
      final random = Random.secure();
      id =
          List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
      await prefs.setString('fcm_installation_v1', id);
    }
    return id;
  }

  static Future<void> register(String token, String uid) {
    if (!PushMigration.enabled) return Future.value();
    return _queue = _queue.catchError((Object _) {}).then((_) async {
      final installationId = await _installationId();
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      await FirebaseFunctions.instance
          .httpsCallable('registerPushDevice')
          .call({
        'installationId': installationId,
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
    });
  }

  /// Must complete while the previous account is still authenticated.
  static Future<void> detach() {
    if (!PushMigration.enabled) return Future.value();
    return _queue = _queue.catchError((Object _) {}).then((_) async {
      await FirebaseFunctions.instance
          .httpsCallable('unregisterPushDevice')
          .call({
        'installationId': await _installationId(),
      });
    });
  }
}
