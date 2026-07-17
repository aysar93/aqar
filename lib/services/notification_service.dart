import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
class NotificationService {
  NotificationService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static Future<void> sendNotification({
  required String title,
  required String message,
  required String type,
  String target = "all",
  String userId = "",
}) async {
  // إشعار لمستخدم واحد
  if (target == "user") {
  await _firestore.collection("notifications").add({
    "title": title,
    "message": message,
    "type": type,
    "target": "user",
    "userId": userId,
    "readBy": [],
    "createdAt": FieldValue.serverTimestamp(),
  });

  await sendPush(
    title: title,
    message: message,
    target: "user",
    userId: userId,
  );

  return;
}

  // إشعار لجميع المستخدمين
  final users =
      await _firestore.collection("users").get();

  final batch = _firestore.batch();

  for (final user in users.docs) {
    final doc =
        _firestore.collection("notifications").doc();

    batch.set(doc, {
      "title": title,
      "message": message,
      "type": type,
      "target": "user",
      "userId": user.id,
      "readBy": [],
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  await sendPush(
  title: title,
  message: message,
  target: "all",
);
}

static Future<void> sendPush({
  required String title,
  required String message,
  required String target,
  String userId = "",
}) async {
  try {
    final response = await http.post(
      Uri.parse(
        "https://notificationserver-production-84bc.up.railway.app/send",
      ),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "message": message,
        "target": target,
        "userId": userId,
      }),
    );

    print("========== Railway ==========");
    print(response.statusCode);
    print(response.body);

  } catch (e) {
    print("========== ERROR ==========");
    print(e);
  }
}

  static Stream<QuerySnapshot<Map<String, dynamic>>>
    userNotifications(String uid) {
  return _firestore
      .collection("notifications")
      .where(
        "userId",
        isEqualTo: uid,
      )
      .orderBy(
        "createdAt",
        descending: true,
      )
      .snapshots();
}

}