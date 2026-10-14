import 'package:firebase_auth/firebase_auth.dart';

/// Enable only in an approved test build after deploying to a test project.
class PushMigration {
  static const isolated =
      bool.fromEnvironment('FCM_MIGRATION', defaultValue: false);
  static const bridgeEnabled =
      bool.fromEnvironment('PUSH_BRIDGE', defaultValue: false);
  static const enabled = isolated || bridgeEnabled;
  static const oneSignalEnabled = !enabled || bridgeEnabled;

  static Map<String, dynamic> get fields => enabled
      ? {
          'pushTransport': 'fcm_v1',
          'createdBy': FirebaseAuth.instance.currentUser?.uid
        }
      : {};
}
