import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final _users =
      FirebaseFirestore.instance.collection('users');

  static Future<void> createUserIfNotExists(User user) async {

    final doc = _users.doc(user.uid);

    final snapshot = await doc.get();

    if (snapshot.exists) return;

    await doc.set({

  'uid': user.uid,

  'name': user.displayName ?? '',

  'email': user.email ?? '',

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

  'isVerified': true,

  'isBlocked': false,

  'createdAt': FieldValue.serverTimestamp(),

  'lastLogin': FieldValue.serverTimestamp(),

});

  }
}