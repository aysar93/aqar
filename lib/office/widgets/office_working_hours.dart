import 'package:flutter/material.dart';

/// أوقات عمل المكتب.
///
/// يقبل البيانات بهذا الشكل:
/// {
///   'السبت': '09:00 - 21:00',
///   'الأحد': '09:00 - 21:00',
///   ...
/// }
///
/// ويمكن لاحقًا لصاحب المكتب تعديلها من صفحة تعديل المكتب.
class OfficeWorkingHours extends StatelessWidget {
  final Map<String, String> workingHours;

  /// اليوم الحالي الذي سيتم تمييزه.
  ///
  /// إذا كان null يتم تحديد اليوم تلقائيًا.
  final String? currentDay;

  /// هل نعرض الأيام المغلقة؟
  final bool showClosedDays;

  const OfficeWorkingHours({
    super.key,
    required this.workingHours,
    this.currentDay,
    this.showClosedDays = true,
  });

  @override
  Widget build(BuildContext context) {
    if (workingHours.isEmpty) {
      return const SizedBox.shrink();
    }

    final days = _orderedDays();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTitle(context),
          const SizedBox(height: 14),
          ...days.map(
            (day) => _buildDayRow(
              context,
              day,
              workingHours[day],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // العنوان
  // ═════════════════════════════════════════════

  Widget _buildTitle(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'أوقات العمل',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.access_time_rounded,
            size: 19,
            color: Color(0xFFD4AF37),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // صف اليوم
  // ═════════════════════════════════════════════

  Widget _buildDayRow(
    BuildContext context,
    String day,
    String? hours,
  ) {
    final isToday = day == _currentDay;
    final isClosed = _isClosed(hours);

    if (isClosed && !showClosedDays) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 7,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFFD4AF37).withValues(
                alpha: 0.09,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _displayHours(hours),
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isClosed
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'اليوم',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              day,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color:
                    isToday ? const Color(0xFFD4AF37) : colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // ترتيب الأيام
  // ═════════════════════════════════════════════

  List<String> _orderedDays() {
    const order = [
      'السبت',
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
    ];

    final availableDays = <String>[];

    for (final day in order) {
      if (workingHours.containsKey(day)) {
        availableDays.add(day);
      }
    }

    // إذا كانت هناك أيام إضافية غير موجودة
    // في القائمة القياسية، نضيفها في النهاية.
    for (final day in workingHours.keys) {
      if (!availableDays.contains(day)) {
        availableDays.add(day);
      }
    }

    return availableDays;
  }

  // ═════════════════════════════════════════════
  // اليوم الحالي
  // ═════════════════════════════════════════════

  String? get _currentDay {
    if (currentDay != null && currentDay!.trim().isNotEmpty) {
      return currentDay;
    }

    switch (DateTime.now().weekday) {
      case DateTime.saturday:
        return 'السبت';

      case DateTime.sunday:
        return 'الأحد';

      case DateTime.monday:
        return 'الاثنين';

      case DateTime.tuesday:
        return 'الثلاثاء';

      case DateTime.wednesday:
        return 'الأربعاء';

      case DateTime.thursday:
        return 'الخميس';

      case DateTime.friday:
        return 'الجمعة';

      default:
        return null;
    }
  }

  // ═════════════════════════════════════════════
  // هل المكتب مغلق؟
  // ═════════════════════════════════════════════

  bool _isClosed(String? hours) {
    if (hours == null) {
      return true;
    }

    final normalized = hours.trim().toLowerCase();

    if (normalized.isEmpty) {
      return true;
    }

    return normalized == 'مغلق' ||
        normalized == 'مغلق اليوم' ||
        normalized == 'closed' ||
        normalized == 'off';
  }

  // ═════════════════════════════════════════════
  // عرض وقت العمل
  // ═════════════════════════════════════════════

  String _displayHours(String? hours) {
    if (_isClosed(hours)) {
      return 'مغلق';
    }

    return hours!.trim();
  }
}
