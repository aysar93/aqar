import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  FavoritesService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Stream<DocumentSnapshot<Map<String, dynamic>>> favoriteStream(
      String propertyId) {
    return _db
        .collection("users")
        .doc(_uid)
        .collection("favorites")
        .doc(propertyId)
        .snapshots();
  }

  static Future<bool> isFavorite(String propertyId) async {
    final doc = await _db
        .collection("users")
        .doc(_uid)
        .collection("favorites")
        .doc(propertyId)
        .get();

    return doc.exists;
  }

  static Future<void> toggleFavorite(String propertyId) async {
    if (_uid == null) return;

    final ref = _db
        .collection("users")
        .doc(_uid)
        .collection("favorites")
        .doc(propertyId);

    final doc = await ref.get();

    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }
}
