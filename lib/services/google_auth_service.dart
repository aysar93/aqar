import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInFailure implements Exception {
  final String message;
  final Object? cause;

  const GoogleSignInFailure(this.message, {this.cause});

  @override
  String toString() => message;
}

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '1031621585901-upglau30rejkhjoqf21el5fdd2fjd3sv.apps.googleusercontent.com',
  );

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // تنظيف أي جلسة Google عالقة قبل بدء محاولة جديدة.
      // disconnect قد يفشل إذا لم تكن هناك جلسة؛ لذلك نكتفي بـ signOut.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // المستخدم أغلق نافذة اختيار الحساب؛ هذا ليس خطأ.
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw const GoogleSignInFailure(
          'لم يتم الحصول على رمز Google المطلوب. تأكد من إعدادات Google وFirebase ثم أعد المحاولة.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('Firebase Google Login Error: ${e.code} - ${e.message}');
      debugPrintStack(stackTrace: stackTrace);

      throw GoogleSignInFailure(
        _firebaseMessage(e),
        cause: e,
      );
    } on GoogleSignInFailure {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Google Login Error: $e');
      debugPrintStack(stackTrace: stackTrace);

      final raw = e.toString();

      // ApiException: 10 غالبًا تعني DEVELOPER_ERROR المرتبط بـ SHA/OAuth/package name.
      if (raw.contains('ApiException: 10') ||
          raw.contains('DEVELOPER_ERROR') ||
          raw.contains('code: 10')) {
        throw GoogleSignInFailure(
          'فشل إعداد تسجيل Google (الرمز 10). تحقق من SHA-1/SHA-256 واسم الحزمة وملف google-services.json الخاص بنسخة Google Play.',
          cause: e,
        );
      }

      if (raw.contains('ApiException: 12500') ||
          raw.contains('SIGN_IN_FAILED')) {
        throw GoogleSignInFailure(
          'تعذر إكمال تسجيل الدخول بواسطة Google. تحقق من إعدادات OAuth وشاشة الموافقة في Google Cloud/Firebase.',
          cause: e,
        );
      }

      if (raw.contains('network_error') ||
          raw.contains('NETWORK_ERROR') ||
          raw.contains('ApiException: 7')) {
        throw GoogleSignInFailure(
          'تعذر الاتصال بخدمة Google. تحقق من اتصال الإنترنت وحاول مرة أخرى.',
          cause: e,
        );
      }

      throw GoogleSignInFailure(
        'تعذر تسجيل الدخول بواسطة Google. التفاصيل: $raw',
        cause: e,
      );
    }
  }

  static String _firebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'يوجد حساب بهذا البريد مرتبط بطريقة تسجيل دخول أخرى.';
      case 'invalid-credential':
        return 'بيانات اعتماد Google غير صالحة أو انتهت صلاحيتها. أعد المحاولة.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بواسطة Google غير مفعّل في Firebase Authentication.';
      case 'network-request-failed':
        return 'حدث خطأ في الاتصال بالشبكة. تحقق من الإنترنت وحاول مرة أخرى.';
      default:
        final details = e.message?.trim();
        return details == null || details.isEmpty
            ? 'تعذر تسجيل الدخول بواسطة Google (${e.code}).'
            : 'تعذر تسجيل الدخول بواسطة Google (${e.code}): $details';
    }
  }
}
