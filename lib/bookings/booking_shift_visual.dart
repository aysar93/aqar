import 'package:flutter/material.dart';

/// Canonical period categories used across chalets, farms, halls, and bookings.
enum BookingShiftKind { morning, evening, fullDay, other }

/// Unified visual specification for booking periods (morning, evening, full day)
/// shared between Android and iOS in both light and dark modes.
class BookingShiftVisual {
  const BookingShiftVisual({
    required this.kind,
    required this.label,
    required this.icon,
    required this.lightForeground,
    required this.darkForeground,
    required this.lightBackground,
    required this.darkBackground,
    required this.lightBorder,
    required this.darkBorder,
    required this.accentColor,
  });

  final BookingShiftKind kind;
  final String label;
  final IconData icon;
  final Color lightForeground;
  final Color darkForeground;
  final Color lightBackground;
  final Color darkBackground;
  final Color lightBorder;
  final Color darkBorder;
  final Color accentColor;

  Color foreground(Brightness brightness) =>
      brightness == Brightness.dark ? darkForeground : lightForeground;

  Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  Color border(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : lightBorder;

  static const _morningSpec = BookingShiftVisual(
    kind: BookingShiftKind.morning,
    label: 'صباحي',
    icon: Icons.wb_sunny_rounded,
    lightForeground: Color(0xFFB45309),
    darkForeground: Color(0xFFFBBF24),
    lightBackground: Color(0xFFFEF3C7),
    darkBackground: Color(0x33F59E0B),
    lightBorder: Color(0x66D97706),
    darkBorder: Color(0x80FBBF24),
    accentColor: Color(0xFFD97706),
  );

  static const _eveningSpec = BookingShiftVisual(
    kind: BookingShiftKind.evening,
    label: 'مسائي',
    icon: Icons.nights_stay_rounded,
    lightForeground: Color(0xFF3730A3),
    darkForeground: Color(0xFF93C5FD),
    lightBackground: Color(0xFFE0E7FF),
    darkBackground: Color(0x333B82F6),
    lightBorder: Color(0x664F46E5),
    darkBorder: Color(0x8093C5FD),
    accentColor: Color(0xFF4F46E5),
  );

  static const _fullDaySpec = BookingShiftVisual(
    kind: BookingShiftKind.fullDay,
    label: 'يوم كامل',
    icon: Icons.timelapse_rounded,
    lightForeground: Color(0xFF047857),
    darkForeground: Color(0xFF34D399),
    lightBackground: Color(0xFFD1FAE5),
    darkBackground: Color(0x3310B981),
    lightBorder: Color(0x66059669),
    darkBorder: Color(0x8034D399),
    accentColor: Color(0xFF059669),
  );

  static const _otherSpec = BookingShiftVisual(
    kind: BookingShiftKind.other,
    label: 'فترة مخصصة',
    icon: Icons.schedule_rounded,
    lightForeground: Color(0xFF334155),
    darkForeground: Color(0xFFE2E8F0),
    lightBackground: Color(0xFFF1F5F9),
    darkBackground: Color(0x3364748B),
    lightBorder: Color(0x6664748B),
    darkBorder: Color(0x8094A3B8),
    accentColor: Color(0xFFD4AF37),
  );

  static BookingShiftVisual specForKind(BookingShiftKind kind, {String? label}) {
    final base = switch (kind) {
      BookingShiftKind.morning => _morningSpec,
      BookingShiftKind.evening => _eveningSpec,
      BookingShiftKind.fullDay => _fullDaySpec,
      BookingShiftKind.other => _otherSpec,
    };
    final trimmed = label?.trim() ?? '';
    if (trimmed.isEmpty) return base;
    return BookingShiftVisual(
      kind: base.kind,
      label: trimmed,
      icon: base.icon,
      lightForeground: base.lightForeground,
      darkForeground: base.darkForeground,
      lightBackground: base.lightBackground,
      darkBackground: base.darkBackground,
      lightBorder: base.lightBorder,
      darkBorder: base.darkBorder,
      accentColor: base.accentColor,
    );
  }

  /// Classifies a shift reliably from structured keys first, then label, then
  /// check-in/out minutes in Baghdad local time.
  static BookingShiftKind classify({
    String? kind,
    String? id,
    String? name,
    int? checkInMinute,
    int? checkOutMinute,
  }) {
    final structured = [kind, id]
        .whereType<String>()
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final token in structured) {
      if (token == 'full_day' || token == 'fullday' || token == '24h') {
        return BookingShiftKind.fullDay;
      }
      if (token == 'evening' || token == 'night' || token == 'pm' ||
          token == 'shift_evening' || token == 'shift_night') {
        return BookingShiftKind.evening;
      }
      if (token == 'morning' || token == 'am' || token == 'shift_morning') {
        return BookingShiftKind.morning;
      }
    }

    final text = '${name ?? ''} ${id ?? ''} ${kind ?? ''}'.trim().toLowerCase();
    if (text.contains('كامل') ||
        text.contains('24') ||
        text.contains('fullday') ||
        text.contains('full_day') ||
        text.contains('full day')) {
      return BookingShiftKind.fullDay;
    }
    if (text.contains('مساء') ||
        text.contains('مسائ') ||
        text.contains('ليل') ||
        text.contains('evening') ||
        text.contains('night')) {
      return BookingShiftKind.evening;
    }
    if (text.contains('صباح') ||
        text.contains('صبح') ||
        text.contains('نهار') ||
        text.contains('morning')) {
      return BookingShiftKind.morning;
    }

    if (checkInMinute != null) {
      if (checkOutMinute != null) {
        final duration = ((checkOutMinute - checkInMinute) + 1440) % 1440;
        if (duration == 0 || duration >= 1200) {
          return BookingShiftKind.fullDay;
        }
      }
      if (checkInMinute >= 780 || checkInMinute < 240) {
        return BookingShiftKind.evening;
      }
      return BookingShiftKind.morning;
    }
    return BookingShiftKind.other;
  }

