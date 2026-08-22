import 'package:flutter/material.dart';

/// حالات اشتراك المكتب.
///
/// ملاحظة مهمة:
/// هذه الحالة مستقلة عن OfficeStatus.
/// المكتب قد يكون نشطًا، لكن اشتراكه منتهي.
/// لذلك لا نخلط بين حالة المكتب وحالة الاشتراك.
enum OfficeSubscriptionStatus {
  trial,
  active,
  expiringSoon,
  expired,
  suspended,
  cancelled,
  none,
}

/// أدوات التعامل مع حالة اشتراك المكتب.
class OfficeSubscriptionStatusUtils {
  const OfficeSubscriptionStatusUtils._();

  // ═════════════════════════════════════════════
  // تحويل النص إلى الحالة
  // ═════════════════════════════════════════════

  static OfficeSubscriptionStatus fromString(
    String? value,
  ) {
    switch (value?.trim().toLowerCase()) {
      case 'trial':
        return OfficeSubscriptionStatus.trial;

      case 'active':
        return OfficeSubscriptionStatus.active;

      case 'expiring_soon':
      case 'expiringsoon':
        return OfficeSubscriptionStatus.expiringSoon;

      case 'expired':
        return OfficeSubscriptionStatus.expired;

      case 'suspended':
        return OfficeSubscriptionStatus.suspended;

      case 'cancelled':
      case 'canceled':
        return OfficeSubscriptionStatus.cancelled;

      case 'none':
        return OfficeSubscriptionStatus.none;

      default:
        return OfficeSubscriptionStatus.none;
    }
  }

  // ═════════════════════════════════════════════
  // تحويل الحالة إلى نص
  // ═════════════════════════════════════════════

  static String toStringValue(
    OfficeSubscriptionStatus status,
  ) {
    switch (status) {
      case OfficeSubscriptionStatus.trial:
        return 'trial';

      case OfficeSubscriptionStatus.active:
        return 'active';

      case OfficeSubscriptionStatus.expiringSoon:
        return 'expiring_soon';

      case OfficeSubscriptionStatus.expired:
        return 'expired';

      case OfficeSubscriptionStatus.suspended:
        return 'suspended';

      case OfficeSubscriptionStatus.cancelled:
        return 'cancelled';

      case OfficeSubscriptionStatus.none:
        return 'none';
    }
  }

  // ═════════════════════════════════════════════
  // الاسم العربي
  // ═════════════════════════════════════════════

  static String label(
    OfficeSubscriptionStatus status,
  ) {
    switch (status) {
      case OfficeSubscriptionStatus.trial:
        return 'فترة تجريبية';

      case OfficeSubscriptionStatus.active:
        return 'اشتراك فعال';

      case OfficeSubscriptionStatus.expiringSoon:
        return 'الاشتراك على وشك الانتهاء';

      case OfficeSubscriptionStatus.expired:
        return 'الاشتراك منتهي';

      case OfficeSubscriptionStatus.suspended:
        return 'الاشتراك موقوف';

      case OfficeSubscriptionStatus.cancelled:
        return 'الاشتراك ملغي';

      case OfficeSubscriptionStatus.none:
        return 'لا يوجد اشتراك';
    }
  }

  // ═════════════════════════════════════════════
  // الوصف
  // ═════════════════════════════════════════════

  static String description(
    OfficeSubscriptionStatus status,
  ) {
    switch (status) {
      case OfficeSubscriptionStatus.trial:
        return 'المكتب يستخدم الفترة التجريبية.';

      case OfficeSubscriptionStatus.active:
        return 'اشتراك المكتب فعال حاليًا.';

      case OfficeSubscriptionStatus.expiringSoon:
        return 'اشتراك المكتب سينتهي قريبًا.';

      case OfficeSubscriptionStatus.expired:
        return 'انتهت مدة اشتراك المكتب.';

      case OfficeSubscriptionStatus.suspended:
        return 'تم إيقاف اشتراك المكتب من الإدارة.';

      case OfficeSubscriptionStatus.cancelled:
        return 'تم إلغاء اشتراك المكتب.';

      case OfficeSubscriptionStatus.none:
        return 'لا يوجد اشتراك فعال للمكتب.';
    }
  }

  // ═════════════════════════════════════════════
  // اللون
  // ═════════════════════════════════════════════

