"""Private chat attachment access checks; isolated demo emulators only."""
import os
import unittest
import urllib.request
import urllib.error
import urllib.parse
import firestore_chat_rules_test as chat_rules
write = chat_rules.write
from firestore_reports_rules_test import token

HOST = os.environ.get('FIREBASE_STORAGE_EMULATOR_HOST', '')
if HOST not in ('127.0.0.1:9198', 'localhost:9198'):
    raise RuntimeError('Isolated storage emulator on port 9198 required')
BASE = f'http://{HOST}/v0/b/demo-aqar.appspot.com/o'


def upload(path, uid='chat-owner', content_type='audio/mp4', size=100):
    request = urllib.request.Request(BASE + '?name=' + urllib.parse.quote(path, safe=''), data=b'0' * size, method='POST', headers={
        'Authorization': 'Bearer ' + token(uid), 'Content-Type': content_type, 'X-Goog-Upload-Protocol': 'raw',
    })
    try:
        with urllib.request.urlopen(request) as response: return response.status
    except urllib.error.HTTPError as error: return error.code


def download(path, uid=None):
    headers = {} if uid is None else {'Authorization': 'Bearer ' + token(uid)}
    request = urllib.request.Request(BASE + '/' + urllib.parse.quote(path, safe='') + '?alt=media', headers=headers)
    try:
        with urllib.request.urlopen(request) as response: return response.status
    except urllib.error.HTTPError as error: return error.code


class StorageChatRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls): chat_rules.ChatRules.setUpClass()

    def test_owner_and_admin_can_upload_and_read_but_strangers_cannot(self):
        path = 'chat_audio/chat-owner/chat-owner/123.m4a'
        self.assertEqual(upload(path), 200)
        self.assertEqual(download(path, 'chat-owner'), 200)
        self.assertEqual(download(path, 'chat-admin'), 200)
        self.assertEqual(download(path, 'chat-other'), 403)
        self.assertEqual(download(path), 403)
        self.assertEqual(upload('chat_audio/chat-owner/chat-admin/124.m4a', 'chat-admin'), 200)
        self.assertEqual(upload('chat_audio/chat-owner/chat-other/125.m4a', 'chat-other'), 403)
        self.assertEqual(upload('chat_audio/chat-owner/chat-admin/126.m4a'), 403)

    def test_file_type_size_and_closed_chat_are_enforced(self):
        self.assertEqual(upload('chat_audio/chat-owner/chat-owner/200.m4a', content_type='application/octet-stream'), 403)
        self.assertEqual(upload('chat_audio/chat-owner/chat-owner/201.m4a', size=6 * 1024 * 1024), 403)
        self.assertEqual(upload('chat_images/chat-owner/chat-owner/202.jpg', content_type='image/jpeg'), 200)
        self.assertEqual(upload('chat_images/chat-owner/chat-owner/203.exe', content_type='image/jpeg'), 403)
        self.assertEqual(write('chats/chat-owner', {'isClosed': True}, 'SEED', True), 200)
        self.assertEqual(upload('chat_audio/chat-owner/chat-owner/204.m4a'), 403)
        self.assertEqual(write('chats/chat-owner', {'isClosed': False}, 'SEED', True), 200)


if __name__ == '__main__': unittest.main(verbosity=2)
