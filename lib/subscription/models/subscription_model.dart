import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج اشتراك المكتب.
///
/// هذا النموذج مسؤول عن بيانات الاشتراك فقط:
/// - المكتب المرتبط بالاشتراك.
/// - المستخدم صاحب المكتب.
/// - الباقة.
/// - تاريخ بداية الاشتراك.
/// - تاريخ الانتهاء.
/// - حالة الاشتراك.
/// - بيانات الدفع.
/// - التجديد.
///
/// ملاحظة:
/// لا نعتمد على وجود زر "إنهاء الاشتراك".
/// انتهاء الاشتراك يعتمد أساسًا على endDate،
/// وسيتم احتساب الحالة تلقائيًا لاحقًا.
class SubscriptionModel {
  final String id;
  final String officeId;
  final String ownerUid;

  final String packageId;
  final String packageName;

  final String status;

  final DateTime? startDate;
  final DateTime? endDate;

  final bool autoRenew;

  final String paymentStatus;
  final String paymentMethod;
  final String? paymentId;

  final double amount;
  final String currency;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubscriptionModel({
    required this.id,
    required this.officeId,
    required this.ownerUid,
    required this.packageId,
    required this.packageName,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.autoRenew,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.paymentId,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  // ═════════════════════════════════════════════
  // إنشاء النموذج من Firestore
  // ═════════════════════════════════════════════

  factory SubscriptionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return SubscriptionModel(
      id: doc.id,
      officeId: _stringValue(
        data['officeId'],
      ),
      ownerUid: _stringValue(
        data['ownerUid'],
      ),
      packageId: _stringValue(
        data['packageId'],
      ),
      packageName: _stringValue(
        data['packageName'],
      ),
      status: _stringValue(
        data['status'],
        fallback: 'none',
      ),
      startDate: _dateValue(
        data['startDate'],
      ),
      endDate: _dateValue(
        data['endDate'],
      ),
      autoRenew: data['autoRenew'] == true,
      paymentStatus: _stringValue(
        data['paymentStatus'],
        fallback: 'pending',
      ),
      paymentMethod: _stringValue(
        data['paymentMethod'],
        fallback: 'manual',
      ),
      paymentId: _nullableString(
        data['paymentId'],
      ),
      amount: _doubleValue(
        data['amount'],
      ),
      currency: _stringValue(
        data['currency'],
        fallback: 'IQD',
      ),
      createdAt: _dateValue(
        data['createdAt'],
      ),
      updatedAt: _dateValue(
        data['updatedAt'],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // إنشاء النموذج من Map
  // ═════════════════════════════════════════════

  factory SubscriptionModel.fromMap(
    Map<String, dynamic> data, {
    String? id,
  }) {
    return SubscriptionModel(
      id: id ?? _stringValue(data['id']),
      officeId: _stringValue(
        data['officeId'],
      ),
      ownerUid: _stringValue(
        data['ownerUid'],
      ),
      packageId: _stringValue(
        data['packageId'],
      ),
      packageName: _stringValue(
        data['packageName'],
      ),
      status: _stringValue(
        data['status'],
        fallback: 'none',
      ),
      startDate: _dateValue(
        data['startDate'],
      ),
      endDate: _dateValue(
        data['endDate'],
      ),
      autoRenew: data['autoRenew'] == true,
      paymentStatus: _stringValue(
        data['paymentStatus'],
        fallback: 'pending',
      ),
      paymentMethod: _stringValue(
        data['paymentMethod'],
        fallback: 'manual',
      ),
      paymentId: _nullableString(
        data['paymentId'],
      ),
      amount: _doubleValue(
        data['amount'],
      ),
      currency: _stringValue(
        data['currency'],
        fallback: 'IQD',
      ),
      createdAt: _dateValue(
        data['createdAt'],
      ),
      updatedAt: _dateValue(
        data['updatedAt'],
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
      'packageId': packageId,
      'packageName': packageName,
      'status': status,
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'autoRenew': autoRenew,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'amount': amount,
      'currency': currency,
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
    };
  }

  // ═════════════════════════════════════════════
  // نسخ النموذج مع التعديل
  // ═════════════════════════════════════════════

  SubscriptionModel copyWith({
    String? id,
    String? officeId,
    String? ownerUid,
    String? packageId,
    String? packageName,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool? autoRenew,
    String? paymentStatus,
    String? paymentMethod,
    String? paymentId,
    double? amount,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      ownerUid: ownerUid ?? this.ownerUid,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      autoRenew: autoRenew ?? this.autoRenew,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentId: paymentId ?? this.paymentId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك منتهي حسب التاريخ؟
  // ═════════════════════════════════════════════

  bool get isExpired {
    if (endDate == null) {
      return true;
    }

    return endDate!.isBefore(DateTime.now());
  }

  // ═════════════════════════════════════════════
  // الأيام المتبقية
  // ═════════════════════════════════════════════

  int get remainingDays {
    if (endDate == null) {
      return 0;
    }

    final now = DateTime.now();

    if (endDate!.isBefore(now)) {
      return 0;
    }

    return endDate!.difference(now).inDays;
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك على وشك الانتهاء؟
  // ═════════════════════════════════════════════

  bool isExpiringSoon({
    int warningDays = 7,
  }) {
    if (endDate == null || isExpired) {
      return false;
    }

    return remainingDays <= warningDays;
  }

  // ═════════════════════════════════════════════
  // القيمة النصية
  // ═════════════════════════════════════════════

  @override
  String toString() {
    return 'SubscriptionModel('
        'id: $id, '
        'officeId: $officeId, '
        'packageId: $packageId, '
        'status: $status, '
        'startDate: $startDate, '
        'endDate: $endDate, '
        'amount: $amount, '
        'currency: $currency'
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
