import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج متابعة مكتب.
///
/// يمثل علاقة بين مستخدم ومكتب قام المستخدم بمتابعته.
class OfficeFollowerModel {
  final String id;

  // ─────────────────────────────────────────────
  // العلاقات
  // ─────────────────────────────────────────────

  final String officeId;
  final String userId;

  // ─────────────────────────────────────────────
  // معلومات المستخدم
  // ─────────────────────────────────────────────

  final String userName;
  final String userImageUrl;

  // ─────────────────────────────────────────────
  // حالة المتابعة
  // ─────────────────────────────────────────────

  final bool isActive;

  // ─────────────────────────────────────────────
  // التواريخ
  // ─────────────────────────────────────────────

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OfficeFollowerModel({
    required this.id,
    required this.officeId,
    required this.userId,
    this.userName = '',
    this.userImageUrl = '',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  // ═════════════════════════════════════════════
  // إنشاء متابعة جديدة
  // ═════════════════════════════════════════════

  factory OfficeFollowerModel.create({
    required String id,
    required String officeId,
    required String userId,
    String userName = '',
    String userImageUrl = '',
  }) {
    final now = DateTime.now();

    return OfficeFollowerModel(
      id: id,
      officeId: officeId,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ═════════════════════════════════════════════
  // Firestore → Model
  // ═════════════════════════════════════════════

  factory OfficeFollowerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return OfficeFollowerModel(
      id: document.id,
      officeId: data['officeId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userImageUrl: data['userImageUrl'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
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
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // ═════════════════════════════════════════════
  // إلغاء المتابعة
  // ═════════════════════════════════════════════

  OfficeFollowerModel deactivate() {
    return copyWith(
      isActive: false,
      updatedAt: DateTime.now(),
    );
  }

  // ═════════════════════════════════════════════
  // إعادة المتابعة
  // ═════════════════════════════════════════════

  OfficeFollowerModel activate() {
    return copyWith(
      isActive: true,
      updatedAt: DateTime.now(),
    );
  }

  // ═════════════════════════════════════════════
  // نسخة جديدة
  // ═════════════════════════════════════════════

  OfficeFollowerModel copyWith({
    String? id,
    String? officeId,
    String? userId,
    String? userName,
    String? userImageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfficeFollowerModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userImageUrl: userImageUrl ?? this.userImageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ═════════════════════════════════════════════
  // Helper
  // ═════════════════════════════════════════════

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
