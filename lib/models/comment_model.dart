import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String text;
  final String userId;
  final String userName;
  final Timestamp createdAt;
  final bool isHidden;
  final bool isPinned;

  CommentModel({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    required this.createdAt,
    required this.isHidden,
    required this.isPinned,
  });

  factory CommentModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    return CommentModel(
      id: doc.id,
      text: data["text"] ?? "",
      userId: data["userId"] ?? "",
      userName: data["userName"] ?? "مستخدم",
      createdAt: data["createdAt"] ?? Timestamp.now(),
      isHidden: data["isHidden"] ?? false,
      isPinned: data["isPinned"] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "text": text,
      "userId": userId,
      "userName": userName,
      "createdAt": createdAt,
      "isHidden": isHidden,
      "isPinned": isPinned,
    };
  }
}
