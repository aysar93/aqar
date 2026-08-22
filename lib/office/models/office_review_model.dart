import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج تقييم المكتب.
///
/// كل تقييم مرتبط بمكتب وبالمستخدم الذي قام بالتقييم.
/// التقييمات تظهر في الصفحة العامة للمكتب ويمكن لصاحب المكتب
/// رؤيتها وإدارتها.
class OfficeReviewModel {
  final String id;

  // ─────────────────────────────────────────────
  // العلاقات
  // ─────────────────────────────────────────────

  final String officeId;
  final String userId;

  // ─────────────────────────────────────────────
  // بيانات صاحب التقييم
  // ─────────────────────────────────────────────

  final String userName;
  final String userImageUrl;

  // ─────────────────────────────────────────────
  // التقييم
  // ─────────────────────────────────────────────

  /// قيمة التقييم من 1 إلى 5.
  final double rating;

  /// النص الذي كتبه المستخدم.
  final String comment;

  // ─────────────────────────────────────────────
  // حالة التقييم
  // ─────────────────────────────────────────────

  final String status;

  /// هل قام صاحب المكتب بالرد على التقييم؟
  final bool hasOwnerReply;

  /// رد صاحب المكتب.
  final String ownerReply;

  // ─────────────────────────────────────────────
  // التواريخ
  // ─────────────────────────────────────────────

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OfficeReviewModel({
    required this.id,
    required this.officeId,
    required this.userId,
    this.userName = '',
    this.userImageUrl = '',
    this.rating = 0,
    this.comment = '',
    this.status = 'published',
    this.hasOwnerReply = false,
    this.ownerReply = '',
    this.createdAt,
    this.updatedAt,
  });

  // ═════════════════════════════════════════════
  // إنشاء تقييم جديد
  // ═════════════════════════════════════════════

  factory OfficeReviewModel.create({
    required String id,
    required String officeId,
    required String userId,
    required double rating,
    String userName = '',
    String userImageUrl = '',
    String comment = '',
  }) {
    final now = DateTime.now();

    return OfficeReviewModel(
      id: id,
      officeId: officeId,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      rating: _normalizeRating(rating),
      comment: comment.trim(),
      status: 'published',
      hasOwnerReply: false,
      ownerReply: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  // ═════════════════════════════════════════════
  // Firestore → Model
  // ═════════════════════════════════════════════

  factory OfficeReviewModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return OfficeReviewModel(
      id: document.id,
      officeId: data['officeId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userImageUrl: data['userImageUrl'] as String? ?? '',
      rating: _normalizeRating(
        _doubleValue(data['rating']),
      ),
      comment: data['comment'] as String? ?? '',
      status: data['status'] as String? ?? 'published',
      hasOwnerReply: data['hasOwnerReply'] as bool? ?? false,
      ownerReply: data['ownerReply'] as String? ?? '',
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  // ═════════════════════════════════════════════
  // Model → Firestore
  // ═════════════════════════════════════════════

  Map<String, dynamic> toFirestore() {
    return {
      'officeId': officeId,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'rating': rating,
      'comment': comment,
      'status': status,
      'hasOwnerReply': hasOwnerReply,
      'ownerReply': ownerReply,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // ═════════════════════════════════════════════
  // هل التقييم منشور؟
  // ═════════════════════════════════════════════

  bool get isPublished {
    return status == 'published';
  }

  // ═════════════════════════════════════════════
  // هل التقييم قيد المراجعة؟
  // ═════════════════════════════════════════════

  bool get isPending {
    return status == 'pending';
  }

  // ═════════════════════════════════════════════
  // هل التقييم مخفي؟
  // ═════════════════════════════════════════════

  bool get isHidden {
    return status == 'hidden';
  }

  // ═════════════════════════════════════════════
  // هل التقييم يحتوي على تعليق؟
  // ═════════════════════════════════════════════

  bool get hasComment {
    return comment.trim().isNotEmpty;
  }

  // ═════════════════════════════════════════════
  // إضافة رد صاحب المكتب
  // ═════════════════════════════════════════════

  OfficeReviewModel addOwnerReply(String reply) {
    final trimmedReply = reply.trim();

    return copyWith(
      hasOwnerReply: trimmedReply.isNotEmpty,
      ownerReply: trimmedReply,
      updatedAt: DateTime.now(),
    );
  }

  // ═════════════════════════════════════════════
  // حذف رد صاحب المكتب
  // ═════════════════════════════════════════════

  OfficeReviewModel removeOwnerReply() {
    return copyWith(
      hasOwnerReply: false,
      ownerReply: '',
      updatedAt: DateTime.now(),
    );
  }

  // ═════════════════════════════════════════════
  // إخفاء التقييم
  // ═════════════════════════════════════════════

  OfficeReviewModel hide() {
    return copyWith(
      status: 'hidden',
      updatedAt: DateTime.now(),
    );
  }

  // ═════════════════════════════════════════════
  // إعادة نشر التقييم
  // ═════════════════════════════════════════════

  OfficeReviewModel publish() {
    return copyWith(
      status: 'published',
      updatedAt: DateTime.now(),
    );
  }

  // ═════════════════════════════════════════════
  // تعديل التقييم
  // ═════════════════════════════════════════════

  OfficeReviewModel copyWith({
    String? id,
    String? officeId,
    String? userId,
    String? userName,
    String? userImageUrl,
    double? rating,
    String? comment,
    String? status,
    bool? hasOwnerReply,
    String? ownerReply,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfficeReviewModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userImageUrl: userImageUrl ?? this.userImageUrl,
      rating: rating != null ? _normalizeRating(rating) : this.rating,
      comment: comment ?? this.comment,
      status: status ?? this.status,
      hasOwnerReply: hasOwnerReply ?? this.hasOwnerReply,
      ownerReply: ownerReply ?? this.ownerReply,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ═════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════

  static double _normalizeRating(double value) {
    if (value < 1) {
      return 1;
    }

    if (value > 5) {
      return 5;
    }

    return value;
  }

  static double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static DateTime? _dateValue(dynamic value) {
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
