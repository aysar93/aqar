import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/notification_service.dart';
import '../../subscription/models/subscription_package_model.dart';
import '../models/office_subscription_model.dart';

/// A new gift preserves remaining time only when extending the same package.
OfficeSubscriptionModel buildGiftSubscription({
  required String id,
  required String officeId,
  required String ownerId,
  required SubscriptionPackageModel package,
  required DateTime now,
  OfficeSubscriptionModel? current,
}) {
  if (!package.isActive || package.durationDays <= 0) {
    throw StateError('الباقة غير متاحة أو مدتها غير صحيحة');
  }
  final preservesTime = current?.status == 'active' &&
      current?.packageId == package.id &&
      current?.endDate?.isAfter(now) == true;
  final endBase = preservesTime ? current!.endDate! : now;
  return OfficeSubscriptionModel(
    id: id,
    officeId: officeId,
    ownerId: ownerId,
    packageId: package.id,
    packageName: package.name,
    durationDays: package.durationDays,
    startDate: now,
    endDate: endBase.add(Duration(days: package.durationDays)),
    status: 'active',
    price: 0,
    currency: package.currency,
    paymentStatus: 'paid',
    paymentMethod: 'gift',
    previousSubscriptionId: current?.id,
    maxProperties: package.maxProperties ?? 0,
    maxFeaturedProperties: package.maxFeaturedProperties ?? 0,
    canFeatureProperties: package.featuredPropertiesEnabled,
    canAppearInFeaturedOffices: package.featuredOfficeEnabled,
    canUseAdvancedStatistics: package.statisticsEnabled,
    createdAt: now,
    updatedAt: now,
  );
}

class OfficeSubscriptionGiftService {
  OfficeSubscriptionGiftService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> grant({
    required String officeId,
    required String packageId,
    required String expectedSubscriptionId,
  }) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) throw StateError('يرجى تسجيل الدخول');

    final officeRef = _firestore.collection('offices').doc(officeId);
    final subscriptions = _firestore.collection('office_subscriptions');
    final history =
        await subscriptions.where('officeId', isEqualTo: officeId).get();
    final giftRef = subscriptions.doc();
    final notificationRef = _firestore.collection('notifications').doc();
    String ownerId = '';
    String message = '';
    const title = 'باقة اشتراك هدية من الإدارة';

    // The office pointer serializes competing gifts. Notification and entitlements
    // commit together, so a retry cannot grant twice or lose the in-app notice.
    await _firestore.runTransaction((transaction) async {
      final admin =
          await transaction.get(_firestore.collection('users').doc(adminUid));
      if (admin.data()?['isAdmin'] != true) {
        throw StateError('إهداء الباقات متاح للإدارة فقط');
      }
      final office = await transaction.get(officeRef);
      final packageDoc = await transaction
          .get(_firestore.collection('subscription_packages').doc(packageId));
      if (!office.exists || !packageDoc.exists) {
        throw StateError('المكتب أو الباقة لم يعد موجودًا');
      }
      final data = office.data()!;
      ownerId = (data['ownerId'] ?? '').toString().trim();
      if (ownerId.isEmpty) {
        throw StateError('لا يوجد صاحب حساب مرتبط بهذا المكتب');
      }
      final currentId = (data['subscriptionId'] ?? '').toString();
      if (currentId != expectedSubscriptionId) {
        throw StateError('تغير اشتراك المكتب، أغلق النافذة وأعد المحاولة');
      }
      final refs = {for (final doc in history.docs) doc.id: doc.reference};
      if (currentId.isNotEmpty) refs[currentId] = subscriptions.doc(currentId);
      final records = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs.values) {
        records.add(await transaction.get(ref));
      }
      final live = records
          .where((doc) => doc.exists)
          .map(OfficeSubscriptionModel.fromFirestore)
          .where((sub) =>
              sub.officeId == officeId &&
              (sub.status == 'active' || sub.status == 'suspended'))
          .toList()
        ..sort((a, b) => (b.endDate ?? DateTime(1970))
            .compareTo(a.endDate ?? DateTime(1970)));
      OfficeSubscriptionModel? current;
      for (final sub in live) {
        if (sub.id == currentId) current = sub;
      }
      current ??= live.isEmpty ? null : live.first;
      final now = DateTime.now();
      final package = SubscriptionPackageModel.fromFirestore(packageDoc);
      final gift = buildGiftSubscription(
          id: giftRef.id,
          officeId: officeId,
          ownerId: ownerId,
          package: package,
          now: now,
          current: current);
      message =
          'أهدتك الإدارة باقة ${package.name} لمدة ${package.durationDays} يومًا لمكتب ${data['name'] ?? ''}. تم تفعيلها الآن.';

      for (final sub in live) {
        transaction.update(subscriptions.doc(sub.id), {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(giftRef, {
        ...gift.toFirestore(),
        'giftedBy': adminUid,
        'giftedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(officeRef, {
        'subscriptionId': gift.id,
        'subscriptionStatus': gift.status,
        'subscriptionStartDate': Timestamp.fromDate(gift.startDate!),
        'subscriptionEndDate': Timestamp.fromDate(gift.endDate!),
        'maxProperties': gift.maxProperties,
        'maxFeaturedProperties': gift.maxFeaturedProperties,
        'canFeatureProperties': gift.canFeatureProperties,
        'canAppearInFeaturedOffices': gift.canAppearInFeaturedOffices,
        'canUseAdvancedStatistics': gift.canUseAdvancedStatistics,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationRef, {
        'notificationId': notificationRef.id,
        'title': title,
        'message': message,
        'type': 'office_notification',
        'target': 'user',
        'userId': ownerId,
        'officeId': officeId,
        'subscriptionId': gift.id,
        'deliveryType': 'external',
        'readBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    unawaited(NotificationService.sendPush(
        title: title,
        message: message,
        type: 'office_notification',
        target: 'user',
        userId: ownerId,
        officeId: officeId,
        notificationId: notificationRef.id));
  }
}
