import 'package:aqar/chat/models/chat_preferences.dart';
import 'package:aqar/chat/widgets/chat_message_tile.dart';
import 'package:aqar/chat/utils/chat_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic search ignores diacritics and localized number formatting', () {
    expect(normalizeChatSearch('الأنبَار ١٥٠,٠٠٠'), 'الانبار 150000');
  });
  test('Baghdad business hours agree at opening, closing and overnight', () {
    const p = ChatPreferences(
        hoursEnabled: true,
        workDays: [5],
        openingMinute: 540,
        closingMinute: 1080);
    expect(p.isOpen(DateTime.parse('2026-10-02T06:00:00Z')), isTrue);
    expect(p.isOpen(DateTime.parse('2026-10-02T05:59:59Z')), isFalse);
    expect(p.isOpen(DateTime.parse('2026-10-02T15:00:00Z')), isFalse);
    expect(p.isOpen(DateTime.parse('2026-10-03T09:00:00Z')), isFalse);
    const overnight = ChatPreferences(
        hoursEnabled: true,
        workDays: [5],
        openingMinute: 1320,
        closingMinute: 120);
    expect(overnight.isOpen(DateTime.parse('2026-10-02T22:00:00Z')), isTrue);
    expect(overnight.isOpen(DateTime.parse('2026-10-02T23:00:00Z')), isFalse);
  });
  test('Settings round-trip and bound voice length and delete window', () {
    final p = ChatPreferences.fromMap({'voiceSeconds': 900, 'deleteHours': -5});
    expect(p.voiceSeconds, 300);
    expect(p.deleteHours, 1);
    expect(ChatPreferences.fromMap(p.toMap()).toMap(), p.toMap());
  });
  test('Deleted message summaries never expose original text or property', () {
    expect(
        ChatMessageTile.summary({
          'deletedAt': 'now',
          'message': 'private',
          'type': 'property',
          'property': {'title': 'private'}
        }),
        'تم حذف هذه الرسالة');
  });
}
