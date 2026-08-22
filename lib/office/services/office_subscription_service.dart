import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/office_subscription_model.dart';
import '../../subscription/models/subscription_package_model.dart';
import '../../subscription/models/subscription_payment_model.dart';

/// خدمة اشتراكات المكاتب.
///
/// القاعدة الأساسية:
/// - صاحب المكتب ينشئ "طلب اشتراك" فقط.
/// - الطلب يبقى pending ولا يتم تفعيله من التطبيق.
/// - الإدارة هي التي تفعّل أو توقف أو تلغي الاشتراك.
/// - عند التفعيل فقط تتم مزامنة حالة الاشتراك مع مستند المكتب.
class OfficeSubscriptionService {
  OfficeSubscriptionService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// مراقبة الباقات المفعّلة التي تسمح الإدارة بالاشتراك بها.
  ///
  /// يتم الفرز داخل Dart لتجنب الحاجة إلى Composite Index في Firestore.
  Stream<List<SubscriptionPackageModel>> watchActivePackages() {
    return _firestore
        .collection('subscription_packages')
        .snapshots()
        .map((snapshot) {
      final packages = snapshot.docs
          .map(SubscriptionPackageModel.fromFirestore)
          .where((package) => package.isActive)
          .toList();

      packages.sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }

        final aDate = a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return aDate.compareTo(bDate);
      });

