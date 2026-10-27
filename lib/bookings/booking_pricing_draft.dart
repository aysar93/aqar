import 'dart:math' as math;

// Local-only v2 proposal. The live booking quote still uses the deployed v1 policy.
class BookingPricingDraft {
  BookingPricingDraft(Map<String, dynamic> source) : data = _copy(source) {
    validate();
  }
  final Map<String, dynamic> data;

  static const kindLabels = <String, String>{
    'morning': 'الفترة الصباحية',
    'evening': 'الفترة المسائية',
    'full_day': 'اليوم الكامل'
  };

  static const dayLabels = <int, String>{
    0: 'الأحد',
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت'
  };

  static BookingPricingDraft? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return BookingPricingDraft(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static BookingPricingDraft? fromVenue(Map<String, dynamic> venue) =>
      tryParse(venue['pricingDraft'] ?? venue['pricing']);

  static int? venueDeposit(Map<String, dynamic> venue) {
    final v1 = venue['deposit'] is int && (venue['deposit'] as int) > 0
        ? venue['deposit'] as int
        : null;
    final draft = fromVenue(venue);
    final v2 = draft != null ? draft.deposit : null;
    if (v1 != null && v2 != null) {
      if (v1 != v2) {
        throw const FormatException(
            'تعارض بين عربون المكان وعربون التسعير المتقدم');
      }
      return v1;
    }
    return v2 ?? v1;
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> p) => {
        ...p,
        'weekendDays': List<int>.from(p['weekendDays'] as List? ?? []),
        'shifts': [
          for (final s in p['shifts'] as List? ?? [])
            Map<String, dynamic>.from(s as Map)
        ]
      };
  static bool _money(dynamic n) => n is int && n > 0 && n <= 9007199254740991;
  void validate() {
    if (data['version'] != 2 ||
        data['timeZone'] != 'Asia/Baghdad' ||
        !_money(data['deposit']))
      throw const FormatException('سياسة غير صالحة');
    final days = data['weekendDays'] as List<int>;
    if (days.toSet().length != days.length || days.any((d) => d < 0 || d > 6))
      throw const FormatException('أيام عطلة غير صالحة');
    final shifts = data['shifts'] as List;
    if (shifts.length != 3) throw const FormatException('ثلاثة تعريفات مطلوبة');
    final kinds = <String>{};
    var active = 0;
    for (final raw in shifts) {
      final s = raw as Map<String, dynamic>;
      if (!['morning', 'evening', 'full_day'].contains(s['kind']) ||
          !kinds.add(s['kind']) ||
          s['enabled'] is! bool)
        throw const FormatException('نوع فترة غير صالح');
      if (s['enabled'] != true) continue;
      active++;
      final a = s['startMinute'],
          b = s['endMinute'],
          offset = s['endDayOffset'];
      if (a is! int ||
          b is! int ||
          a < 0 ||
          a >= 1440 ||
          b < 0 ||
          b >= 1440 ||
          offset is! int ||
          ![0, 1].contains(offset)) throw const FormatException('وقت غير صالح');
      final duration = b + offset * 1440 - a;
      if (duration <= 0 ||
          duration > 1440 ||
          !_money(s['weekdayPrice']) ||
          !_money(s['weekendPrice']) ||
          data['deposit'] > s['weekdayPrice'] ||
          data['deposit'] > s['weekendPrice'])
        throw const FormatException('سعر أو مدة أو عربون غير صالح');
    }
    if (active == 0) throw const FormatException('لا توجد فترة مفعلة');
  }

  List<Map<String, dynamic>> get enabledShifts {
    final raw = (data['shifts'] as List).cast<Map<String, dynamic>>();
    final ordered = <Map<String, dynamic>>[];
    for (final kind in const ['morning', 'evening', 'full_day']) {
      final s =
          raw.where((e) => e['kind'] == kind && e['enabled'] == true).firstOrNull;
      if (s != null) {
        final weekday = s['weekdayPrice'] as int;
        final weekend = s['weekendPrice'] as int;
        ordered.add({
          'id': kind,
          'kind': kind,
          'name': (s['name'] is String && (s['name'] as String).trim().isNotEmpty)
              ? '${s['name']}'
              : (kindLabels[kind] ?? kind),
          'checkInMinute': s['startMinute'] as int,
          'checkOutMinute': s['endMinute'] as int,
          'startMinute': s['startMinute'] as int,
          'endMinute': s['endMinute'] as int,
          'endDayOffset': s['endDayOffset'] as int,
          'weekdayPrice': weekday,
          'weekendPrice': weekend,
          'price': math.min(weekday, weekend)
        });
      }
    }
    return ordered;
  }

  int? get startingPrice {
    final list = enabledShifts;
    if (list.isEmpty) return null;
    return list.map((s) => s['price'] as int).reduce(math.min);
  }

  int get deposit => data['deposit'] as int;

  List<int> get weekendDays => List<int>.from(data['weekendDays'] as List);

  String get weekendDaysText {
    final days = weekendDays;
    if (days.isEmpty) return 'بدون عطلة نهاية أسبوع مخصصة';
    return days.map((d) => dayLabels[d] ?? '$d').join('، ');
  }

  bool isWeekendBaghdad(DateTime utcInstant) {
    final local = utcInstant.toUtc().add(const Duration(hours: 3));
    return weekendDays.contains(local.weekday % 7);
  }

  Map<String, dynamic> quote(String kind, DateTime start, DateTime end) {
    validate();
    final s = (data['shifts'] as List)
        .cast<Map<String, dynamic>>()
        .where((s) => s['kind'] == kind && s['enabled'] == true)
        .firstOrNull;
    if (s == null) throw const FormatException('الفترة غير مفعلة');
    final local = start.toUtc().add(const Duration(hours: 3));
    if (local.hour * 60 + local.minute != s['startMinute'] ||
        local.second != 0 ||
        local.millisecond != 0 ||
        local.microsecond != 0 ||
        end.difference(start).inMilliseconds !=
            (s['endMinute'] + s['endDayOffset'] * 1440 - s['startMinute']) *
                60000) throw const FormatException('وقت الطلب لا يطابق الفترة');
    final weekend = (data['weekendDays'] as List).contains(local.weekday % 7),
        total = s[weekend ? 'weekendPrice' : 'weekdayPrice'] as int;
    return {
      'total': total,
      'deposit': data['deposit'],
      'remaining': total - (data['deposit'] as int),
      'pricing': {
        'version': 2,
        'kind': kind,
        'startMinute': s['startMinute'],
        'endMinute': s['endMinute'],
        'endDayOffset': s['endDayOffset'],
        'dayGroup': weekend ? 'weekend' : 'weekday',
        'timeZone': 'Asia/Baghdad',
        'currency': 'IQD'
      }
    };
  }
}
