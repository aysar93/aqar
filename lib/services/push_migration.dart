import 'package:firebase_auth/firebase_auth.dart';

/// Enable only in an approved test build after deploying to a test project.
class PushMigration {
  static const enabled =
      bool.fromEnvironment('FCM_MIGRATION', defaultValue: false);

  static Map<String, dynamic> get fields => enabled
      ? {
          'pushTransport': 'fcm_v1',
          'createdBy': FirebaseAuth.instance.currentUser?.uid
        }
      : {};
}
