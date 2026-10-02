"""Chat rules regression checks. Runs only against the demo-aqar emulator."""
import unittest
import firestore_reports_rules_test as base


def value(v):
    if v is None: return {'nullValue': None}
    if isinstance(v, bool): return {'booleanValue': v}
    if isinstance(v, int): return {'integerValue': str(v)}
    if isinstance(v, float): return {'doubleValue': v}
    if isinstance(v, list): return {'arrayValue': {'values': [value(x) for x in v]}}
    if isinstance(v, dict): return {'mapValue': {'fields': {k: value(x) for k, x in v.items()}}}
    return {'stringValue': v}


def write(path, data, uid='chat-owner', update=False, times=()):
    operation = {'update': {'name': base.NAME + path, 'fields': {k: value(v) for k, v in data.items()}}}
    if update: operation['updateMask'] = {'fieldPaths': list(data)}
    if times: operation['updateTransforms'] = [{'fieldPath': key, 'setToServerValue': 'REQUEST_TIME'} for key in times]
    return base.call(':commit', uid, {'writes': [operation]})


def message(**changes):
    return {'senderId': 'chat-owner', 'senderType': 'user', 'authorUid': 'chat-owner', 'message': 'Hello',
            'imageUrl': '', 'type': 'text', 'status': 'sent', 'isRead': False, 'replyToId': '',
            'audioUrl': '', 'audioPath': '', 'audioSeconds': 0, 'latitude': None, 'longitude': None,
            'deliveredAt': None, 'readAt': None, **changes}


class ChatRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for uid in ['chat-owner', 'chat-other', 'chat-blocked', 'chat-admin']:
            assert write(f'users/{uid}', {'isAdmin': uid == 'chat-admin', 'isBlocked': uid == 'chat-blocked'}, 'SEED') == 200
        assert write('settings/app_settings', {'allowChat': True, 'chatPreferences': {'voiceEnabled': True, 'voiceSeconds': 120}}, 'SEED') == 200
        for uid in ['chat-owner', 'chat-blocked']:
            assert write(f'chats/{uid}', {'userId': uid, 'isClosed': False, 'isBlocked': False, 'unreadUser': 0, 'unreadAdmin': 0, 'lastMessage': '', 'lastSender': ''}, 'SEED') == 200
        assert write('properties/chat-property', {'status': 'approved'}, 'SEED') == 200

    def test_atomic_message_and_list_preview_matches_client_send(self):
        data = message(imagePath='')
        preview = {'lastMessage': 'Hello', 'lastMessageId': 'atomic', 'lastSender': 'user', 'unreadAdmin': 1, 'unreadUser': 0}
        operations = [
            {'update': {'name': base.NAME + 'chats/chat-owner/messages/atomic', 'fields': {k: value(v) for k, v in data.items()}},
             'updateTransforms': [{'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}]},
            {'update': {'name': base.NAME + 'chats/chat-owner', 'fields': {k: value(v) for k, v in preview.items()}},
             'updateMask': {'fieldPaths': list(preview)},
             'updateTransforms': [{'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'}]},
        ]
        self.assertEqual(base.call(':commit', 'chat-owner', {'writes': operations}), 200)
        self.assertEqual(write('chats/chat-owner', {'unreadAdmin': 1000}, update=True), 403)

    def test_authorship_and_server_time_cannot_be_forged(self):
        path = 'chats/chat-owner/messages/valid'
        self.assertEqual(write(path, message(), times=['createdAt']), 200)
        for i, data in enumerate([message(senderId='chat-admin'), message(senderType='admin'), message(authorUid='chat-admin'), message(deletedAt='fake'), message(message='x' * 5001)]):
            self.assertEqual(write(f'chats/chat-owner/messages/forged-{i}', data, times=['createdAt']), 403)
        self.assertEqual(write('chats/chat-owner/messages/no-time', message()), 403)
        self.assertEqual(write('chats/chat-owner/messages/foreign', message(), 'chat-other', times=['createdAt']), 403)
        self.assertEqual(write('chats/chat-blocked/messages/blocked', message(senderId='chat-blocked', authorUid='chat-blocked'), 'chat-blocked', times=['createdAt']), 403)

    def test_original_content_and_deletion_metadata_are_immutable(self):
        path = 'chats/chat-owner/messages/immutable'
        self.assertEqual(write(path, message(), times=['createdAt']), 200)
        for change in [{'message': 'edited'}, {'createdAt': 'fake'}, {'senderId': 'admin'}, {'deletedAt': 'fake', 'message': ''}, {'authorUid': 'other'}]:
            self.assertEqual(write(path, change, update=True), 403)
        self.assertEqual(write(path, {'message': 'edited'}, 'chat-admin', True), 403)
        self.assertEqual(base.call(':commit', 'chat-admin', {'writes': [{'delete': base.NAME + path}]}), 403)

    def test_timed_tombstone_rejects_forgery_foreign_and_expired(self):
        import datetime, json, urllib.request
        path = 'chats/chat-owner/messages/tombstone'
        self.assertEqual(write(path, message(), times=['createdAt']), 200)
        req = urllib.request.Request(base.BASE + '/' + path, headers={'Authorization': 'Bearer owner'})
        fields = json.load(urllib.request.urlopen(req))['fields']
        keep = {k: v for k, v in fields.items() if k in ['senderId', 'senderType', 'authorUid', 'createdAt', 'isRead', 'status', 'readAt', 'deliveredAt']}
        def erase(uid='chat-owner', extra=None, server=True, target=path):
            data = {**keep, 'type': value('deleted'), 'message': value(''), 'deletedBy': value(uid), **(extra or {})}
            op = {'update': {'name': base.NAME + target, 'fields': data}}
            if server: op['updateTransforms'] = [{'fieldPath': 'deletedAt', 'setToServerValue': 'REQUEST_TIME'}]
            return base.call(':commit', uid, {'writes': [op]})
        self.assertEqual(erase('chat-other'), 403)
        self.assertEqual(erase(extra={'deletedBy': value('chat-admin')}), 403)
        self.assertEqual(erase(extra={'imageUrl': value('retained')}), 403)
        self.assertEqual(erase(extra={'deletedAt': value('fake')}, server=False), 403)
        self.assertEqual(erase(), 200)
        self.assertEqual(write(path, {'message': 'resurrected'}, update=True), 403)
        old = 'chats/chat-owner/messages/expired-delete'
        keep['createdAt'] = {'timestampValue': (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=8)).isoformat()}
        seed = {**keep, 'type': value('text'), 'message': value('old')}
        self.assertEqual(base.call(':commit', 'SEED', {'writes': [{'update': {'name': base.NAME + old, 'fields': seed}}]}), 200)
        self.assertEqual(erase(target=old), 403)
        self.assertEqual(erase('chat-admin', target=old), 200)

    def test_atomic_delete_clears_latest_preview_even_when_chat_closed(self):
        import json, urllib.request
        path = 'chats/chat-owner/messages/delete-latest'
        self.assertEqual(write(path, message(), times=['createdAt']), 200)
        self.assertEqual(write('chats/chat-owner', {'lastMessageId': 'delete-latest', 'lastMessage': 'Hello', 'lastSender': 'user', 'isClosed': True}, 'SEED', True), 200)
        try:
            req = urllib.request.Request(base.BASE + '/' + path, headers={'Authorization': 'Bearer owner'})
            original = json.load(urllib.request.urlopen(req))['fields']
            fields = {k: v for k, v in original.items() if k in ['senderId', 'senderType', 'authorUid', 'createdAt', 'isRead', 'status', 'readAt', 'deliveredAt']}
            fields.update({'type': value('deleted'), 'message': value(''), 'deletedBy': value('chat-owner')})
            operations = [
                {'update': {'name': base.NAME + path, 'fields': fields}, 'updateTransforms': [{'fieldPath': 'deletedAt', 'setToServerValue': 'REQUEST_TIME'}]},
                {'update': {'name': base.NAME + 'chats/chat-owner', 'fields': {'lastMessage': value('تم حذف هذه الرسالة')}},
                 'updateMask': {'fieldPaths': ['lastMessage']}, 'updateTransforms': [{'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'}]},
            ]
            self.assertEqual(base.call(':commit', 'chat-owner', {'writes': operations}), 200)
            self.assertEqual(write('chats/chat-owner', {'lastMessage': 'تم حذف هذه الرسالة'}, update=True, times=['updatedAt']), 403)
        finally:
            write('chats/chat-owner', {'isClosed': False}, 'SEED', True)

    def test_cloudinary_audio_accepted_and_untrusted_audio_rejected(self):
        data = message(type='audio', audioPath='', audioSeconds=2, audioUrl='https://res.cloudinary.com/hwxcrlcj/video/upload/v1/example.m4a')
        self.assertEqual(write('chats/chat-owner/messages/cloud-audio', data, times=['createdAt']), 200)
        self.assertEqual(write('chats/chat-owner/messages/cloud-invalid', {**data, 'audioUrl': 'https://foreign.example/audio'}, times=['createdAt']), 403)

    def test_recipient_can_read_but_sender_cannot_forge_receipts(self):
        path = 'chats/chat-owner/messages/admin-receipt'
        self.assertEqual(write(path, message(senderId='admin', senderType='admin', authorUid='chat-admin'), 'chat-admin', times=['createdAt']), 200)
        self.assertEqual(write(path, {'status': 'read', 'isRead': True}, update=True, times=['readAt', 'deliveredAt']), 200)
        path = 'chats/chat-owner/messages/user-receipt'
        self.assertEqual(write(path, message(), times=['createdAt']), 200)
        self.assertEqual(write(path, {'status': 'read', 'isRead': True}, update=True, times=['readAt', 'deliveredAt']), 403)
        self.assertEqual(write(path, {'status': 'read', 'isRead': True}, 'chat-admin', True, ['readAt', 'deliveredAt']), 200)

    def test_typing_and_moderation_roles(self):
        self.assertEqual(write('chats/chat-owner', {}, update=True, times=['userTypingAt']), 200)
        self.assertEqual(write('chats/chat-owner', {'userTypingAt': None}, update=True), 200)
        self.assertEqual(write('chats/chat-owner', {'userTypingAt': 'fake'}, update=True), 403)
        self.assertEqual(write('chats/chat-owner', {}, update=True, times=['adminTypingAt']), 403)
        for change in [{'isBlocked': True}, {'isClosed': True}]:
            self.assertEqual(write('chats/chat-owner', change, update=True), 403)
        self.assertEqual(write('settings/app_settings', {'chatPreferences': {'deleteHours': 168}}, update=True), 403)
        self.assertEqual(write('chats/chat-owner/deletionAudit/fake', {'deletedBy': 'chat-owner'}), 403)

    def test_away_and_human_notification_query_is_scoped_to_recipient(self):
        self.assertEqual(write('notifications/chat-system', {'userId': 'chat-owner', 'chatId': 'chat-owner', 'type': 'chat_message', 'readBy': []}, 'SEED'), 200)
        query = {'structuredQuery': {'from': [{'collectionId': 'notifications'}], 'where': {'compositeFilter': {'op': 'AND', 'filters': [
            {'fieldFilter': {'field': {'fieldPath': key}, 'op': 'EQUAL', 'value': value(v)}}
            for key, v in [('userId', 'chat-owner'), ('chatId', 'chat-owner'), ('type', 'chat_message')]
        ]}}}}
        self.assertEqual(base.call(':runQuery', 'chat-owner', query), 200)
        self.assertEqual(base.call(':runQuery', 'chat-other', query), 403)
        self.assertEqual(write('notifications/chat-system', {'readBy': ['chat-owner'], 'unreadCount': 0}, update=True, times=['updatedAt']), 200)

    def test_audio_bounds_reply_scope_and_property_payload(self):
        self.assertEqual(write('chats/chat-owner/messages/location', message(type='location', latitude=33.4, longitude=43.3), times=['createdAt']), 200)
        self.assertEqual(write('chats/chat-owner/messages/bad-location', message(type='location', latitude=900, longitude=43.3), times=['createdAt']), 403)
        audio = message(type='audio', audioUrl='https://example.com/audio', audioPath='chat_audio/chat-owner/chat-owner/123.m4a', audioSeconds=120)
        self.assertEqual(write('chats/chat-owner/messages/audio', audio, times=['createdAt']), 200)
        self.assertEqual(write('chats/chat-owner/messages/too-long', {**audio, 'audioSeconds': 121}, times=['createdAt']), 403)
        self.assertEqual(write('chats/chat-owner/messages/foreign-audio', {**audio, 'audioPath': 'chat_audio/chat-other/chat-owner/123.m4a'}, times=['createdAt']), 403)
        self.assertEqual(write('chats/chat-owner/messages/reply', message(replyToId='audio'), times=['createdAt']), 200)
        self.assertEqual(write('chats/chat-owner/messages/no-reply', message(replyToId='missing'), times=['createdAt']), 403)
        card = {'id': 'chat-property', 'title': 'House', 'location': 'Ramadi', 'price': 100, 'number': 1, 'imageUrl': '', 'adType': 'sale'}
        self.assertEqual(write('chats/chat-owner/messages/property', message(type='property', property=card), times=['createdAt']), 200)
        self.assertEqual(write('chats/chat-owner/messages/private-property', message(type='property', property={**card, 'ownerPhone': 'private'}), times=['createdAt']), 403)


if __name__ == '__main__': unittest.main(verbosity=2)
