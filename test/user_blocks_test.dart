import 'package:aqar/moderation/user_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a blocked author disappears under every supported ownership field', () {
    for (final key in ['userId', 'publisherUid', 'ownerId', 'authorId']) {
      expect(isBlockedContent({key: 'abuser'}, {'abuser'}, {}), isTrue);
      expect(isBlockedContent({key: 'someone-else'}, {'abuser'}, {}), isFalse);
    }
  });
  test('office-linked content and nested reel snapshots respect blocks', () {
    expect(isBlockedContent({'officeId': 'office'}, {}, {'office'}), isTrue);
    expect(
        isBlockedContent({
          'propertySnapshot': {'publisherUid': 'abuser'}
        }, {
          'abuser'
        }, {}),
        isTrue);
    expect(
        isBlockedContent({
          'officeSnapshot': {'ownerId': 'abuser'}
        }, {
          'abuser'
        }, {}),
        isTrue);
  });
  test(
      'unblocking restores content while moderation-hidden content stays hidden',
      () {
    expect(isBlockedContent({'userId': 'abuser'}, {}, {}), isFalse);
    expect(isBlockedContent({'isHidden': true}, {}, {}), isTrue);
  });
}
