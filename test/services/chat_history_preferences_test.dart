import 'package:aqar/chat/services/chat_history_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Draft persists text and reply, and clears only its own conversation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = ChatHistoryPreferences();
    await preferences.saveDraft('one', 'chat', 'رسالة غير مرسلة', 'reply-1');
    expect(await preferences.loadDraft('one', 'chat'),
        {'text': 'رسالة غير مرسلة', 'replyId': 'reply-1'});
    expect(await preferences.loadDraft('two', 'chat'), isEmpty);
    await preferences.saveDraft('one', 'chat', '', '');
    expect(await preferences.loadDraft('one', 'chat'), isEmpty);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Deleted messages remain hidden after reopening the conversation',
      () async {
    await ChatHistoryPreferences()
        .save('user', 'chat', {'message-1', 'message-2'});
    final hidden = await ChatHistoryPreferences().load('user', 'chat');
    expect(hidden, {'message-1', 'message-2'});
    expect(hidden.contains('new-message'), isFalse);
  });

  test('Deletion is isolated by account and conversation', () async {
    final preferences = ChatHistoryPreferences();
    await preferences.save('user-1', 'chat-1', {'message'});
    expect(await preferences.load('user-2', 'chat-1'), isEmpty);
    expect(await preferences.load('user-1', 'chat-2'), isEmpty);
  });

  test('Account and chat identifiers cannot collide', () {
    expect(ChatHistoryPreferences.storageKey('a_b', 'c'),
        isNot(ChatHistoryPreferences.storageKey('a', 'b_c')));
  });
}
