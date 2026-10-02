"""Analytics security regression tests; isolated demo-aqar emulator ONLY."""
from firestore_reports_rules_test import *


def activity(**extra):
    return {'userId': 'reporter', 'isGuest': False, 'platform': 'ios',
            'displayName': 'Registered user', 'lastSessionId': 'session', **extra}


class ActivityRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert write('users/admin', {'isAdmin': True}, 'SEED', timestamp=None) == 200
        assert write('users/reporter', {'isAdmin': False}, 'SEED', timestamp=None) == 200

    def test_own_activity_and_server_timestamp_only(self):
        self.assertEqual(write('user_activity/reporter', activity(), timestamp='lastSeen'), 200)
        self.assertEqual(write('user_activity/reporter', activity(platform='android'),
                               update=True, timestamp='lastSeen'), 200)
        self.assertEqual(write('user_activity/reporter', activity(userId='other'),
                               update=True, timestamp='lastSeen'), 403)
        self.assertEqual(write('user_activity/reporter', activity(isGuest=True),
                               update=True, timestamp='lastSeen'), 403)
        self.assertEqual(write('user_activity/reporter', {'platform': 'ios'},
                               update=True, timestamp=None), 403)

    def test_foreign_guest_and_unknown_fields_are_rejected(self):
        self.assertEqual(write('user_activity/other', activity(), timestamp='lastSeen'), 403)
        self.assertEqual(write('user_activity/new', activity(), uid=None, timestamp='lastSeen'), 403)
        self.assertEqual(write('user_activity/reporter', {'photoUrl': 'injected'},
                               update=True, timestamp='lastSeen'), 403)
        self.assertEqual(call('/user_activity/reporter', 'other'), 403)
        self.assertEqual(call('/user_activity', 'reporter'), 403)
        self.assertEqual(call('/user_activity', 'admin'), 200)

    def test_session_identity_end_time_and_duration(self):
        path = 'app_sessions/activity-session'
        fields = {k: value(v) for k, v in {
            'visitorId': 'reporter', 'userId': 'reporter', 'isGuest': False,
            'platform': 'ios', 'durationSeconds': 0,
        }.items()}
        fields['endedAt'] = {'nullValue': None}
        payload = {'writes': [{'update': {'name': NAME + path, 'fields': fields},
                              'updateTransforms': [{'fieldPath': 'startedAt', 'setToServerValue': 'REQUEST_TIME'}]}]}
        self.assertEqual(call(':commit', 'reporter', payload), 200)
        self.assertEqual(write(path, {'durationSeconds': -1}, update=True, timestamp='endedAt'), 403)
        self.assertEqual(write(path, {'durationSeconds': 30}, uid='other', update=True, timestamp='endedAt'), 403)
        self.assertEqual(write(path, {'durationSeconds': 30}, update=True, timestamp=None), 403)
        self.assertEqual(write(path, {'durationSeconds': 30}, update=True, timestamp='endedAt'), 200)
        self.assertEqual(write(path, {'durationSeconds': 40}, update=True, timestamp='endedAt'), 403)

    def test_provider_platform_matrix(self):
        for platform in ['android', 'ios']:
            for provider in ['phone', 'password', 'google.com', 'apple.com', 'facebook.com', 'anonymous']:
                uid = f"{platform}-{provider.replace('.', '-')}"
                encoded = token(uid).split('.')
                claims = json.loads(base64.urlsafe_b64decode(encoded[1] + '=='))
                claims['firebase']['sign_in_provider'] = provider
                encoded[1] = base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip('=')
                fields = {k: value(v) for k, v in activity(userId=uid, platform=platform).items()}
                body = {'writes': [{'update': {'name': NAME + 'user_activity/' + uid, 'fields': fields},
                                   'updateTransforms': [{'fieldPath': 'lastSeen', 'setToServerValue': 'REQUEST_TIME'}]}]}
                req = urllib.request.Request(BASE + ':commit', data=json.dumps(body).encode(),
                    headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + '.'.join(encoded)})
                try:
                    with urllib.request.urlopen(req) as response:
                        status = response.status
                except urllib.error.HTTPError as error:
                    status = error.code
                with self.subTest(platform=platform, provider=provider):
                    self.assertEqual(status, 403 if provider == 'anonymous' else 200)


if __name__ == '__main__':
    unittest.main(verbosity=2)
