import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/subscription_model.dart';
import '../models/subscription_package_model.dart';
import '../models/subscription_payment_model.dart';

/// خدمة اشتراكات المكاتب.
///
/// المسؤوليات الأساسية:
/// - قراءة الباقات.
/// - إنشاء الاشتراكات.
/// - قراءة اشتراك مكتب.
/// - حساب حالة الاشتراك.
/// - إنشاء طلبات الدفع.
/// - قراءة سجل الدفعات.
/// - تجديد الاشتراك.
/// - اعتماد/رفض الدفع.
/// - تفعيل الاشتراك بعد اعتماد الدفع.
class SubscriptionService {
  SubscriptionService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String packagesCollection = 'subscription_packages';
  static const String subscriptionsCollection = 'subscriptions';
  static const String paymentsCollection = 'subscription_payments';

  // ═════════════════════════════════════════════
  // الباقات
  // ═════════════════════════════════════════════

  Stream<List<SubscriptionPackageModel>> watchActivePackages() {
    return _firestore
        .collection(packagesCollection)
        .where(
          'isActive',
          isEqualTo: true,
        )
        .orderBy('sortOrder')
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs
            .map(SubscriptionPackageModel.fromFirestore)
            .toList();
      },
    );
  }

  Stream<List<SubscriptionPackageModel>> watchAllPackages() {
    return _firestore
        .collection(packagesCollection)
        .orderBy('sortOrder')
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs
            .map(SubscriptionPackageModel.fromFirestore)
            .toList();
      },
    );
  }

  Future<SubscriptionPackageModel?> getPackage(
    String packageId,
  ) async {
    final doc =
        await _firestore.collection(packagesCollection).doc(packageId).get();

    if (!doc.exists) {
      return null;
    }

    return SubscriptionPackageModel.fromFirestore(doc);
  }

  Future<String> createPackage(
    SubscriptionPackageModel package,
  ) async {
    final docRef = _firestore.collection(packagesCollection).doc();

    await docRef.set(
      package.copyWith(id: docRef.id).toMap(useServerTimestamp: true),
    );

    return docRef.id;
  }

  Future<void> updatePackage(
    SubscriptionPackageModel package,
  ) async {
    await _firestore.collection(packagesCollection).doc(package.id).update(
          package
              .copyWith(
                updatedAt: DateTime.now(),
              )
              .toMap(),
        );
  }

  Future<void> setPackageActive({
    required String packageId,
    required bool isActive,
  }) async {
    await _firestore.collection(packagesCollection).doc(packageId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePackage(
    String packageId,
  ) async {
    await _firestore.collection(packagesCollection).doc(packageId).delete();
  }

  // ═════════════════════════════════════════════
  // اشتراك المكتب
  // ═════════════════════════════════════════════

  Future<SubscriptionModel?> getOfficeSubscription(
    String officeId,
  ) async {
    final snapshot = await _firestore
        .collection(subscriptionsCollection)
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return SubscriptionModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  Stream<SubscriptionModel?> watchOfficeSubscription(
    String officeId,
  ) {
    return _firestore
        .collection(subscriptionsCollection)
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(1)
        .snapshots()
        .map(
      (snapshot) {
        if (snapshot.docs.isEmpty) {
          return null;
        }

        return SubscriptionModel.fromFirestore(
          snapshot.docs.first,
        );
      },
    );
  }

  Stream<List<SubscriptionModel>> watchOfficeSubscriptions(
    String officeId,
  ) {
    return _firestore
        .collection(subscriptionsCollection)
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs.map(SubscriptionModel.fromFirestore).toList();
      },
    );
  }

  // ═════════════════════════════════════════════
  // إنشاء اشتراك
  // ═════════════════════════════════════════════

  Future<String> createSubscription({
    required String officeId,
    required String ownerUid,
    required SubscriptionPackageModel package,
    DateTime? startDate,
    bool isTrial = false,
    String paymentStatus = 'pending',
    String paymentMethod = 'manual',

    /// الحالة الأولية للاشتراك.
    ///
    /// عند الدفع اليدوي أو الإلكتروني يجب أن تكون:
    /// pending_payment
    ///
    /// ولا تصبح active إلا بعد اعتماد الإدارة.
    String? initialStatus,
  }) async {
    if (!package.isValid) {
      throw Exception(
        'الباقة غير صالحة أو غير متاحة',
      );
    }

    final start = startDate ?? DateTime.now();

    final end = start.add(
      Duration(
        days: package.durationDays,
      ),
    );

    final docRef = _firestore.collection(subscriptionsCollection).doc();

    final status = initialStatus ?? (isTrial ? 'trial' : 'active');

    final subscription = SubscriptionModel(
      id: docRef.id,
      officeId: officeId,
      ownerUid: ownerUid,
      packageId: package.id,
      packageName: package.name,
      status: status,
      startDate: start,
      endDate: end,
      autoRenew: false,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      paymentId: null,
      amount: package.price,
      currency: package.currency,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(
      subscription.toMap(
        useServerTimestamp: true,
      ),
    );

    return docRef.id;
  }

  // ═════════════════════════════════════════════
  // حساب الحالة
  // ═════════════════════════════════════════════

  String calculateCurrentStatus(
    SubscriptionModel subscription, {
    int warningDays = 7,
  }) {
    final endDate = subscription.endDate;

    if (endDate == null) {
      return 'none';
    }

    final now = DateTime.now();

    if (subscription.status == 'pending_payment') {
      return 'pending_payment';
    }

    if (subscription.status == 'suspended') {
      return 'suspended';
    }

    if (subscription.status == 'cancelled') {
      return 'cancelled';
    }

    if (endDate.isBefore(now)) {
      return 'expired';
    }

    if (subscription.status == 'trial') {
      return 'trial';
    }

    final remaining = endDate.difference(now);

    if (remaining.inDays <= warningDays) {
      return 'expiring_soon';
    }

    return 'active';
  }

  bool isSubscriptionUsable(
    SubscriptionModel subscription,
  ) {
    final status = calculateCurrentStatus(subscription);

    return status == 'active' || status == 'trial' || status == 'expiring_soon';
  }

  bool isSubscriptionExpired(
    SubscriptionModel subscription,
  ) {
    return calculateCurrentStatus(subscription) == 'expired';
  }

  int remainingDays(
    SubscriptionModel subscription,
  ) {
    final endDate = subscription.endDate;

    if (endDate == null) {
      return 0;
    }

    final now = DateTime.now();

    if (endDate.isBefore(now)) {
      return 0;
    }

    return endDate.difference(now).inDays;
  }

  // ═════════════════════════════════════════════
  // تحديث حالة الاشتراك
  // ═════════════════════════════════════════════

  Future<void> updateSubscriptionStatus({
    required String subscriptionId,
    required String status,
  }) async {
    await _firestore
        .collection(subscriptionsCollection)
        .doc(subscriptionId)
        .update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> suspendSubscription(
    String subscriptionId,
  ) async {
    await updateSubscriptionStatus(
      subscriptionId: subscriptionId,
      status: 'suspended',
    );
  }

  Future<void> cancelSubscription(
    String subscriptionId,
  ) async {
    await updateSubscriptionStatus(
      subscriptionId: subscriptionId,
      status: 'cancelled',
    );
  }

  Future<void> activateSubscription(
    String subscriptionId,
  ) async {
    await updateSubscriptionStatus(
      subscriptionId: subscriptionId,
      status: 'active',
    );
  }

  // ═════════════════════════════════════════════
  // طلبات الدفع
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
  }) async {
    final docRef = _firestore.collection(paymentsCollection).doc();

    final payment = SubscriptionPaymentModel(
      id: docRef.id,
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      approvedAt: null,
      approvedBy: null,
    );

    await docRef.set(
      payment.toMap(
        useServerTimestamp: true,
      ),
    );

    // ربط رقم عملية الدفع بالاشتراك.
    await _firestore
        .collection(subscriptionsCollection)
        .doc(subscriptionId)
        .update({
      'paymentId': docRef.id,
      'paymentStatus': 'pending',
      'paymentMethod': paymentMethod,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Stream<List<SubscriptionPaymentModel>> watchOfficePayments(
    String officeId,
  ) {
    return _firestore
        .collection(paymentsCollection)
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs
            .map(SubscriptionPaymentModel.fromFirestore)
            .toList();
      },
    );
  }

  Stream<List<SubscriptionPaymentModel>> watchAllPayments() {
    return _firestore
        .collection(paymentsCollection)
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs
            .map(SubscriptionPaymentModel.fromFirestore)
            .toList();
      },
    );
  }

  // ═════════════════════════════════════════════
  // اعتماد الدفع
  // ═════════════════════════════════════════════

  /// اعتماد الدفع وتفعيل الاشتراك المرتبط به.
  ///
  /// تتم العمليتان داخل Transaction واحدة.
  Future<void> approvePayment({
    required String paymentId,
    required String approvedBy,
  }) async {
    final paymentRef = _firestore.collection(paymentsCollection).doc(paymentId);

    await _firestore.runTransaction(
      (transaction) async {
        final paymentSnapshot = await transaction.get(paymentRef);

        if (!paymentSnapshot.exists) {
          throw Exception(
            'طلب الدفع غير موجود',
          );
        }

        final payment = SubscriptionPaymentModel.fromFirestore(
          paymentSnapshot,
        );

        if (payment.status == 'approved') {
          return;
        }

        if (payment.status != 'pending') {
          throw Exception(
            'لا يمكن اعتماد طلب دفع حالته ${payment.status}',
          );
        }

        final subscriptionRef = _firestore
            .collection(subscriptionsCollection)
            .doc(payment.subscriptionId);

        final subscriptionSnapshot = await transaction.get(subscriptionRef);

        if (!subscriptionSnapshot.exists) {
          throw Exception(
            'الاشتراك المرتبط بطلب الدفع غير موجود',
          );
        }

        transaction.update(
          paymentRef,
          {
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': approvedBy,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          subscriptionRef,
          {
            'status': 'active',
            'paymentStatus': 'approved',
            'paymentMethod': payment.paymentMethod,
            'paymentId': payment.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  /// رفض الدفع وإبقاء الاشتراك غير فعال.
  Future<void> rejectPayment({
    required String paymentId,
    required String rejectedBy,
  }) async {
    final paymentRef = _firestore.collection(paymentsCollection).doc(paymentId);

    await _firestore.runTransaction(
      (transaction) async {
        final paymentSnapshot = await transaction.get(paymentRef);

        if (!paymentSnapshot.exists) {
          throw Exception(
            'طلب الدفع غير موجود',
          );
        }

        final payment = SubscriptionPaymentModel.fromFirestore(
          paymentSnapshot,
        );

        final subscriptionRef = _firestore
            .collection(subscriptionsCollection)
            .doc(payment.subscriptionId);

        transaction.update(
          paymentRef,
          {
            'status': 'rejected',
            'approvedBy': rejectedBy,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          subscriptionRef,
          {
            'status': 'payment_rejected',
            'paymentStatus': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  // ═════════════════════════════════════════════
  // تجديد الاشتراك
  // ═════════════════════════════════════════════

  Future<String> renewSubscription({
    required String officeId,
    required String ownerUid,
    required SubscriptionPackageModel package,
    SubscriptionModel? currentSubscription,
    bool isTrial = false,
    String paymentStatus = 'pending',
    String paymentMethod = 'manual',
  }) async {
    DateTime start = DateTime.now();

    if (currentSubscription != null &&
        currentSubscription.endDate != null &&
        currentSubscription.endDate!.isAfter(start)) {
      start = currentSubscription.endDate!;
    }

    return createSubscription(
      officeId: officeId,
      ownerUid: ownerUid,
      package: package,
      startDate: start,
      isTrial: isTrial,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      initialStatus: isTrial ? 'trial' : 'pending_payment',
    );
  }
}
