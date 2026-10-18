import 'package:firebase_auth/firebase_auth.dart';
// Isolated media UI testing excludes analytics and presence writes.
class VisitTrackingService {
 String get sessionId => '';
 Future<String> startSession(User user) async => '';
 Future<void> recordActivity(User user, {bool ensureDocument=false}) async {}
 Future<void> endSession() async {}
}
