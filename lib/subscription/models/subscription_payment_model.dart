import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج عملية دفع اشتراك المكتب.
///
/// يحتفظ بسجل مستقل لكل عملية دفع أو تجديد.
/// هذا مهم حتى لا نعتمد على سجل الاشتراك الحالي فقط.
///
/// مثال:
/// - دفع أول اشتراك.
/// - تجديد الاشتراك.
/// - ترقية الباقة.
/// - دفع يدوي تمت مراجعته من الإدارة.
class SubscriptionPaymentModel {
  final String id;

  /// المكتب المرتبط بالدفع.
  final String officeId;

  /// صاحب المكتب.
  final String ownerUid;

  /// الاشتراك الذي تم الدفع له.
  final String subscriptionId;

  /// الباقة المرتبطة بالعملية.
  final String packageId;

  /// اسم الباقة وقت الدفع.
  ///
  /// نحتفظ به حتى لو تغير اسم الباقة لاحقًا.
  final String packageName;

  /// المبلغ المدفوع.
  final double amount;

  /// العملة.
  final String currency;

  /// حالة عملية الدفع.
  ///
  /// القيم المتوقعة لاحقًا:
  /// pending
  /// approved
  /// rejected
  /// refunded
  final String status;

  /// طريقة الدفع.
  ///
  /// مثال:
  /// manual
  /// cash
  /// bank_transfer
  /// electronic
  final String paymentMethod;

  /// رقم العملية أو المرجع إن وجد.
  final String? transactionId;

  /// ملاحظات الدفع.
  final String? notes;

  /// صورة إيصال الدفع إن وجدت.
  final String? receiptUrl;

  /// تاريخ إنشاء طلب الدفع.
  final DateTime? createdAt;

  /// تاريخ تحديث العملية.
  final DateTime? updatedAt;

  /// تاريخ اعتماد العملية من الإدارة.
  final DateTime? approvedAt;

  /// UID المسؤول الذي قام بالاعتماد.
  final String? approvedBy;

  const SubscriptionPaymentModel({
    required this.id,
    required this.officeId,
    required this.ownerUid,
    required this.subscriptionId,
    required this.packageId,
    required this.packageName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    required this.notes,
    required this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.approvedAt,
    required this.approvedBy,
  });

  // ═════════════════════════════════════════════
  // إنشاء من Firestore
  // ═════════════════════════════════════════════

  factory SubscriptionPaymentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return SubscriptionPaymentModel(
      id: doc.id,
      officeId: _stringValue(
        data['officeId'],
      ),
      ownerUid: _stringValue(
        data['ownerUid'],
      ),
      subscriptionId: _stringValue(
        data['subscriptionId'],
      ),
      packageId: _stringValue(
        data['packageId'],
      ),
      packageName: _stringValue(
        data['packageName'],
      ),
      amount: _doubleValue(
        data['amount'],
      ),
      currency: _stringValue(
        data['currency'],
        fallback: 'IQD',
      ),
      status: _stringValue(
        data['status'],
        fallback: 'pending',
      ),
      paymentMethod: _stringValue(
        data['paymentMethod'],
        fallback: 'manual',
      ),
      transactionId: _nullableString(
        data['transactionId'],
      ),
      notes: _nullableString(
        data['notes'],
      ),
      receiptUrl: _nullableString(
        data['receiptUrl'],
      ),
      createdAt: _dateValue(
        data['createdAt'],
      ),
      updatedAt: _dateValue(
        data['updatedAt'],
      ),
      approvedAt: _dateValue(
        data['approvedAt'],
      ),
      approvedBy: _nullableString(
        data['approvedBy'],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // إنشاء من Map
  // ═════════════════════════════════════════════

  factory SubscriptionPaymentModel.fromMap(
    Map<String, dynamic> data, {
    String? id,
  }) {
    return SubscriptionPaymentModel(
      id: id ?? _stringValue(data['id']),
      officeId: _stringValue(
        data['officeId'],
      ),
      ownerUid: _stringValue(
        data['ownerUid'],
      ),
      subscriptionId: _stringValue(
        data['subscriptionId'],
      ),
      packageId: _stringValue(
        data['packageId'],
      ),
      packageName: _stringValue(
        data['packageName'],
      ),
      amount: _doubleValue(
        data['amount'],
      ),
      currency: _stringValue(
        data['currency'],
        fallback: 'IQD',
      ),
      status: _stringValue(
        data['status'],
        fallback: 'pending',
      ),
      paymentMethod: _stringValue(
        data['paymentMethod'],
        fallback: 'manual',
      ),
      transactionId: _nullableString(
        data['transactionId'],
      ),
      notes: _nullableString(
        data['notes'],
      ),
      receiptUrl: _nullableString(
        data['receiptUrl'],
      ),
      createdAt: _dateValue(
        data['createdAt'],
      ),
      updatedAt: _dateValue(
        data['updatedAt'],
      ),
      approvedAt: _dateValue(
        data['approvedAt'],
      ),
      approvedBy: _nullableString(
        data['approvedBy'],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // تحويل إلى Map
  // ═════════════════════════════════════════════

  Map<String, dynamic> toMap({
    bool useServerTimestamp = false,
  }) {
    return {
      'officeId': officeId,
      'ownerUid': ownerUid,
      'subscriptionId': subscriptionId,
      'packageId': packageId,
      'packageName': packageName,
      'amount': amount,
      'currency': currency,
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'notes': notes,
      'receiptUrl': receiptUrl,
      'createdAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : createdAt == null
              ? null
              : Timestamp.fromDate(createdAt!),
      'updatedAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : updatedAt == null
              ? null
              : Timestamp.fromDate(updatedAt!),
      'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
      'approvedBy': approvedBy,
    };
  }

  // ═════════════════════════════════════════════
  // نسخ مع التعديل
  // ═════════════════════════════════════════════

  SubscriptionPaymentModel copyWith({
    String? id,
    String? officeId,
    String? ownerUid,
    String? subscriptionId,
    String? packageId,
    String? packageName,
    double? amount,
    String? currency,
    String? status,
    String? paymentMethod,
    String? transactionId,
    String? notes,
    String? receiptUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedAt,
    String? approvedBy,
  }) {
    return SubscriptionPaymentModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      ownerUid: ownerUid ?? this.ownerUid,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }

  // ═════════════════════════════════════════════
  // حالات الدفع
  // ═════════════════════════════════════════════

  bool get isPending {
    return status == 'pending';
  }

  bool get isApproved {
    return status == 'approved';
  }

  bool get isRejected {
    return status == 'rejected';
  }

  bool get isRefunded {
    return status == 'refunded';
  }

  // ═════════════════════════════════════════════
  // هل العملية نهائية؟
  // ═════════════════════════════════════════════

  bool get isFinal {
    return isApproved || isRejected || isRefunded;
  }

  // ═════════════════════════════════════════════
  // القيمة النصية
  // ═════════════════════════════════════════════

  @override
  String toString() {
    return 'SubscriptionPaymentModel('
        'id: $id, '
        'officeId: $officeId, '
        'subscriptionId: $subscriptionId, '
        'packageName: $packageName, '
        'amount: $amount, '
        'currency: $currency, '
        'status: $status, '
        'paymentMethod: $paymentMethod'
        ')';
  }

  // ═════════════════════════════════════════════
  // أدوات التحويل
  // ═════════════════════════════════════════════

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  static double _doubleValue(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static DateTime? _dateValue(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
