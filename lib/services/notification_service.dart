import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  NotificationService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================
  // إرسال إشعار
  // =========================================================

  static Future<void> sendNotification({
    required String title,
    required String message,
    required String type,
    String target = 'all',
    String userId = '',

    // الوجهة المرتبطة بالإشعار
    String propertyId = '',
    String officeId = '',
    String chatId = '',
    String deliveryType = 'external',
    Map<String, dynamic>? extraData,
  }) async {
    final normalizedDeliveryType =
        deliveryType.trim().toLowerCase() == 'internal'
            ? 'internal'
            : 'external';
    final notificationData = <String, dynamic>{
      'title': title,
      'message': message,
      'type': type,
      'target': 'user',
      'deliveryType': normalizedDeliveryType,
      'readBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      if (propertyId.isNotEmpty) 'propertyId': propertyId,
      if (officeId.isNotEmpty) 'officeId': officeId,
      if (chatId.isNotEmpty) 'chatId': chatId,
      if (extraData != null) ...extraData,
    };

    // =======================================================
    // مستخدم واحد
    // =======================================================

    if (target == 'user') {
      if (userId.trim().isEmpty) {
        debugPrint(
          'NotificationService: userId is empty.',
        );
        return;
      }

      final notificationRef = _firestore.collection('notifications').doc();

      await notificationRef.set({
        ...notificationData,
        'notificationId': notificationRef.id,
        'userId': userId,
      });

      if (normalizedDeliveryType == 'external') {
        await sendPush(
          title: title,
          message: message,
          type: type,
          target: 'user',
          userId: userId,
          propertyId: propertyId,
          officeId: officeId,
          chatId: chatId,
          deliveryType: normalizedDeliveryType,
          notificationId: notificationRef.id,
          extraData: extraData,
        );
      }

      return;
    }

    // =======================================================
    // جميع المستخدمين
    // =======================================================

    final users = await _firestore.collection('users').get();

    WriteBatch batch = _firestore.batch();
    var operations = 0;
    final broadcastId = 'broadcast_${DateTime.now().microsecondsSinceEpoch}';

    Future<void> commitBatch() async {
      if (operations == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      operations = 0;
    }

    for (final user in users.docs) {
      final doc = _firestore.collection('notifications').doc();

      batch.set(
        doc,
        {
          ...notificationData,
          'notificationId': doc.id,
          'broadcastId': broadcastId,
          'userId': user.id,
        },
      );

      operations++;

      if (operations >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();

    if (normalizedDeliveryType == 'external') {
      await sendPush(
        title: title,
        message: message,
        type: type,
        target: 'all',
        propertyId: propertyId,
        officeId: officeId,
        chatId: chatId,
        deliveryType: normalizedDeliveryType,
        notificationId: broadcastId,
        extraData: extraData,
      );
    }
  }

  // =========================================================
  // إشعار داخلي لمتابعي مكتب عند نشر عقار
  // لا يستخدم FCM أو OneSignal أو أي Push خارجي.
  // =========================================================

  static Future<int> notifyOfficeFollowersOfNewProperty({
    required String officeId,
    required String propertyId,
    required String propertyTitle,
    String officeName = '',
  }) async {
    final normalizedOfficeId = officeId.trim();
    final normalizedPropertyId = propertyId.trim();

    if (normalizedOfficeId.isEmpty || normalizedPropertyId.isEmpty) {
      return 0;
    }

    final followersSnapshot = await _firestore
        .collection('office_followers')
        .where(
          'officeId',
          isEqualTo: normalizedOfficeId,
        )
        .where(
          'isActive',
          isEqualTo: true,
        )
        .get();

    if (followersSnapshot.docs.isEmpty) {
      return 0;
    }

    // Firestore Batch يسمح بحد أقصى 500 عملية.
    // نقسم المتابعين إلى دفعات حتى يعمل النظام مع أعداد كبيرة.
    var createdCount = 0;
    WriteBatch batch = _firestore.batch();
    var batchOperations = 0;

    Future<void> commitBatch() async {
      if (batchOperations == 0) return;

      await batch.commit();

      batch = _firestore.batch();
      batchOperations = 0;
    }

    for (final followerDoc in followersSnapshot.docs) {
      final follower = followerDoc.data();
      final userId = (follower['userId'] ?? '').toString().trim();

      if (userId.isEmpty) continue;

      final notificationRef = _firestore.collection('notifications').doc();

      batch.set(
        notificationRef,
        {
          'title': officeName.trim().isEmpty
              ? 'عقار جديد'
              : 'عقار جديد من $officeName',
          'message': propertyTitle.trim().isEmpty
              ? 'تم نشر عقار جديد من المكتب الذي تتابعه.'
              : 'تم نشر عقار جديد: ${propertyTitle.trim()}',
          'type': 'property',
          'target': 'user',
          'deliveryType': 'internal',
          'userId': userId,
          'propertyId': normalizedPropertyId,
          'officeId': normalizedOfficeId,
          'officeName': officeName.trim(),
          'readBy': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'isOfficeFollowerNotification': true,
        },
      );

      createdCount++;
      batchOperations++;

      if (batchOperations >= 500) {
        await commitBatch();
      }
    }

    await commitBatch();

    return createdCount;
  }

  // =========================================================
// إشعار المحادثة - وثيقة واحدة لكل محادثة ولكل مستلم
// =========================================================

  static Future<void> sendChatNotification({
    required String userId,
    required String chatId,
    required String title,
    required String message,
    required int unreadCount,
  }) async {
    if (userId.trim().isEmpty || chatId.trim().isEmpty) {
      debugPrint(
        'NotificationService: '
        'Cannot send chat notification - userId/chatId is empty.',
      );
      return;
    }

    // وثيقة ثابتة لنفس المحادثة ونفس المستلم.
    // الرسائل الجديدة تحدثها بدل إنشاء إشعار جديد.
    final notificationId = 'chat_${chatId}_$userId';

    final notificationRef =
        _firestore.collection('notifications').doc(notificationId);

    await notificationRef.set({
      'title': title,
      'message': message,
      'type': 'chat_message',
      'target': 'user',
      'userId': userId,
      'chatId': chatId,
      'unreadCount': unreadCount,
      'readBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await sendPush(
      title: title,
      message: message,
      type: 'chat_message',
      target: 'user',
      userId: userId,
      chatId: chatId,
      deliveryType: 'external',
      notificationId: notificationId,
      extraData: {
        'unreadCount': unreadCount,
        'collapseId': 'chat_$chatId',
      },
    );
  }

// =========================================================
// تعليم إشعار المحادثة كمقروء
// =========================================================

  static Future<void> markChatNotificationRead({
    required String userId,
    required String chatId,
  }) async {
    if (userId.trim().isEmpty || chatId.trim().isEmpty) {
      return;
    }

    final notificationId = 'chat_${chatId}_$userId';

    final ref = _firestore.collection('notifications').doc(notificationId);

    final doc = await ref.get();

    if (!doc.exists) {
      return;
    }

    await ref.update({
      'unreadCount': 0,
      'readBy': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // إرسال Push عبر Railway
  // =========================================================

  static Future<void> sendPush({
    required String title,
    required String message,
    required String type,
    required String target,
    String userId = '',
    String propertyId = '',
    String officeId = '',
    String chatId = '',
    String deliveryType = 'external',
    String notificationId = '',
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type,
        'deliveryType': deliveryType,
        if (notificationId.isNotEmpty) 'notificationId': notificationId,
        if (propertyId.isNotEmpty) 'propertyId': propertyId,
        if (officeId.isNotEmpty) 'officeId': officeId,
        if (chatId.isNotEmpty) 'chatId': chatId,
        if (extraData != null) ...extraData,
      };

      final payload = <String, dynamic>{
        'title': title,
        'message': message,
        'type': type,
        'target': target,
        'userId': userId,
        'deliveryType': deliveryType,
        if (notificationId.isNotEmpty) 'notificationId': notificationId,

        if (propertyId.isNotEmpty) 'propertyId': propertyId,

        if (officeId.isNotEmpty) 'officeId': officeId,

        if (chatId.isNotEmpty) 'chatId': chatId,

        // Payload موحد يمكن لخادم vercel تمريره
        // إلى OneSignal / FCM.
        'data': data,
      };

      final response = await http.post(
        Uri.parse(
          'https://notification-server-henna.vercel.app/send',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint(
        '========== Railway ==========',
      );

      debugPrint(
        'Status: ${response.statusCode}',
      );

      debugPrint(
        'Body: ${response.body}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'NotificationService: '
          'Push request failed.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '========== PUSH ERROR ==========',
      );

      debugPrint(
        e.toString(),
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  // =========================================================
  // إشعارات المستخدم
  // =========================================================

  static Stream<QuerySnapshot<Map<String, dynamic>>> userNotifications(
    String uid,
  ) {
    return _firestore
        .collection('notifications')
        .where(
          'userId',
          isEqualTo: uid,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }
}