  /// Resolves visual configuration from either a shift/pricing Map or a String.
  static BookingShiftVisual resolve(
    dynamic shiftOrPricing, {
    String? fallbackLabel,
  }) {
    if (shiftOrPricing is Map) {
      final kindStr = shiftOrPricing['kind']?.toString();
      final idStr = shiftOrPricing['id']?.toString();
      final nameStr = shiftOrPricing['name']?.toString();
      final modeStr = shiftOrPricing['mode']?.toString();
      final startRaw = shiftOrPricing['checkInMinute'] ?? shiftOrPricing['startMinute'];
      final endRaw = shiftOrPricing['checkOutMinute'] ?? shiftOrPricing['endMinute'];
      final kind = classify(
        kind: kindStr,
        id: idStr,
        name: nameStr ?? (modeStr == 'shifts' ? null : modeStr),
        checkInMinute: startRaw is num ? startRaw.toInt() : null,
        checkOutMinute: endRaw is num ? endRaw.toInt() : null,
      );
      final displayName = (nameStr != null && nameStr.trim().isNotEmpty)
          ? nameStr.trim()
          : (fallbackLabel ?? '');
      return specForKind(kind, label: displayName.isNotEmpty ? displayName : null);
    }
    final text = shiftOrPricing?.toString().trim() ?? '';
    final kind = classify(name: text);
    return specForKind(
      kind,
      label: text.isNotEmpty ? text : fallbackLabel,
    );
  }
}

/// Accessible pill badge for booking shift periods with distinct morning/evening
/// icons and contrast-safe colors across light and dark modes.
class BookingPeriodBadge extends StatelessWidget {
  const BookingPeriodBadge({
    super.key,
    required this.shift,
    this.compact = false,
    this.iconOnly = false,
  });

  final dynamic shift;
  final bool compact;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final visual = BookingShiftVisual.resolve(shift);
    final brightness = Theme.of(context).brightness;
    final fg = visual.foreground(brightness);
    final bg = visual.background(brightness);
    final border = visual.border(brightness);
    final iconSize = compact ? 13.0 : 16.0;

    return Semantics(
      label: 'الفترة: ${visual.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(color: border, width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visual.icon, size: iconSize, color: fg),
            if (!iconOnly) ...[
              SizedBox(width: compact ? 4 : 6),
              Flexible(
                child: Text(
                  visual.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: compact ? 10.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
