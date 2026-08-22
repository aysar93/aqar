import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';
import 'password_auth_service.dart';
import 'iraqi_phone_service.dart';

class UserService {
  static final _users = FirebaseFirestore.instance.collection('users');

  static Future<void> createUserIfNotExists(User user) async {
    final doc = _users.doc(user.uid);

    final snapshot = await doc.get();

    if (snapshot.exists) return;

    await doc.set({
      'uid': user.uid,

      'name': user.displayName ?? '',

      'email': user.email ?? '',

      'authEmail': user.email ?? '',

      'phone': user.phoneNumber ?? '',

      'photo': user.photoURL ?? '',

      'provider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',

      // للتوافق مع النظام الحالي
      'isAdmin': false,

      // النظام الجديد
      'accountType': 'user',

      'officeId': '',

      'activeOfficeId': '',

      'accountMode': 'user',

      'isVerified': true,

      'isBlocked': false,

      'createdAt': FieldValue.serverTimestamp(),

      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> createOrUpdateSocialUser(User user) async {
    final doc = _users.doc(user.uid);
    final snapshot = await doc.get();
    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'social';

    if (!snapshot.exists) {
      await doc.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'authEmail': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'phoneNormalized': user.phoneNumber ?? '',
        'photo': user.photoURL ?? '',
        'photoUrl': user.photoURL ?? '',
        'provider': provider,
        'providers': [provider],
        'isAdmin': false,
        'accountType': 'user',
        'officeId': '',
        'activeOfficeId': '',
        'accountMode': 'user',
        'isVerified': true,
        'phoneVerified': user.phoneNumber?.isNotEmpty == true,
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final providers = Set<String>.from(
      (data['providers'] as List<dynamic>? ?? const <dynamic>[]).map(
        (value) => value.toString(),
      ),
    )..add(provider);
    await doc.set({
      if ((data['name'] ?? '').toString().isEmpty && user.displayName != null)
        'name': user.displayName,
      if ((data['email'] ?? '').toString().isEmpty && user.email != null)
        'email': user.email,
      if ((data['photoUrl'] ?? data['photo'] ?? '').toString().isEmpty &&
          user.photoURL != null) ...{
        'photo': user.photoURL,
        'photoUrl': user.photoURL,
      },
      'providers': providers.toList(),
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> completeSignIn(User user) async {
    final doc = await _users.doc(user.uid).get();
    if (doc.data()?['isBlocked'] == true) {
      await FirebaseAuth.instance.signOut();
      throw const AuthFailure('تم إيقاف هذا الحساب، يرجى التواصل مع الإدارة');
    }
    await _users.doc(user.uid).set({
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await FCMService.saveTokens();
    if (doc.data()?['isAdmin'] == true) {
      try {
        await _migrateLegacyLoginIndexes();
      } catch (_) {
        // لا نمنع دخول المدير إذا تعذر الترحيل؛ سيُعاد عند الدخول القادم.
      }
    }
  }

  static Future<void> _migrateLegacyLoginIndexes() async {
    final marker = FirebaseFirestore.instance
        .collection('settings')
        .doc('auth_login_index_migration');
    final markerSnapshot = await marker.get();
    if ((markerSnapshot.data()?['version'] ?? 0) >= 1) return;

    final users = await _users.get();
    // كل مستخدم قد ينتج عمليتي كتابة؛ نبقى دون حد 500 للعملية الدفعية.
    const chunkSize = 200;
    for (var start = 0; start < users.docs.length; start += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      final end = (start + chunkSize < users.docs.length)
          ? start + chunkSize
          : users.docs.length;
      for (final document in users.docs.sublist(start, end)) {
        final data = document.data();
        final authEmail = (data['authEmail'] ?? data['email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (authEmail.isEmpty) continue;

        final phone = IraqiPhoneService.normalize(
          (data['phoneNormalized'] ?? data['phone'] ?? '').toString(),
        );
        if (phone != null) {
          final phoneRef = FirebaseFirestore.instance
              .collection('phone_login_index')
              .doc(PasswordAuthService.indexId(phone));
          batch.set(
              phoneRef,
              {
                'uid': document.id,
                'authEmail': authEmail,
                'normalizedValue': phone,
                'migratedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }

        final contactEmail =
            (data['email'] ?? '').toString().trim().toLowerCase();
        if (contactEmail.isNotEmpty) {
          final emailRef = FirebaseFirestore.instance
              .collection('email_login_index')
              .doc(PasswordAuthService.indexId(contactEmail));
          batch.set(
              emailRef,
              {
                'uid': document.id,
                'authEmail': authEmail,
                'normalizedValue': contactEmail,
                'migratedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
      }
      await batch.commit();
    }

    await marker.set({
      'version': 1,
      'completedAt': FieldValue.serverTimestamp(),
      'usersScanned': users.size,
    });
  }
}
