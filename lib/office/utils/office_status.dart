import 'package:flutter/material.dart';

/// حالات المكتب داخل تطبيق عقار.
///
/// هذه الحالات تخص حالة المكتب نفسه، وليست حالة الاشتراك.
/// حالة الاشتراك سيتم التعامل معها بشكل منفصل في:
/// office_subscription_status.dart
enum OfficeStatus {
  pending,
  active,
  suspended,
  rejected,
  archived,
}

/// أدوات التعامل مع حالة المكتب.
class OfficeStatusUtils {
  const OfficeStatusUtils._();

  // ═════════════════════════════════════════════
  // تحويل النص إلى الحالة
  // ═════════════════════════════════════════════

  static OfficeStatus fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'pending':
        return OfficeStatus.pending;

      case 'active':
        return OfficeStatus.active;

      case 'suspended':
        return OfficeStatus.suspended;

      case 'rejected':
        return OfficeStatus.rejected;

      case 'archived':
        return OfficeStatus.archived;

      default:
        return OfficeStatus.pending;
    }
  }

  // ═════════════════════════════════════════════
  // تحويل الحالة إلى نص
  // ═════════════════════════════════════════════

  static String toStringValue(
    OfficeStatus status,
  ) {
    switch (status) {
      case OfficeStatus.pending:
        return 'pending';

      case OfficeStatus.active:
        return 'active';

      case OfficeStatus.suspended:
        return 'suspended';

      case OfficeStatus.rejected:
        return 'rejected';

      case OfficeStatus.archived:
        return 'archived';
    }
  }

  // ═════════════════════════════════════════════
  // الاسم العربي
  // ═════════════════════════════════════════════

  static String label(
    OfficeStatus status,
  ) {
    switch (status) {
      case OfficeStatus.pending:
        return 'قيد المراجعة';

      case OfficeStatus.active:
        return 'نشط';

      case OfficeStatus.suspended:
        return 'موقوف';

      case OfficeStatus.rejected:
        return 'مرفوض';

      case OfficeStatus.archived:
        return 'مؤرشف';
    }
  }

  // ═════════════════════════════════════════════
  // الوصف
  // ═════════════════════════════════════════════

  static String description(
    OfficeStatus status,
  ) {
    switch (status) {
      case OfficeStatus.pending:
        return 'طلب المكتب قيد المراجعة من الإدارة.';

      case OfficeStatus.active:
        return 'المكتب نشط ويمكن عرضه للمستخدمين.';

      case OfficeStatus.suspended:
        return 'تم إيقاف المكتب مؤقتًا من الإدارة.';

      case OfficeStatus.rejected:
        return 'تم رفض طلب إنشاء المكتب.';

      case OfficeStatus.archived:
        return 'تم أرشفة المكتب ولم يعد نشطًا.';
    }
  }

  // ═════════════════════════════════════════════
  // اللون
  // ═════════════════════════════════════════════

  static Color color(
    OfficeStatus status,
  ) {
    switch (status) {
      case OfficeStatus.pending:
        return const Color(0xFFFFB020);

      case OfficeStatus.active:
        return const Color(0xFF22C55E);

      case OfficeStatus.suspended:
        return const Color(0xFFEF4444);

      case OfficeStatus.rejected:
        return const Color(0xFFDC2626);

      case OfficeStatus.archived:
        return const Color(0xFF64748B);
    }
  }

  // ═════════════════════════════════════════════
  // الأيقونة
  // ═════════════════════════════════════════════

  static IconData icon(
    OfficeStatus status,
  ) {
    switch (status) {
      case OfficeStatus.pending:
        return Icons.pending_actions_rounded;

      case OfficeStatus.active:
        return Icons.check_circle_outline_rounded;

      case OfficeStatus.suspended:
        return Icons.pause_circle_outline_rounded;

      case OfficeStatus.rejected:
        return Icons.cancel_outlined;

      case OfficeStatus.archived:
        return Icons.archive_outlined;
    }
  }

  // ═════════════════════════════════════════════
  // هل المكتب ظاهر للمستخدمين؟
  // ═════════════════════════════════════════════

  static bool isPubliclyVisible(
    OfficeStatus status,
  ) {
    return status == OfficeStatus.active;
  }

  // ═════════════════════════════════════════════
  // هل يمكن تعديل المكتب؟
  // ═════════════════════════════════════════════

  static bool canEdit(
    OfficeStatus status,
  ) {
    return status == OfficeStatus.active || status == OfficeStatus.pending;
  }

  // ═════════════════════════════════════════════
  // هل يمكن نشر العقارات؟
  // ═════════════════════════════════════════════

  static bool canPublishProperties(
    OfficeStatus status,
  ) {
    return status == OfficeStatus.active;
  }

  // ═════════════════════════════════════════════
  // هل الحالة نهائية؟
  // ═════════════════════════════════════════════

  static bool isFinal(
    OfficeStatus status,
  ) {
    return status == OfficeStatus.rejected || status == OfficeStatus.archived;
  }
}
