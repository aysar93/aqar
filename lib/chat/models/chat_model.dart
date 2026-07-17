import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;

  final String lastMessage;
  final String lastSender;

  final int unreadAdmin;
  final int unreadUser;

  final bool isClosed;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  ChatModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.lastMessage,
    required this.lastSender,
    required this.unreadAdmin,
    required this.unreadUser,
    required this.isClosed,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    return ChatModel(
      id: doc.id,
      userId: data["userId"] ?? "",
      userName: data["userName"] ?? "",
      userPhone: data["userPhone"] ?? "",
      lastMessage: data["lastMessage"] ?? "",
      lastSender: data["lastSender"] ?? "",
      unreadAdmin: data["unreadAdmin"] ?? 0,
      unreadUser: data["unreadUser"] ?? 0,
      isClosed: data["isClosed"] ?? false,
      createdAt: data["createdAt"],
      updatedAt: data["updatedAt"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "userId": userId,
      "userName": userName,
      "userPhone": userPhone,
      "lastMessage": lastMessage,
      "lastSender": lastSender,
      "unreadAdmin": unreadAdmin,
      "unreadUser": unreadUser,
      "isClosed": isClosed,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
    };
  }
}