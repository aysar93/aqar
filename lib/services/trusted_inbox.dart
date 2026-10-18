import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Next-release contract. No effect on existing builds unless explicitly enabled.
class TrustedInbox {
  static const enabled =
      bool.fromEnvironment('TRUSTED_INBOX', defaultValue: false);
  static String get visibleCollection =>
      enabled ? 'trusted_notifications' : 'notifications';
  static String get writeCollection =>
      enabled ? 'notification_requests' : 'notifications';
  static Map<String, dynamic> get requestFields => enabled
      ? {
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'requestVersion': 1
        }
      : {};

  static CollectionReference<Map<String, dynamic>> collection(
          {bool history = false}) =>
      FirebaseFirestore.instance
          .collection(history ? 'notification_history' : visibleCollection);

  static Query<Map<String, dynamic>> forUser(String uid,
      {bool history = false}) {
    Query<Map<String, dynamic>> query =
        collection(history: history).where('userId', isEqualTo: uid);
    if (enabled || history) {
      query = query.where('isDismissed', isEqualTo: false);
    }
    return query;
  }

  static Query<Map<String, dynamic>> managementQuery() {
    Query<Map<String, dynamic>> query = collection();
    if (enabled) query = query.where('isDismissed', isEqualTo: false);
    return query.orderBy('createdAt', descending: true);
  }

  static Future<void> submit(Map<String, dynamic> request) async {
    if (!enabled) throw StateError('Trusted inbox is not enabled');
    await FirebaseFirestore.instance.collection(writeCollection).add({
      ...request,
      ...requestFields,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> dismiss(DocumentReference<Map<String, dynamic>> ref,
      {bool history = false}) async {
    if (enabled || history) {
      await ref.update({
        'isDismissed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  static Future<void> markEventRead(Map<String, dynamic> payload) async {
    if (!enabled) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final eventId = payload['eventId'];
    if (uid == null ||
        payload['userId'] != uid ||
        eventId is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(eventId)) {
      return;
    }
    try {
      final ref = collection().doc('event_$eventId');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final item = await transaction.get(ref);
        if (!item.exists || item.data()?['userId'] != uid) return;
        transaction.update(ref, {
          'readBy': FieldValue.arrayUnion([uid]),
          'isRead': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      // Offline acknowledgement may retry through the inbox; never block a tap.
    }
  }
}
