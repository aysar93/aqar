import 'firebase_options.dart';
import 'main.dart' as app;
import 'services/push_migration.dart';

/// Compile-only production candidate; never install or launch against production
/// before backend/legacy compatibility acceptance and explicit rollout approval.
Future<void> main() async {
  if (!PushMigration.bridgeEnabled || PushMigration.isolated) {
    throw StateError(
        'Explicit PUSH_BRIDGE production-candidate configuration required');
  }
  await app.startAqar(DefaultFirebaseOptions.currentPlatform,
      bridgeCandidate: true);
}
