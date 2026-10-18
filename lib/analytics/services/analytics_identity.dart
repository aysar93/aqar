import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsIdentity {
  AnalyticsIdentity._();
  static const _guestKey = 'analytics_guest_id';

  static Future<String> id() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) return uid;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_guestKey);
    if (saved != null) return saved;
    final value = 'guest_${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(_guestKey, value);
    return value;
  }
}
