import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'fcm_service.dart';
import 'iraqi_phone_service.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class PasswordAuthService {
  PasswordAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String internalEmailForPhone(String phone) {
    final normalized = IraqiPhoneService.normalize(phone);
    if (normalized == null) {
      throw const AuthFailure('رقم الهاتف العراقي غير صحيح');
    }
    return 'phone-${normalized.substring(1)}@login.aqar.invalid';
  }

  static String indexId(String value) {
    return base64Url
        .encode(utf8.encode(value.trim().toLowerCase()))
        .replaceAll('=', '');
  }

  static Future<UserCredential> register({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    final normalizedPhone = IraqiPhoneService.normalize(phone);
    if (normalizedPhone == null) {
      throw const AuthFailure('يرجى إدخال رقم هاتف عراقي صحيح');
    }
    final contactEmail = email?.trim().toLowerCase() ?? '';
    final authEmail = internalEmailForPhone(normalizedPhone);
    UserCredential? credential;

    try {
      final phoneIndex = _firestore
          .collection('phone_login_index')
          .doc(indexId(normalizedPhone));
      if ((await phoneIndex.get()).exists) {
        throw const AuthFailure('رقم الهاتف مستخدم مسبقًا');
      }

      credential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());

      final userRef = _firestore.collection('users').doc(credential.user!.uid);
      final emailIndex = contactEmail.isEmpty
          ? null
          : _firestore
              .collection('email_login_index')
              .doc(indexId(contactEmail));

      await _firestore.runTransaction((transaction) async {
        final phoneSnapshot = await transaction.get(phoneIndex);
        if (phoneSnapshot.exists) {
          throw const AuthFailure('رقم الهاتف مستخدم مسبقًا');
        }
        if (emailIndex != null) {
          final emailSnapshot = await transaction.get(emailIndex);
          if (emailSnapshot.exists) {
            throw const AuthFailure('البريد الإلكتروني مستخدم مسبقًا');
          }
        }

        transaction.set(userRef, {
          'uid': credential!.user!.uid,
          'name': name.trim(),
          'email': contactEmail,
          'authEmail': authEmail,
          'phone': normalizedPhone,
          'phoneNormalized': normalizedPhone,
          'photo': '',
          'photoUrl': '',
          'provider': 'password',
          'providers': ['password'],
          'isAdmin': false,
          'accountType': 'user',
          'officeId': '',
          'activeOfficeId': '',
          'accountMode': 'user',
          'isVerified': false,
          'phoneVerified': false,
          'isBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        transaction.set(phoneIndex, {
          'uid': credential.user!.uid,
          'authEmail': authEmail,
          'normalizedValue': normalizedPhone,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (emailIndex != null) {
          transaction.set(emailIndex, {
            'uid': credential.user!.uid,
            'authEmail': authEmail,
            'normalizedValue': contactEmail,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      await _afterSignIn(credential.user);
      return credential;
    } on AuthFailure {
      if (credential?.user != null) {
        await credential!.user!.delete().catchError((_) {});
      }
      rethrow;
    } on FirebaseAuthException catch (error) {
      if (credential?.user != null) {
        await credential!.user!.delete().catchError((_) {});
      }
      throw AuthFailure(_authMessage(error));
    } catch (_) {
      if (credential?.user != null) {
        await credential!.user!.delete().catchError((_) {});
      }
      throw const AuthFailure('تعذر إنشاء الحساب، يرجى المحاولة مجددًا');
    }
  }

  static Future<UserCredential> signIn({
    required String identifier,
    required String password,
  }) async {
    final input = identifier.trim();
    String authEmail;

    if (IraqiPhoneService.looksLikePhone(input)) {
      final phone = IraqiPhoneService.normalize(input);
      if (phone == null) {
        throw const AuthFailure('يرجى إدخال رقم هاتف عراقي صحيح');
      }
      final indexed = await _lookupIdentifier('phone_login_index', phone);
      authEmail = indexed ?? internalEmailForPhone(phone);
      return _signInAndComplete(authEmail, password);
    }

    final email = input.toLowerCase();
    if (!_isValidEmail(email)) {
      throw const AuthFailure(
          'أدخل رقم هاتف عراقي أو بريدًا إلكترونيًا صحيحًا');
    }
    final indexed = await _lookupIdentifier('email_login_index', email);
    authEmail = indexed ?? email;
    return _signInAndComplete(authEmail, password);
  }

  static Future<String?> _lookupIdentifier(
      String collection, String value) async {
    try {
      final snapshot =
          await _firestore.collection(collection).doc(indexId(value)).get();
      return snapshot.data()?['authEmail']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<UserCredential> _signInAndComplete(
      String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _afterSignIn(credential.user);
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_authMessage(error));
    }
  }

  static Future<void> _afterSignIn(User? user) async {
    if (user == null) return;
    final reference = _firestore.collection('users').doc(user.uid);
    final snapshot = await reference.get();
    if (snapshot.exists && snapshot.data()?['isBlocked'] == true) {
      await _auth.signOut();
      throw const AuthFailure('تم إيقاف هذا الحساب، يرجى التواصل مع الإدارة');
    }
    await reference.set(
      {'lastLogin': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await FCMService.saveTokens();
  }

  static bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  static String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'رقم الهاتف مستخدم مسبقًا';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'رقم الهاتف أو البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'weak-password':
        return 'كلمة المرور ضعيفة';
      case 'user-disabled':
        return 'تم إيقاف هذا الحساب، يرجى التواصل مع الإدارة';
      case 'too-many-requests':
        return 'محاولات كثيرة، يرجى الانتظار ثم المحاولة مجددًا';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت ثم حاول مجددًا';
      default:
        return 'تعذر تنفيذ العملية، يرجى المحاولة مجددًا';
    }
  }
}
