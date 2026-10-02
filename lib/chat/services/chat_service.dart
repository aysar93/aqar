import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// إنشاء أو الحصول على المحادثة
  Future<String> getOrCreateChat(User user) async {
    final uid = user.uid;
    try {
      final cached = await _firestore
          .collection('chats')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (cached.exists) return uid;
    } catch (_) {/* No cached conversation yet. */}

    final doc = await _firestore.collection("chats").doc(uid).get();

    if (doc.exists) {
      return uid;
    }

    await _firestore.collection("chats").doc(uid).set({
      "userId": uid,
      "userName": user.displayName ?? "",
      "userPhone": user.phoneNumber ?? "",
      "lastMessage": "",
      "lastSender": "",
      "unreadAdmin": 0,
      "unreadUser": 0,
      "isClosed": false,
      "isPinned": false,
      "isArchived": false,
      "isMuted": false,
      "isBlocked": false,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    return uid;
  }

  /// إرسال رسالة (للمستخدم والأدمن)
  Future<void> sendMessage({
    required String chatId,
    String message = "",
    String imageUrl = "",
    String imagePath = '',
    String type = "text",
    double? latitude,
    double? longitude,
    required String senderType,
    String replyToId = '',
    Map<String, dynamic>? property,
    String audioUrl = '',
    String audioPath = '',
    int audioSeconds = 0,
  }) async {
    final currentUser = _auth.currentUser;

    if (senderType != "admin" && currentUser == null) {
      throw StateError('سجّل الدخول لإرسال رسالة');
    }

    final senderId = senderType == "admin" ? "admin" : currentUser!.uid;

    if (senderType == "user") {
      final chatDoc = await _firestore.collection("chats").doc(chatId).get();
      if (chatDoc.data()?["isBlocked"] == true) {
        throw StateError('الحساب محظور من المحادثة');
      }
    }

    final messageReference =
        _firestore.collection("chats").doc(chatId).collection("messages").doc();
    final batch = _firestore.batch();
    batch.set(messageReference, {
      "senderId": senderId,
      "senderType": senderType,
      "message": message,
      "imageUrl": imageUrl,
      'imagePath': imagePath,
      "type": type,
      "latitude": latitude,
      "longitude": longitude,
      'replyToId': replyToId,
      if (property != null) 'property': property,
      'audioUrl': audioUrl,
      'audioPath': audioPath,
      'audioSeconds': audioSeconds,
      'authorUid': currentUser?.uid ?? '',
      "isRead": false,
      "status": "sent",
      "createdAt": FieldValue.serverTimestamp(),
      "deliveredAt": null,
      "readAt": null,
    });

    batch.update(_firestore.collection("chats").doc(chatId), {
      'lastMessageId': messageReference.id,
      "lastMessage": type == 'audio'
          ? 'رسالة صوتية'
          : type == 'property'
              ? 'عقار: ${property?['title'] ?? ''}'
              : type == "image"
                  ? "📷 صورة"
                  : type == "location"
                      ? "📍 الموقع"
                      : message,
      "lastSender": senderType,
      "updatedAt": FieldValue.serverTimestamp(),
      "unreadAdmin": senderType == "user"
          ? FieldValue.increment(1)
          : FieldValue.increment(0),
      "unreadUser": senderType == "admin"
          ? FieldValue.increment(1)
          : FieldValue.increment(0),
    });
    await batch.commit();
    unawaited(_notify(
        chatId: chatId,
        messageId: messageReference.id,
        type: type,
        message: message,
        senderType: senderType,
        currentUser: currentUser));
  }

  Future<void> _notify(
      {required String chatId,
      required String messageId,
      required String type,
      required String message,
      required String senderType,
      User? currentUser}) async {
// =======================================================
// إرسال إشعار للطرف الآخر
// =======================================================

    try {
      // نقرأ المحادثة بعد زيادة العداد.
      final chatDoc = await _firestore.collection("chats").doc(chatId).get();

      if (!chatDoc.exists) {
        return;
      }

      final chatData = chatDoc.data() ?? <String, dynamic>{};
      final original = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();
      if (!original.exists || original.data()?['deletedAt'] != null) return;

      final notificationMessage = type == 'audio'
          ? 'رسالة صوتية'
          : type == 'property'
              ? 'بطاقة عقار'
              : type == "image"
                  ? "📷 صورة"
                  : type == "location"
                      ? "📍 تم إرسال موقع"
                      : message;

      // =====================================================
// الأدمن أرسل -> الإشعار للمستخدم صاحب المحادثة
// =====================================================

      if (senderType == "admin") {
        final unreadCount = (chatData["unreadUser"] as num?)?.toInt() ?? 1;

        final title = unreadCount <= 1
            ? "رسالة جديدة من الإدارة"
            : "$unreadCount رسائل جديدة من الإدارة";

        await NotificationService.sendChatNotification(
          userId: chatId,
          chatId: chatId,
          title: title,
          message: notificationMessage,
          unreadCount: unreadCount,
          messageId: messageId,
        );

        return;
      }

      // =====================================================
      // المستخدم أرسل -> الإشعار لكل حساب إداري
      // =====================================================

      if (senderType == "user") {
        final unreadCount = (chatData["unreadAdmin"] as num?)?.toInt() ?? 1;

        final userName = (chatData["userName"] ?? "").toString().trim();

        final title = unreadCount <= 1
            ? userName.isNotEmpty
                ? "رسالة جديدة من $userName"
                : "رسالة جديدة من مستخدم"
            : userName.isNotEmpty
                ? "$unreadCount رسائل جديدة من $userName"
                : "$unreadCount رسائل جديدة";

        final settings =
            await _firestore.collection("settings").doc("app_settings").get();

        final adminUid = (settings.data()?["adminUid"] ?? "").toString().trim();

        if (adminUid.isEmpty) {
          debugPrint("adminUid not configured.");
          return;
        }

// لا نرسل إذا كان المرسل هو الأدمن نفسه
        if (adminUid == currentUser?.uid) {
          return;
        }

        await NotificationService.sendChatNotification(
          userId: adminUid,
          chatId: chatId,
          title: title,
          message: notificationMessage,
          unreadCount: unreadCount,
          messageId: messageId,
        );
      }
    } catch (e, stackTrace) {
      // فشل Push لا يجب أن يفشل إرسال الرسالة نفسها.
      debugPrint(
        "Chat notification error: $e",
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  /// تحويل الرسائل إلى مستلمة
  Future<void> markDelivered({
    required String chatId,
    required String currentUserId,
  }) async {
    final snapshot = await _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final senderId = data["senderId"];

      final status = data["status"] ?? "sent";

      if (senderId != currentUserId && status == "sent") {
        batch.update(
          doc.reference,
          {
            "status": "delivered",
            "deliveredAt": FieldValue.serverTimestamp(),
          },
        );
      }
    }

    await batch.commit();
  }

  /// تحويل الرسائل إلى مقروءة
  Future<void> markRead({
    required String chatId,
    required String currentUserId,
  }) async {
    final snapshot = await _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final senderId = data["senderId"];

      final status = data["status"] ?? "sent";

      if (senderId != currentUserId && status != "read") {
        batch.update(
          doc.reference,
          {
            "status": "read",
            "isRead": true,
            "readAt": FieldValue.serverTimestamp(),
            "deliveredAt": FieldValue.serverTimestamp(),
          },
        );
      }
    }

    await batch.commit();
  }

  /// بث الرسائل
  Stream<QuerySnapshot> messages(String chatId, {int? limit}) {
    final query = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt');
    return (limit == null ? query : query.limitToLast(limit)).snapshots();
  }

  Future<void> deleteForEveryone(String chatId, String messageId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in required');
    final chat = _firestore.collection('chats').doc(chatId);
    final message = chat.collection('messages').doc(messageId);
    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chat);
      final snapshot = await transaction.get(message);
      final data = snapshot.data();
      if (data == null) throw StateError('Message missing');
      if (data['deletedAt'] != null) return;
      final tombstone = <String, dynamic>{
        for (final key in [
          'senderId',
          'senderType',
          'authorUid',
          'createdAt',
          'isRead',
          'status',
          'deliveredAt',
          'readAt'
        ])
          if (data.containsKey(key)) key: data[key],
        'type': 'deleted',
        'message': '',
        'deletedBy': uid,
        'deletedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(message, tombstone);
      if (chatSnapshot.data()?['lastMessageId'] == messageId) {
        transaction.update(chat, {
          'lastMessage': 'تم حذف هذه الرسالة',
          'updatedAt': FieldValue.serverTimestamp()
        });
      }
    });
  }

  Future<void> setTyping(String chatId, bool admin, bool typing) async {
    await _firestore.collection('chats').doc(chatId).update({
      admin ? 'adminTypingAt' : 'userTypingAt':
          typing ? FieldValue.serverTimestamp() : null,
    });
  }

  /// بث المحادثات للأدمن
  Stream<QuerySnapshot> chats() {
    return _firestore
        .collection("chats")
        .orderBy(
          "updatedAt",
          descending: true,
        )
        .snapshots();
  }

  /// تصفير عداد المستخدم
  Future<void> markUserRead(
    String chatId,
  ) async {
    await _firestore.collection("chats").doc(chatId).update({
      "unreadUser": 0,
    });

    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return;
    }

    await NotificationService.markChatNotificationRead(
      userId: currentUser.uid,
      chatId: chatId,
    );
  }

  /// تصفير عداد الأدمن
  Future<void> markAdminRead(
    String chatId,
  ) async {
    await _firestore.collection("chats").doc(chatId).update({
      "unreadAdmin": 0,
    });

    final currentAdmin = _auth.currentUser;

    if (currentAdmin == null) {
      return;
    }

    await NotificationService.markChatNotificationRead(
      userId: currentAdmin.uid,
      chatId: chatId,
    );
  }

  /// إغلاق أو فتح المحادثة
  Future<void> setClosed(
    String chatId,
    bool value,
  ) async {
    await _firestore.collection("chats").doc(chatId).update({
      "isClosed": value,
    });
  }

  /// حذف المحادثة
  Future<void> deleteChat(String chatId) async {
    await _firestore.collection("chats").doc(chatId).delete();
  }
}
