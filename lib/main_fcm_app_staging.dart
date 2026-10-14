import 'package:firebase_core/firebase_core.dart';
import 'main.dart' as app;
import 'services/push_migration.dart';

/// Runs the real screens using only the explicitly selected test project.
Future<void> main() async {
  const project = String.fromEnvironment('STAGING_PROJECT_ID');
  const apiKey = String.fromEnvironment('STAGING_API_KEY');
  const appId = String.fromEnvironment('STAGING_APP_ID');
  const sender = String.fromEnvironment('STAGING_SENDER_ID');
  if (!PushMigration.enabled ||
      project != 'aqar-fcm-test-20261014' ||
      const bool.fromEnvironment('STAGING_EMULATORS') ||
      apiKey.isEmpty ||
      appId.isEmpty ||
      sender.isEmpty) {
    throw StateError('Explicit isolated full-app configuration required');
  }
  await app.startAqar(
      const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: sender,
        projectId: project,
        iosBundleId: 'com.andalus.aqar.staging',
      ),
      isolated: true);
}
