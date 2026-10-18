class ChatPreferences {
  final bool voiceEnabled;
  final int voiceSeconds;
  final int deleteHours;
  final bool hoursEnabled;
  final int openingMinute;
  final int closingMinute;
  final List<int> workDays;
  final String awayMessage;
  final List<String> quickReplies;

  const ChatPreferences({
    this.voiceEnabled = true,
    this.voiceSeconds = 120,
    this.deleteHours = 24,
    this.hoursEnabled = false,
    this.openingMinute = 540,
    this.closingMinute = 1080,
    this.workDays = const [1, 2, 3, 4, 6, 7],
    this.awayMessage =
        'شكراً لتواصلك مع عقارات الأنبار. نحن خارج وقت العمل وسنرد على رسالتك عند العودة.',
    this.quickReplies = const [
      'ما المنطقة التي تبحث فيها؟',
      'ما ميزانيتك التقريبية؟',
      'هل تبحث عن شراء أم إيجار؟'
    ],
  });

  factory ChatPreferences.fromMap(Map<String, dynamic>? data) {
    final d = data ?? {};
    const defaults = ChatPreferences();
    int bounded(String key, int fallback, int min, int max) =>
        ((d[key] as num?)?.toInt() ?? fallback).clamp(min, max);
    return ChatPreferences(
      voiceEnabled: d['voiceEnabled'] != false,
      voiceSeconds: bounded('voiceSeconds', 120, 15, 300),
      deleteHours: bounded('deleteHours', 24, 1, 168),
      hoursEnabled: d['hoursEnabled'] == true,
      openingMinute: bounded('openingMinute', 540, 0, 1439),
      closingMinute: bounded('closingMinute', 1080, 0, 1439),
      workDays: d['workDays'] is List
          ? (d['workDays'] as List)
              .whereType<int>()
              .where((v) => v >= 1 && v <= 7)
              .toList()
          : defaults.workDays,
      awayMessage: (d['awayMessage'] as String?) ?? defaults.awayMessage,
      quickReplies: d['quickReplies'] is List
          ? (d['quickReplies'] as List)
              .whereType<String>()
              .where((v) => v.trim().isNotEmpty)
              .take(30)
              .toList()
          : defaults.quickReplies,
    );
  }

  bool isOpen(DateTime instant) {
    if (!hoursEnabled) return true;
    final baghdad = instant.toUtc().add(const Duration(hours: 3));
    final minute = baghdad.hour * 60 + baghdad.minute;
    if (openingMinute < closingMinute) {
      return workDays.contains(baghdad.weekday) &&
          minute >= openingMinute &&
          minute < closingMinute;
    }
    final previousDay = baghdad.weekday == 1 ? 7 : baghdad.weekday - 1;
    return (workDays.contains(baghdad.weekday) && minute >= openingMinute) ||
        (workDays.contains(previousDay) && minute < closingMinute);
  }

  static String clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'voiceEnabled': voiceEnabled,
        'voiceSeconds': voiceSeconds,
        'deleteHours': deleteHours,
        'hoursEnabled': hoursEnabled,
        'openingMinute': openingMinute,
        'closingMinute': closingMinute,
        'workDays': workDays,
        'awayMessage': awayMessage,
        'quickReplies': quickReplies,
      };
}
