import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderType;

  final String message;
  final String imageUrl;
  final String type;

  final double? latitude;
  final double? longitude;

  final bool isRead;

  // حالة الرسالة
  final String status;

  final Timestamp? createdAt;
  final Timestamp? deliveredAt;
  final Timestamp? readAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.message,
    required this.imageUrl,
    required this.type,
    this.latitude,
    this.longitude,
    required this.isRead,
    required this.status,
    this.createdAt,
    this.deliveredAt,
    this.readAt,
  });

  factory MessageModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    return MessageModel(
      id: doc.id,
      senderId: data["senderId"] ?? "",
      senderType: data["senderType"] ?? "user",
      message: data["message"] ?? "",
      imageUrl: data["imageUrl"] ?? "",
      type: data["type"] ?? "text",

      latitude: data["latitude"]?.toDouble(),

      longitude: data["longitude"]?.toDouble(),
      isRead: data["isRead"] ?? false,

      // إذا كانت الرسائل القديمة لا تحتوي على status
      status: data["status"] ?? "sent",

      createdAt: data["createdAt"],
      deliveredAt: data["deliveredAt"],
      readAt: data["readAt"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "senderId": senderId,
      "senderType": senderType,
      "message": message,
      "imageUrl": imageUrl,
      "type": type,
      "latitude": latitude,
      "longitude": longitude,
      "isRead": isRead,
      "status": status,
      "createdAt": createdAt,
      "deliveredAt": deliveredAt,
      "readAt": readAt,
    };
  }
}