      return packages;
    });
  }

  CollectionReference<Map<String, dynamic>> get _offices =>
      _firestore.collection('offices');

  CollectionReference<Map<String, dynamic>> get _subscriptions =>
      _firestore.collection('office_subscriptions');

  /// لوحة الإدارة تحتاج بيانات الاشتراك مع اسم المكتب وصورته الفعليين.
  /// تتم عملية الربط في الذاكرة بين مجموعتي offices وoffice_subscriptions
  /// حتى تبقى بنية Firestore وواجهات الإنشاء الحالية دون تغيير.
  Stream<List<OfficeSubscriptionAdminItem>> watchAdminSubscriptions({
    String? officeId,
  }) {
    late final StreamController<List<OfficeSubscriptionAdminItem>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        subscriptionsListener;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? officesListener;
    List<OfficeSubscriptionModel>? subscriptions;
    Map<String, Map<String, dynamic>>? offices;

    void emit() {
      final currentSubscriptions = subscriptions;
      final currentOffices = offices;
      if (currentSubscriptions == null || currentOffices == null) return;

      final result = currentSubscriptions.map((subscription) {
        final office = currentOffices[subscription.officeId];
        final officeName = _firstText(office, const ['name', 'officeName']);
        final officeImage = _firstText(
          office,
          const ['logoUrl', 'coverImageUrl', 'imageUrl'],
        );
        return OfficeSubscriptionAdminItem(
          subscription: subscription,
          officeName: officeName,
          officeImageUrl: officeImage,
          officeExists: office != null,
        );
      }).toList()
        ..sort((a, b) {
          final aDate = a.subscription.updatedAt ??
              a.subscription.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.subscription.updatedAt ??
              b.subscription.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
      if (!controller.isClosed) controller.add(result);
    }

    controller = StreamController<List<OfficeSubscriptionAdminItem>>(
      onListen: () {
        Query<Map<String, dynamic>> query = _subscriptions;
        final normalizedOfficeId = officeId?.trim() ?? '';
        if (normalizedOfficeId.isNotEmpty) {
          query = query.where('officeId', isEqualTo: normalizedOfficeId);
        }
        subscriptionsListener = query.snapshots().listen(
          (snapshot) {
            subscriptions = snapshot.docs
                .map(OfficeSubscriptionModel.fromFirestore)
                .toList();
            emit();
          },
          onError: controller.addError,
        );
        officesListener = _offices.snapshots().listen(
          (snapshot) {
            offices = {
              for (final document in snapshot.docs)
                document.id: document.data(),
            };
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subscriptionsListener?.cancel();
        await officesListener?.cancel();
      },
    );
    return controller.stream;
  }

  /// حذف فعلي لسجل الاشتراك وطلبات الدفع التابعة له.
  /// إذا كان المكتب يشير إلى هذا الاشتراك تحديدًا، تُمسح بيانات مزامنته فقط؛
  /// ولا يتأثر أي اشتراك أحدث للمكتب.
  Future<void> deleteSubscription({
    required String subscriptionId,
  }) async {
    final normalizedId = subscriptionId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('معرّف الاشتراك غير صالح');
    }

    final subscriptionRef = _subscriptions.doc(normalizedId);
    final paymentSnapshot = await _firestore
        .collection('subscription_payments')
        .where('subscriptionId', isEqualTo: normalizedId)
        .get();

    await _firestore.runTransaction((transaction) async {
      final subscriptionSnapshot = await transaction.get(subscriptionRef);
      if (!subscriptionSnapshot.exists) {
        throw StateError('الاشتراك غير موجود أو حُذف مسبقًا');
      }

      final subscription =
          OfficeSubscriptionModel.fromFirestore(subscriptionSnapshot);
      final officeRef = _offices.doc(subscription.officeId);
      final officeSnapshot = await transaction.get(officeRef);

      for (final payment in paymentSnapshot.docs) {
        transaction.delete(payment.reference);
      }
      transaction.delete(subscriptionRef);

      if (officeSnapshot.exists) {
        final officeData = officeSnapshot.data() ?? const <String, dynamic>{};
        if (officeData['subscriptionId']?.toString() == normalizedId) {
          transaction.update(officeRef, {
            'subscriptionId': FieldValue.delete(),
            'subscriptionStatus': 'none',
            'subscriptionStartDate': null,
            'subscriptionEndDate': null,
            'maxProperties': FieldValue.delete(),
            'maxFeaturedProperties': FieldValue.delete(),
            'canFeatureProperties': FieldValue.delete(),
            'canAppearInFeaturedOffices': FieldValue.delete(),
            'canUseAdvancedStatistics': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  static String _firstText(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) return '';
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  // ═════════════════════════════════════════════
  // جلب أحدث سجل اشتراك للمكتب
  // ═════════════════════════════════════════════

  Future<OfficeSubscriptionModel?> getOfficeSubscription(
    String officeId,
  ) async {
    if (officeId.trim().isEmpty) {
      return null;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return null;
    }

    final snapshot = await _subscriptions
        .where('officeId', isEqualTo: officeId.trim())
        .where('ownerId', isEqualTo: currentUser.uid)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final models =
        snapshot.docs.map(OfficeSubscriptionModel.fromFirestore).toList();

    models.sort((a, b) {
      int priority(String status) {
        switch (status) {
          case 'active':
            return 0;
          case 'pending':
            return 1;
          case 'expired':
            return 2;
          case 'suspended':
            return 3;
          case 'cancelled':
            return 4;
          default:
            return 5;
        }
      }

      final priorityCompare = priority(a.status).compareTo(priority(b.status));

      if (priorityCompare != 0) {
        return priorityCompare;
      }

      final aDate =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      final bDate =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return models.first;
  }

  // ═════════════════════════════════════════════
  // جلب اشتراك محدد بواسطة subscriptionId
  // ═════════════════════════════════════════════

  Future<OfficeSubscriptionModel?> getSubscriptionById(
    String subscriptionId,
  ) async {
    if (subscriptionId.trim().isEmpty) {
      return null;
    }

    final doc = await _subscriptions.doc(subscriptionId).get();

    if (!doc.exists) {
      return null;
    }

    return OfficeSubscriptionModel.fromFirestore(doc);
  }

  // ═════════════════════════════════════════════
  // مراقبة اشتراك المكتب
  // ═════════════════════════════════════════════

  Stream<OfficeSubscriptionModel?> watchOfficeSubscription(
    String officeId,
  ) {
    return _subscriptions
        .where('officeId', isEqualTo: officeId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final models =
          snapshot.docs.map(OfficeSubscriptionModel.fromFirestore).toList();

      models.sort((a, b) {
        int priority(String status) {
          switch (status) {
            case 'active':
              return 0;
            case 'pending':
              return 1;
            case 'expired':
              return 2;
            case 'suspended':
              return 3;
            case 'cancelled':
              return 4;
            default:
              return 5;
          }
        }

        final priorityCompare =
            priority(a.status).compareTo(priority(b.status));

        if (priorityCompare != 0) {
          return priorityCompare;
        }

        final aDate = a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      return models.first;
    });
  }

  // ═════════════════════════════════════════════
  // هل يوجد طلب اشتراك قيد المراجعة؟
  // ═════════════════════════════════════════════

  Future<bool> hasPendingSubscriptionRequest({
    required String officeId,
    required String ownerId,
  }) async {
    final snapshot = await _subscriptions
        .where('officeId', isEqualTo: officeId)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // ═════════════════════════════════════════════
  // إنشاء طلب اشتراك من صاحب المكتب
  // ═════════════════════════════════════════════

  Future<String> createSubscriptionRequest({
    required String officeId,
    required String ownerId,
    required String packageId,
    required String packageName,
    required int durationDays,
    required double price,
    String currency = 'IQD',

    // حدود ومزايا الباقة
    int maxProperties = 0,
    int maxFeaturedProperties = 0,
    bool canFeatureProperties = false,
    bool canAppearInFeaturedOffices = false,
    bool canUseAdvancedStatistics = false,
  }) async {
    if (officeId.trim().isEmpty) {
      throw ArgumentError('معرّف المكتب غير صالح');
    }

    if (ownerId.trim().isEmpty) {
      throw ArgumentError('معرّف صاحب المكتب غير صالح');
    }

    if (packageId.trim().isEmpty) {
      throw ArgumentError('معرّف الباقة غير صالح');
    }

    if (durationDays <= 0) {
      throw ArgumentError('مدة الاشتراك يجب أن تكون أكبر من صفر');
    }

    if (price < 0) {
      throw ArgumentError('سعر الباقة غير صالح');
    }

    // تحقق إضافي من ملكية المكتب.
    // يجب أيضًا حماية ذلك بقواعد Firestore.
    final officeSnapshot = await _offices.doc(officeId).get();

    if (!officeSnapshot.exists) {
      throw StateError('المكتب غير موجود');
    }

    final officeData = officeSnapshot.data() ?? {};
    final storedOwnerId = officeData['ownerId'] as String? ?? '';

    if (storedOwnerId != ownerId) {
      throw StateError('لا تملك صلاحية إنشاء طلب اشتراك لهذا المكتب');
    }

    final pendingExists = await hasPendingSubscriptionRequest(
      officeId: officeId,
      ownerId: ownerId,
    );

    if (pendingExists) {
      throw StateError('يوجد طلب اشتراك قيد المراجعة لهذا المكتب بالفعل');
    }

    final now = DateTime.now();
    final reference = _subscriptions.doc();

    final subscription = OfficeSubscriptionModel(
      id: reference.id,
      officeId: officeId,
      ownerId: ownerId,
      packageId: packageId,
      packageName: packageName,
      durationDays: durationDays,
      price: price,
      currency: currency,
      paymentStatus: 'pending',
      status: 'pending',

      // تبدأ المدة عند موافقة الإدارة
      startDate: null,
      endDate: null,

      // حدود الباقة
      maxProperties: maxProperties,
      maxFeaturedProperties: maxFeaturedProperties,
      canFeatureProperties: canFeatureProperties,
      canAppearInFeaturedOffices: canAppearInFeaturedOffices,
      canUseAdvancedStatistics: canUseAdvancedStatistics,

      createdAt: now,
      updatedAt: now,
    );

    await reference.set(subscription.toFirestore());

    return reference.id;
  }

  // ═════════════════════════════════════════════
  // إنشاء اشتراك مباشر - للإدارة/العمليات الداخلية فقط
  // ═════════════════════════════════════════════

  Future<String> createSubscription({
    required String officeId,
    required String ownerId,
    required String packageId,
    required String packageName,
    required int durationDays,
    required double price,
    String currency = 'IQD',
    String paymentStatus = 'pending',
    String subscriptionStatus = 'pending',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (durationDays <= 0) {
      throw ArgumentError('مدة الاشتراك يجب أن تكون أكبر من صفر');
    }

    if (ownerId.trim().isEmpty) {
      throw ArgumentError('معرّف صاحب المكتب غير صالح');
    }

    final now = startDate ?? DateTime.now();

    final calculatedEndDate = endDate ??
        (subscriptionStatus == 'active'
            ? now.add(Duration(days: durationDays))
            : null);

    if (subscriptionStatus == 'active' && calculatedEndDate == null) {
      throw StateError('الاشتراك الفعّال يحتاج إلى تاريخ انتهاء');
    }

    final reference = _subscriptions.doc();

    final subscription = OfficeSubscriptionModel(
      id: reference.id,
      officeId: officeId,
      ownerId: ownerId,
      packageId: packageId,
      packageName: packageName,
      durationDays: durationDays,
      price: price,
      currency: currency,
      paymentStatus: paymentStatus,
      status: subscriptionStatus,
      startDate: subscriptionStatus == 'active' ? now : startDate,
      endDate: calculatedEndDate,
      createdAt: now,
      updatedAt: now,
    );

    await reference.set(subscription.toFirestore());

    if (subscription.status == 'active') {
      await _syncOfficeSubscription(
        officeId,
        subscription,
      );
    }

    return reference.id;
  }

  // ═════════════════════════════════════════════
  // تمديد اشتراك فعّال - للاستخدام الإداري
  // ═════════════════════════════════════════════

  Future<void> extendSubscription({
    required String officeId,
    required int additionalDays,
  }) async {
    if (additionalDays <= 0) {
      throw ArgumentError('عدد أيام التمديد يجب أن يكون أكبر من صفر');
    }

    final subscription = await getOfficeSubscription(officeId);

    if (subscription == null) {
      throw StateError('لا يوجد اشتراك لهذا المكتب');
    }

    if (subscription.status != 'active') {
      throw StateError('لا يمكن تمديد اشتراك غير فعّال');
    }

    final now = DateTime.now();
    final currentEndDate = _requireEndDate(subscription);
    final baseDate = currentEndDate.isAfter(now) ? currentEndDate : now;
    final newEndDate = baseDate.add(Duration(days: additionalDays));

    await _subscriptions.doc(subscription.id).update({
      'endDate': Timestamp.fromDate(newEndDate),
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncOfficeSubscriptionData(
      officeId: officeId,
      status: 'active',
      endDate: newEndDate,
      subscriptionId: subscription.id,
      packageId: subscription.packageId,
      packageName: subscription.packageName,
    );
  }

  // ═════════════════════════════════════════════
  // تجديد الاشتراك - ينشئ/يحدث طلبًا pending
  // ═════════════════════════════════════════════

  Future<String> renewSubscription({
    required String officeId,
    required String ownerId,
    required String packageId,
    required String packageName,
    required int durationDays,
    required double price,
    String currency = 'IQD',
  }) async {
    return createSubscriptionRequest(
      officeId: officeId,
      ownerId: ownerId,
      packageId: packageId,
      packageName: packageName,
      durationDays: durationDays,
      price: price,
      currency: currency,
    );
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك فعّال؟
  // ═════════════════════════════════════════════

  Future<bool> isSubscriptionActive(String officeId) async {
    final subscription = await getOfficeSubscription(officeId);

    if (subscription == null || subscription.status != 'active') {
      return false;
    }

    final endDate = subscription.endDate;

    if (endDate == null) {
      return false;
    }

    return _isDateActive(endDate);
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك منتهي؟
  // ═════════════════════════════════════════════

  Future<bool> isSubscriptionExpired(String officeId) async {
    final subscription = await getOfficeSubscription(officeId);

    if (subscription == null) {
      return true;
    }

    if (subscription.status != 'active') {
      return subscription.status == 'expired';
    }

    final endDate = subscription.endDate;

    if (endDate == null) {
      return false;
    }

    return !_isDateActive(endDate);
  }

  // ═════════════════════════════════════════════
  // تحديث حالة الاشتراك تلقائيًا
  // ═════════════════════════════════════════════

  Future<OfficeSubscriptionModel?> refreshSubscriptionStatus(
    String officeId,
  ) async {
    final subscription = await getOfficeSubscription(officeId);

    if (subscription == null) {
      return null;
    }

    // الطلبات pending لا تتحول إلى active تلقائيًا.
    if (subscription.status != 'active') {
      return subscription;
    }

    final endDate = _requireEndDate(subscription);
    final now = DateTime.now();

    if (!endDate.isAfter(now)) {
      await _subscriptions.doc(subscription.id).update({
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _syncOfficeSubscriptionData(
        officeId: officeId,
        status: 'expired',
        endDate: endDate,
        subscriptionId: subscription.id,
        packageId: subscription.packageId,
        packageName: subscription.packageName,
      );

      return subscription.copyWith(
        status: 'expired',
        updatedAt: now,
      );
    }

    return subscription;
  }

  // ═════════════════════════════════════════════
  // إلغاء الاشتراك - للإدارة
  // ═════════════════════════════════════════════

  Future<void> cancelSubscription({
    required String subscriptionId,
  }) async {
    final subscription = await getSubscriptionById(subscriptionId);

    if (subscription == null) {
      throw StateError('لا يوجد اشتراك بهذا المعرّف');
    }

    final endDate = subscription.endDate;

    await _subscriptions.doc(subscription.id).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncOfficeSubscriptionData(
      officeId: subscription.officeId,
      status: 'cancelled',
      endDate: endDate,
      subscriptionId: subscription.id,
      packageId: subscription.packageId,
      packageName: subscription.packageName,
    );
  }

  // ═════════════════════════════════════════════
  // تفعيل الاشتراك - للإدارة فقط
  // ═════════════════════════════════════════════

  Future<void> activateSubscription({
    required String subscriptionId,
  }) async {
    final subscription = await getSubscriptionById(subscriptionId);

    if (subscription == null) {
      throw StateError('لا يوجد اشتراك بهذا المعرّف');
    }

    if (subscription.status != 'pending') {
      throw StateError(
        'لا يمكن تفعيل هذا الاشتراك لأنه ليس قيد المراجعة',
      );
    }

    final now = DateTime.now();

    // عند التجديد لا نستبدل الأيام المتبقية من الاشتراك الحالي.
    // تُضاف مدة الباقة الجديدة إلى تاريخ انتهاء الاشتراك الفعّال الحالي.
    final currentSubscription = await getOfficeSubscription(
      subscription.officeId,
    );

    final currentEndDate = currentSubscription?.status == 'active'
        ? currentSubscription?.endDate
        : null;

    final hasRemainingTime =
        currentEndDate != null && currentEndDate.isAfter(now);

    final startDate = hasRemainingTime ? currentEndDate : now;
    final endDate = startDate.add(
      Duration(
        days: subscription.durationDays,
      ),
    );

    // عند تجديد الاشتراك، لا نضيّع محاولات التمييز المتبقية من
    // الاشتراك القديم. تُضاف إلى رصيد الباقة الجديدة.
    // مثال: 4 محاولات متبقية + 7 محاولات في الباقة الجديدة = 11.
    final newFeaturedMax = currentSubscription == null
        ? subscription.maxFeaturedProperties
        : currentSubscription.mergedFeaturedLimit(
            subscription.maxFeaturedProperties,
          );

    final batch = _firestore.batch();

    final subscriptionRef = _subscriptions.doc(
      subscription.id,
    );

    batch.update(
      subscriptionRef,
      {
        'status': 'active',
        'paymentStatus': 'paid',
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'maxFeaturedProperties': newFeaturedMax,
        'featuredPropertiesUsed': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // البحث عن طلب الدفع المرتبط بهذا الاشتراك.
    final paymentSnapshot = await _firestore
        .collection('subscription_payments')
        .where(
          'subscriptionId',
          isEqualTo: subscription.id,
        )
        .limit(1)
        .get();

    if (paymentSnapshot.docs.isNotEmpty) {
      final paymentRef = paymentSnapshot.docs.first.reference;

      batch.update(
        paymentRef,
        {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': FirebaseAuth.instance.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();

    await _syncOfficeSubscriptionData(
      officeId: subscription.officeId,
      status: 'active',
      endDate: endDate,
      subscriptionId: subscription.id,
      packageId: subscription.packageId,
      packageName: subscription.packageName,
      subscriptionStartDate:
          hasRemainingTime ? currentSubscription?.startDate : startDate,
    );
  }

// ═════════════════════════════════════════════
// رفض طلب الاشتراك - للإدارة فقط
// ═════════════════════════════════════════════

  Future<void> rejectSubscription({
    required String subscriptionId,
  }) async {
    final subscription = await getSubscriptionById(
      subscriptionId,
    );

    if (subscription == null) {
      throw StateError(
        'لا يوجد اشتراك بهذا المعرّف',
      );
    }

    if (subscription.status != 'pending') {
      throw StateError(
        'لا يمكن رفض هذا الطلب لأنه ليس قيد المراجعة',
      );
    }

    final batch = _firestore.batch();

    final subscriptionRef = _subscriptions.doc(
      subscription.id,
    );

    batch.update(
      subscriptionRef,
      {
        'status': 'cancelled',
        'paymentStatus': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    final paymentSnapshot = await _firestore
        .collection('subscription_payments')
        .where(
          'subscriptionId',
          isEqualTo: subscription.id,
        )
        .limit(1)
        .get();

    if (paymentSnapshot.docs.isNotEmpty) {
      final paymentRef = paymentSnapshot.docs.first.reference;

      batch.update(
        paymentRef,
        {
          'status': 'rejected',
          'approvedBy': FirebaseAuth.instance.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();

    // الطلب مرفوض، لذلك لا يوجد اشتراك فعال في المكتب.
    await _syncOfficeSubscriptionData(
      officeId: subscription.officeId,
      status: 'cancelled',
      endDate: null,
      subscriptionId: subscription.id,
      packageId: subscription.packageId,
      packageName: subscription.packageName,
      subscriptionStartDate: null,
    );
  }

  // ═════════════════════════════════════════════
  // إيقاف الاشتراك - للإدارة
  // ═════════════════════════════════════════════

  Future<void> suspendSubscription({
    required String subscriptionId,
  }) async {
    final subscription = await getSubscriptionById(subscriptionId);

    if (subscription == null) {
      throw StateError('لا يوجد اشتراك بهذا المعرّف');
    }

    if (subscription.status != 'active') {
      throw StateError(
        'لا يمكن إيقاف اشتراك غير فعّال',
      );
    }

    await _subscriptions.doc(subscription.id).update({
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncOfficeSubscriptionData(
      officeId: subscription.officeId,
      status: 'suspended',
      endDate: subscription.endDate,
      subscriptionId: subscription.id,
      packageId: subscription.packageId,
      packageName: subscription.packageName,
      subscriptionStartDate: subscription.startDate,
    );
  }

  // ═════════════════════════════════════════════
  // الأيام المتبقية
  // ═════════════════════════════════════════════

  Future<int> getRemainingDays(String officeId) async {
    final subscription = await getOfficeSubscription(officeId);

    if (subscription == null || subscription.status != 'active') {
      return 0;
    }

    final endDate = subscription.endDate;

    if (endDate == null || !endDate.isAfter(DateTime.now())) {
      return 0;
    }

    return endDate.difference(DateTime.now()).inDays;
  }

  Future<void> resumeSubscription({
    required String subscriptionId,
  }) async {
    final subscription = await getSubscriptionById(subscriptionId);

    if (subscription == null) {
      throw StateError('لا يوجد اشتراك بهذا المعرّف');
    }

    if (subscription.status != 'suspended') {
      throw StateError(
        'لا يمكن إعادة تفعيل اشتراك غير موقوف',
      );
    }

    final now = DateTime.now();
    final endDate = subscription.endDate;

    if (endDate == null || !endDate.isAfter(now)) {
      throw StateError(
        'انتهت مدة الاشتراك، يجب إنشاء طلب تجديد جديد',
      );
    }

    await _subscriptions.doc(subscription.id).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncOfficeSubscriptionData(
      officeId: subscription.officeId,
      status: 'active',
      endDate: endDate,
      subscriptionId: subscription.id,
      packageId: subscription.packageId,
      packageName: subscription.packageName,
      subscriptionStartDate: subscription.startDate,
    );
  }

  // ═════════════════════════════════════════════
  // إنشاء طلب دفع مرتبط بطلب الاشتراك
  // ═════════════════════════════════════════════

  Future<String> createPaymentRequest({
    required String officeId,
    required String ownerUid,
    required String subscriptionId,
    required SubscriptionPackageModel package,
    required String paymentMethod,
    String? transactionId,
    String? notes,
    String? receiptUrl,
    String? contactPhone,
  }) async {
    if (officeId.trim().isEmpty) {
      throw ArgumentError('معرّف المكتب غير صالح');
    }

    if (ownerUid.trim().isEmpty) {
      throw ArgumentError('معرّف صاحب المكتب غير صالح');
    }

    if (subscriptionId.trim().isEmpty) {
      throw ArgumentError('معرّف الاشتراك غير صالح');
    }

    final subscription = await getSubscriptionById(subscriptionId);

    if (subscription == null) {
      throw StateError('طلب الاشتراك غير موجود');
    }

    if (subscription.officeId != officeId || subscription.ownerId != ownerUid) {
      throw StateError('لا تملك صلاحية إنشاء طلب دفع لهذا الاشتراك');
    }

    if (subscription.status != 'pending') {
      throw StateError('لا يمكن إنشاء طلب دفع لهذا الاشتراك حاليًا');
    }

    final reference = _firestore.collection('subscription_payments').doc();
    final now = DateTime.now();

    final payment = SubscriptionPaymentModel(
      id: reference.id,
      officeId: officeId,
      ownerUid: ownerUid,
      subscriptionId: subscriptionId,
      packageId: package.id,
      packageName: package.name,
      amount: package.price,
      currency: package.currency,
      status: 'pending',
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      notes: notes,
      receiptUrl: receiptUrl,
      createdAt: now,
      updatedAt: now,
      approvedAt: null,
      approvedBy: null,
    );

    final paymentData = payment.toMap();
    if (contactPhone != null && contactPhone.trim().isNotEmpty) {
      paymentData['contactPhone'] = contactPhone.trim();
    }
    await reference.set(paymentData);

    await _subscriptions.doc(subscriptionId).update({
      'paymentStatus': 'pending',
      'paymentMethod': paymentMethod,
      'paymentReference': transactionId ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return reference.id;
  }

  // ═════════════════════════════════════════════
  // مزامنة الاشتراك مع المكتب
  // ═════════════════════════════════════════════

  /// تمييز/إلغاء تمييز عقار مع استهلاك محاولة واحدة فقط عند التمييز.
  ///
  /// التمييز يستهلك محاولة واحدة. إلغاء التمييز لا يستهلك محاولة
  /// إضافية ولا يعيد المحاولة المستهلكة إلى الرصيد.
  ///
  /// تتم العملية داخل Transaction لمنع تجاوز الحد بسبب طلبين متزامنين.
  Future<void> setFeaturedProperty({
    required String officeId,
    required String ownerUid,
    required String propertyId,
    required bool isFeatured,
  }) async {
    if (officeId.trim().isEmpty ||
        ownerUid.trim().isEmpty ||
        propertyId.trim().isEmpty) {
      throw ArgumentError('بيانات المكتب أو المالك أو العقار غير صالحة.');
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != ownerUid) {
      throw StateError('ليس لديك صلاحية لإدارة عقارات هذا المكتب.');
    }

    // جلب الاشتراك الفعال للمكتب.
    final subscription = await getOfficeSubscription(officeId);

    if (subscription == null) {
      throw StateError('لا يوجد اشتراك لهذا المكتب.');
    }

    if (!subscription.isActive || !subscription.canFeatureProperties) {
      throw StateError('باقتك الحالية لا تسمح بتمييز العقارات.');
    }

    final propertyRef = _firestore.collection('properties').doc(propertyId);

    final subscriptionRef = _subscriptions.doc(subscription.id);

    await _firestore.runTransaction((transaction) async {
      final propertySnapshot = await transaction.get(propertyRef);

      final subscriptionSnapshot = await transaction.get(subscriptionRef);

      if (!propertySnapshot.exists) {
        throw StateError('العقار غير موجود.');
      }

      if (!subscriptionSnapshot.exists) {
        throw StateError('الاشتراك غير موجود.');
      }

      final propertyData = propertySnapshot.data() ?? {};

      final propertyOfficeId = propertyData['officeId'] as String? ?? '';

      final propertyOwnerUid = propertyData['publisherUid'] as String? ??
          propertyData['userId'] as String? ??
          '';

      if (propertyOfficeId != officeId ||
          (propertyOwnerUid.isNotEmpty && propertyOwnerUid != ownerUid)) {
        throw StateError('هذا العقار لا يتبع لهذا المكتب.');
      }

      final currentFeatured = propertyData['isFeatured'] as bool? ?? false;

      // لا يوجد أي تغيير، لذلك لا نستهلك محاولة.
      if (currentFeatured == isFeatured) {
        return;
      }

      // =========================================================
      // إلغاء التمييز
      // =========================================================
      //
      // مهم جدًا:
      // إلغاء التمييز لا يعيد المحاولة ولا يستهلك محاولة جديدة.
      //
      if (!isFeatured) {
        transaction.update(propertyRef, {
          'isFeatured': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return;
      }

      // =========================================================
      // تمييز العقار
      // =========================================================
      //
      // هنا فقط يتم استهلاك محاولة واحدة.
      //

      final subscriptionData = subscriptionSnapshot.data() ?? {};

      final usedRaw = subscriptionData['featuredPropertiesUsed'];

      final used = usedRaw is int
          ? usedRaw
          : usedRaw is num
              ? usedRaw.toInt()
              : 0;

      final maxRaw = subscriptionData['maxFeaturedProperties'];

      final max = maxRaw is int
          ? maxRaw
          : maxRaw is num
              ? maxRaw.toInt()
              : subscription.maxFeaturedProperties;

      // max = 0 يعني عدم وجود حد.
      if (max > 0 && used >= max) {
        throw StateError(
          'لقد استُنفذت جميع محاولات تمييز العقارات في باقتك الحالية',
        );
      }

      // تمييز العقار.
      transaction.update(propertyRef, {
        'isFeatured': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // استهلاك محاولة واحدة فقط عند التمييز.
      transaction.update(subscriptionRef, {
        'featuredPropertiesUsed': used + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _syncOfficeSubscription(
    String officeId,
    OfficeSubscriptionModel subscription,
  ) async {
    await _syncOfficeSubscriptionData(
      officeId: officeId,
      status: subscription.status,
      endDate: subscription.endDate,
      subscriptionId: subscription.id,
      packageId: subscription.packageId,
      packageName: subscription.packageName,
      subscriptionStartDate: subscription.startDate,
    );
  }

  Future<void> _syncOfficeSubscriptionData({
    required String officeId,
    required String status,
    DateTime? endDate,
    String? subscriptionId,
    String? packageId,
    String? packageName,
    DateTime? subscriptionStartDate,
    int? maxProperties,
    int? maxFeaturedProperties,
    bool? canFeatureProperties,
    bool? canAppearInFeaturedOffices,
    bool? canUseAdvancedStatistics,
  }) async {
    final data = <String, dynamic>{
      'subscriptionStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (endDate != null) {
      data['subscriptionEndDate'] = Timestamp.fromDate(endDate);
    } else {
      data['subscriptionEndDate'] = null;
    }

    if (subscriptionStartDate != null) {
      data['subscriptionStartDate'] = Timestamp.fromDate(subscriptionStartDate);
    } else {
      data['subscriptionStartDate'] = null;
    }

    if (subscriptionId != null) {
      data['subscriptionId'] = subscriptionId;
    }

    if (maxProperties != null) {
      data['maxProperties'] = maxProperties;
    }

    if (maxFeaturedProperties != null) {
      data['maxFeaturedProperties'] = maxFeaturedProperties;
    }

    if (canFeatureProperties != null) {
      data['canFeatureProperties'] = canFeatureProperties;
    }

    if (canAppearInFeaturedOffices != null) {
      data['canAppearInFeaturedOffices'] = canAppearInFeaturedOffices;
    }

    if (canUseAdvancedStatistics != null) {
      data['canUseAdvancedStatistics'] = canUseAdvancedStatistics;
    }

    // لا يحتوي OfficeModel على حقلي packageId/packageName.
    // لذلك لا نضيفهما إلى مستند المكتب.
    // بيانات الباقة تبقى في office_subscriptions.
    await _offices.doc(officeId).update(data);
  }

  bool _isDateActive(DateTime endDate) {
    return endDate.isAfter(DateTime.now());
  }

  DateTime _requireEndDate(OfficeSubscriptionModel subscription) {
    final endDate = subscription.endDate;

    if (endDate == null) {
      throw StateError(
        'الاشتراك ${subscription.id} لا يحتوي على تاريخ انتهاء',
      );
    }

    return endDate;
  }
}