  static Color color(
    OfficeSubscriptionStatus status,
  ) {
    switch (status) {
      case OfficeSubscriptionStatus.trial:
        return const Color(0xFF38BDF8);

      case OfficeSubscriptionStatus.active:
        return const Color(0xFF22C55E);

      case OfficeSubscriptionStatus.expiringSoon:
        return const Color(0xFFFFB020);

      case OfficeSubscriptionStatus.expired:
        return const Color(0xFFEF4444);

      case OfficeSubscriptionStatus.suspended:
        return const Color(0xFFDC2626);

      case OfficeSubscriptionStatus.cancelled:
        return const Color(0xFF64748B);

      case OfficeSubscriptionStatus.none:
        return const Color(0xFF94A3B8);
    }
  }

  // ═════════════════════════════════════════════
  // الأيقونة
  // ═════════════════════════════════════════════

  static IconData icon(
    OfficeSubscriptionStatus status,
  ) {
    switch (status) {
      case OfficeSubscriptionStatus.trial:
        return Icons.timer_outlined;

      case OfficeSubscriptionStatus.active:
        return Icons.verified_outlined;

      case OfficeSubscriptionStatus.expiringSoon:
        return Icons.warning_amber_rounded;

      case OfficeSubscriptionStatus.expired:
        return Icons.event_busy_outlined;

      case OfficeSubscriptionStatus.suspended:
        return Icons.pause_circle_outline_rounded;

      case OfficeSubscriptionStatus.cancelled:
        return Icons.cancel_outlined;

      case OfficeSubscriptionStatus.none:
        return Icons.remove_circle_outline_rounded;
    }
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك يسمح بالعمل؟
  // ═════════════════════════════════════════════

  static bool isUsable(
    OfficeSubscriptionStatus status,
  ) {
    return status == OfficeSubscriptionStatus.trial ||
        status == OfficeSubscriptionStatus.active ||
        status == OfficeSubscriptionStatus.expiringSoon;
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك منتهي؟
  // ═════════════════════════════════════════════

  static bool isExpired(
    OfficeSubscriptionStatus status,
  ) {
    return status == OfficeSubscriptionStatus.expired;
  }

  // ═════════════════════════════════════════════
  // هل الاشتراك موقوف؟
  // ═════════════════════════════════════════════

  static bool isSuspended(
    OfficeSubscriptionStatus status,
  ) {
    return status == OfficeSubscriptionStatus.suspended;
  }

  // ═════════════════════════════════════════════
  // هل يمكن للمكتب نشر العقارات؟
  // ═════════════════════════════════════════════

  static bool canPublishProperties(
    OfficeSubscriptionStatus status,
  ) {
    return isUsable(status);
  }

  // ═════════════════════════════════════════════
  // هل يمكن للمكتب تعديل بياناته؟
  // ═════════════════════════════════════════════

  static bool canEditOffice(
    OfficeSubscriptionStatus status,
  ) {
    return status != OfficeSubscriptionStatus.cancelled &&
        status != OfficeSubscriptionStatus.suspended;
  }

  // ═════════════════════════════════════════════
  // هل يمكن عرض المكتب للعامة؟
  // ═════════════════════════════════════════════

  static bool canBePubliclyVisible(
    OfficeSubscriptionStatus status,
  ) {
    return isUsable(status);
  }

  // ═════════════════════════════════════════════
  // حساب الحالة تلقائيًا اعتمادًا على تاريخ الانتهاء
  // ═════════════════════════════════════════════

  /// إذا كان الاشتراك:
  ///
  /// - منتهي → expired
  /// - بقي عليه عدد أيام أقل أو يساوي warningDays → expiringSoon
  /// - غير ذلك → active
  ///
  /// هذه الدالة لا تقوم بتعديل Firestore.
  /// هي فقط تحسب الحالة الحالية.
  static OfficeSubscriptionStatus calculateFromDates({
    required DateTime? startDate,
    required DateTime? endDate,
    DateTime? now,
    int warningDays = 7,
    bool isTrial = false,
  }) {
    if (endDate == null) {
      return OfficeSubscriptionStatus.none;
    }

    final currentDate = now ?? DateTime.now();

    if (endDate.isBefore(currentDate)) {
      return OfficeSubscriptionStatus.expired;
    }

    if (isTrial) {
      return OfficeSubscriptionStatus.trial;
    }

    final remaining = endDate.difference(currentDate);

    if (remaining.inDays <= warningDays) {
      return OfficeSubscriptionStatus.expiringSoon;
    }

    return OfficeSubscriptionStatus.active;
  }

  // ═════════════════════════════════════════════
  // الأيام المتبقية
  // ═════════════════════════════════════════════

  static int remainingDays(
    DateTime? endDate, {
    DateTime? now,
  }) {
    if (endDate == null) {
      return 0;
    }

    final currentDate = now ?? DateTime.now();

    if (endDate.isBefore(currentDate)) {
      return 0;
    }

    final difference = endDate.difference(currentDate);

    return difference.inDays;
  }
}
