import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local history visibility, scoped to both account and conversation.
class ChatHistoryPreferences {
  Future<Map<String, String>> loadDraft(String userId, String chatId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('${storageKey(userId, chatId)}_draft');
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveDraft(
      String userId, String chatId, String text, String replyId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '${storageKey(userId, chatId)}_draft';
    if (text.isEmpty && replyId.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(
          key, jsonEncode({'text': text, 'replyId': replyId}));
    }
  }

  static String storageKey(String userId, String chatId) =>
      'chat_hidden_${jsonEncode([userId, chatId])}';

  Future<Set<String>> load(String userId, String chatId) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(storageKey(userId, chatId)) ?? [])
        .toSet();
  }

  Future<void> save(String userId, String chatId, Set<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setStringList(
      storageKey(userId, chatId),
      ids.toList(),
    );
    if (!saved) throw StateError('Unable to save chat history preferences');
  }
}
