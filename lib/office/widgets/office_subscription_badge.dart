import 'package:flutter/material.dart';

import '../models/office_model.dart';

/// شارة حالة اشتراك المكتب.
///
/// الحالات:
/// - فعال
/// - قريب الانتهاء
/// - منتهي
/// - موقوف
/// - ملغى
/// - غير مشترك
class OfficeSubscriptionBadge extends StatelessWidget {
  final OfficeModel office;

  /// عدد الأيام التي نعتبر بعدها الاشتراك قريب الانتهاء.
  final int warningDays;

  const OfficeSubscriptionBadge({
    super.key,
    required this.office,
    this.warningDays = 7,
  });

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status.color.withValues(
            alpha: 0.35,
          ),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            size: 14,
            color: status.color,
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // تحديد حالة الاشتراك
  // ═════════════════════════════════════════════

  _SubscriptionBadgeStatus _resolveStatus() {
    final status = _readSubscriptionStatus();

    final normalizedStatus = status.trim().toLowerCase();

    final endDate = _readSubscriptionEndDate();

    // إذا كان هناك تاريخ انتهاء وانتهى فعليًا،
    // نعتبر الاشتراك منتهيًا مهما كانت قيمة status.
    if (endDate != null && !endDate.isAfter(DateTime.now())) {
      return _SubscriptionBadgeStatus.expired;
    }

    if (normalizedStatus == 'expired' ||
        normalizedStatus == 'منتهي' ||
        normalizedStatus == 'انتهى') {
      return _SubscriptionBadgeStatus.expired;
    }

    if (normalizedStatus == 'suspended' ||
        normalizedStatus == 'موقوف' ||
        normalizedStatus == 'متوقف') {
      return _SubscriptionBadgeStatus.suspended;
    }

    if (normalizedStatus == 'cancelled' ||
        normalizedStatus == 'canceled' ||
        normalizedStatus == 'ملغي' ||
        normalizedStatus == 'ملغى') {
      return _SubscriptionBadgeStatus.cancelled;
    }

    if (normalizedStatus == 'pending' || normalizedStatus == 'قيد الانتظار') {
      return _SubscriptionBadgeStatus.pending;
    }

    if (endDate != null) {
      final remaining = endDate.difference(DateTime.now());

      if (remaining.inDays <= warningDays && remaining.inSeconds > 0) {
        return _SubscriptionBadgeStatus.expiringSoon;
      }
    }

    if (normalizedStatus == 'active' ||
        normalizedStatus == 'فعال' ||
        normalizedStatus == 'نشط') {
      return _SubscriptionBadgeStatus.active;
    }

    return _SubscriptionBadgeStatus.notSubscribed;
  }

  // ═════════════════════════════════════════════
  // قراءة حالة الاشتراك من OfficeModel
  // ═════════════════════════════════════════════

  String _readSubscriptionStatus() {
    return office.subscriptionStatus?.toString() ?? '';
  }

  // ═════════════════════════════════════════════
  // قراءة تاريخ انتهاء الاشتراك
  // ═════════════════════════════════════════════

  DateTime? _readSubscriptionEndDate() {
    final value = office.subscriptionEndDate;

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}

// ═══════════════════════════════════════════════
// حالات الشارة
// ═══════════════════════════════════════════════

class _SubscriptionBadgeStatus {
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;

  const _SubscriptionBadgeStatus({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });

  static const active = _SubscriptionBadgeStatus(
    label: 'اشتراك فعال',
    color: Color(0xFF4CAF50),
    backgroundColor: Color(0x1A4CAF50),
    icon: Icons.verified_rounded,
  );

  static const expiringSoon = _SubscriptionBadgeStatus(
    label: 'قريب الانتهاء',
    color: Color(0xFFFFB300),
    backgroundColor: Color(0x1AFFB300),
    icon: Icons.schedule_rounded,
  );

  static const expired = _SubscriptionBadgeStatus(
    label: 'اشتراك منتهي',
    color: Color(0xFFE53935),
    backgroundColor: Color(0x1AE53935),
    icon: Icons.error_outline_rounded,
  );

  static const suspended = _SubscriptionBadgeStatus(
    label: 'اشتراك موقوف',
    color: Color(0xFFFF7043),
    backgroundColor: Color(0x1AFF7043),
    icon: Icons.pause_circle_outline_rounded,
  );

  static const cancelled = _SubscriptionBadgeStatus(
    label: 'اشتراك ملغى',
    color: Color(0xFF9E9E9E),
    backgroundColor: Color(0x1A9E9E9E),
    icon: Icons.cancel_outlined,
  );

  static const pending = _SubscriptionBadgeStatus(
    label: 'قيد التفعيل',
    color: Color(0xFF42A5F5),
    backgroundColor: Color(0x1A42A5F5),
    icon: Icons.hourglass_top_rounded,
  );

  static const notSubscribed = _SubscriptionBadgeStatus(
    label: 'غير مشترك',
    color: Color(0xFF9E9E9E),
    backgroundColor: Color(0x1A9E9E9E),
    icon: Icons.remove_circle_outline_rounded,
  );
}
