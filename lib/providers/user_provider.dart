import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  String name = "";
  String phone = "";
  String photoUrl = "";
  bool isAdmin = false;
  late final StreamSubscription<User?> _authSubscription;

  UserProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      loadUser();
    });
  }

  Future<void> loadUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      clear();
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;

      name = data["name"] ?? "";
      phone = data["phone"] ?? "";
      photoUrl = data["photoUrl"] ?? data["photo"] ?? "";
      isAdmin = data["isAdmin"] == true;
    } else {
      clear(notify: false);
    }

    notifyListeners();
  }

  void clear({bool notify = true}) {
    name = "";
    phone = "";
    photoUrl = "";
    isAdmin = false;

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadUser();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
