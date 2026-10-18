import 'package:firebase_auth/firebase_auth.dart';

// This isolated media test uses synthetic email accounts only.
class FacebookAuthService {
 static Future<UserCredential?> signInWithFacebook() async {
  throw UnsupportedError('Facebook sign-in is disabled in isolated media tests');
 }
}
