import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppleAuthService {
  AppleAuthService._();

  static Future<UserCredential?> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name')
      ..setCustomParameters({'locale': 'ar'});

    try {
      if (kIsWeb) {
        return await FirebaseAuth.instance.signInWithPopup(provider);
      }

      return await FirebaseAuth.instance.signInWithProvider(provider);
    } on FirebaseAuthException catch (error) {
      if (_isCancellation(error.code)) return null;
      rethrow;
    }
  }

  static bool _isCancellation(String code) {
    return code == 'canceled' ||
        code == 'cancelled' ||
        code == 'web-context-canceled' ||
        code == 'web-context-cancelled';
  }
}
