"""Run only against the local Firestore emulator, never production.

firebase emulators:exec --only firestore --project demo-aqar --config firebase.reports-test.json "python test/firestore_reports_rules_test.py"
"""
import base64
import json
import os
import time
import unittest
import urllib.error
import urllib.request

HOST = os.environ.get('FIRESTORE_EMULATOR_HOST', '')
if HOST not in ('127.0.0.1:8185', 'localhost:8185'):
    raise RuntimeError('This test requires the isolated local Firestore emulator on port 8185')
BASE = f'http://{HOST}/v1/projects/demo-aqar/databases/(default)/documents'
NAME = 'projects/demo-aqar/databases/(default)/documents/'


def token(uid):
    def enc(obj):
        return base64.urlsafe_b64encode(json.dumps(obj).encode()).decode().rstrip('=')
    return enc({'alg': 'none', 'typ': 'JWT'}) + '.' + enc({
        'sub': uid, 'user_id': uid, 'aud': 'demo-aqar',
        'iss': 'https://securetoken.google.com/demo-aqar',
        'iat': int(time.time()), 'exp': int(time.time()) + 3600,
        'firebase': {'sign_in_provider': 'password'},
    }) + '.'


def value(v):
    if isinstance(v, bool): return {'booleanValue': v}
    if isinstance(v, int): return {'integerValue': str(v)}
    return {'stringValue': v}


def call(path, uid=None, body=None):
    headers = {'Content-Type': 'application/json'}
    if uid: headers['Authorization'] = 'Bearer ' + ('owner' if uid == 'SEED' else token(uid))
    req = urllib.request.Request(BASE + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
    try:
        with urllib.request.urlopen(req) as response: return response.status
    except urllib.error.HTTPError as error:
        return error.code


def write(path, data, uid='reporter', update=False, timestamp='createdAt'):
    w = {'update': {'name': NAME + path, 'fields': {k: value(v) for k,v in data.items()}}}
    if timestamp: w['updateTransforms'] = [{'fieldPath': timestamp, 'setToServerValue': 'REQUEST_TIME'}]
    if update: w['updateMask'] = {'fieldPaths': list(data)}
    return call(':commit', uid, {'writes': [w]})


def report(office=False, **extra):
    data = {'officeId' if office else 'propertyId': 'target', 'userId': 'reporter', 'status': 'pending',
            'targetTitle': 'Example', 'reason': 'محتوى غير مناسب', 'details': ''}
    if office: data['officeOwnerId'] = 'publisher'
    return {**data, **extra}


class ReportRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for path, data in [('users/admin', {'isAdmin': True}), ('users/reporter', {'isAdmin': False}),
                           ('properties/target', {'userId': 'publisher'}), ('offices/target', {'ownerId': 'publisher'})]:
            assert write(path, data, 'SEED', timestamp=None) == 200

    def test_valid_property_and_office(self):
        self.assertEqual(write('property_reports/valid', report()), 200)
        self.assertEqual(write('office_reports/valid', report(True)), 200)

    def test_legacy_office(self):
        old = {'officeId': 'target', 'officeOwnerId': 'publisher', 'userId': 'reporter', 'status': 'pending'}
        self.assertEqual(write('office_reports/legacy', old), 200)
        self.assertEqual(write('office_reports/legacy', {'status': 'resolved', 'reviewedBy': 'admin', 'adminNotes': 'Reviewed'}, 'admin', True, 'updatedAt'), 200)

    def test_private_reports(self):
        self.assertEqual(write('property_reports/private', report()), 200)
        for uid in (None, 'reporter', 'other'):
            self.assertEqual(call('/property_reports/private', uid), 403)
            self.assertEqual(call('/property_reports', uid), 403)
        self.assertEqual(call('/property_reports/private', 'admin'), 200)
        self.assertEqual(call('/property_reports', 'admin'), 200)

    def test_create_abuse(self):
        for i, data in enumerate([report(userId='other'), report(status='resolved'), report(adminNotes='fake'),
                                  report(details='x'*1501), report(reason='invalid'), report(extra='pollution'),
                                  report(propertyId='missing'), report(reason='سبب آخر'), report(targetTitle=42)]):
            with self.subTest(i=i): self.assertEqual(write(f'property_reports/bad{i}', data), 403)
        self.assertEqual(write('property_reports/anonymous', report(), uid=None), 403)
        self.assertEqual(write('office_reports/spoof', report(True, officeOwnerId='other')), 403)
        self.assertEqual(write('property_reports/no-time', report(), timestamp=None), 403)

    def test_review_integrity(self):
        self.assertEqual(write('property_reports/review', report()), 200)
        review = {'status': 'in_review', 'adminNotes': 'Checking', 'reviewedBy': 'admin'}
        self.assertEqual(write('property_reports/review', review, 'reporter', True, 'updatedAt'), 403)
        self.assertEqual(write('property_reports/review', review, 'admin', True, 'updatedAt'), 200)
        for extra in ({'userId': 'admin'}, {'propertyId': 'other'}, {'details':'edited'}, {'adminNotes': 'x'*1501}, {'status':'invalid'}, {'reviewedBy':'other'}):
            with self.subTest(extra=list(extra)):
                self.assertEqual(write('property_reports/review', {**review, **extra}, 'admin', True, 'updatedAt'), 403)

    def test_cannot_self_promote(self):
        self.assertEqual(write('users/reporter', {'isAdmin': True}, 'reporter', True, None), 403)
        self.assertEqual(write('users/attacker', {'isAdmin': True, 'isBlocked': False, 'accountType':'user', 'accountMode':'user'}, 'attacker', timestamp=None), 403)


if __name__ == '__main__': unittest.main(verbosity=2)
