"""Safety regression tests; uses only demo-aqar's local emulator."""
from firestore_reports_rules_test import *


def block_writes(uid='reporter', target='publisher', report_id='block', include_report=True):
    data = {'userId': uid, 'targetUid': target, 'targetPath': 'properties/target',
            'reason': 'حظر مستخدم مسيء', 'details': '', 'status': 'pending'}
    records = [(f'users/{uid}/blockedUsers/{target}', {'targetUid': target, 'officeId': '', 'reportId': report_id})]
    if include_report: records.append((f'user_reports/{report_id}', data))
    return [{'update': {'name': NAME + path, 'fields': {k: value(v) for k, v in fields.items()}},
             'updateTransforms': [{'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}]} for path, fields in records]


class SafetyRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for uid in ['reporter', 'publisher', 'other', 'blocked', 'admin']:
            assert write(f'users/{uid}', {'isAdmin': uid == 'admin', 'isBlocked': uid == 'blocked'}, 'SEED', timestamp=None) == 200
        assert write('properties/target', {'userId': 'publisher', 'publisherUid': 'publisher', 'status': 'approved'}, 'SEED', timestamp=None) == 200

    def test_atomic_block_and_private_report(self):
        self.assertEqual(call(':commit', 'reporter', {'writes': block_writes(report_id='valid-block')}), 200)
        self.assertEqual(call('/users/reporter/blockedUsers/publisher', 'reporter'), 200)
        self.assertEqual(call('/users/reporter/blockedUsers/publisher', 'other'), 403)
        self.assertEqual(call('/user_reports/valid-block', 'reporter'), 403)
        self.assertEqual(call('/user_reports/valid-block', 'admin'), 200)

    def test_block_requires_matching_report(self):
        self.assertEqual(call(':commit', 'reporter', {'writes': block_writes(report_id='absent', include_report=False)}), 403)
        self.assertEqual(call(':commit', 'other', {'writes': block_writes(report_id='foreign')}), 403)
        self.assertEqual(call(':commit', 'reporter', {'writes': block_writes(target='reporter', report_id='self')}), 403)
        self.assertEqual(call(':commit', 'reporter', {'writes': block_writes(target='other', report_id='forged')}), 403)

    def test_consent_cannot_be_forged(self):
        path = 'users/reporter/consents/2026-09-27'
        data = {'version': '2026-09-27', 'accepted': True}
        self.assertEqual(write(path, data, timestamp='acceptedAt'), 200)
        self.assertEqual(write(path, data, 'other', timestamp='acceptedAt'), 403)
        self.assertEqual(write(path, {**data, 'accepted': False}, timestamp='acceptedAt'), 403)

    def test_admin_can_ban_but_user_cannot_unban(self):
        self.assertEqual(write('users/other', {'isBlocked': True}, 'admin', True, None), 200)
        self.assertEqual(write('users/other', {'isBlocked': False}, 'other', True, None), 403)
        self.assertEqual(write('users/reporter', {'isBlocked': True}, 'publisher', True, None), 403)

    def test_comments_publish_immediately_but_cannot_evade_admin_hiding(self):
        data = {'userId': 'reporter', 'text': 'عقار جميل', 'isHidden': False}
        path = 'properties/target/comments/safety-comment'
        self.assertEqual(write(path, data), 200)
        self.assertEqual(write(path, {'isHidden': True}, 'admin', True, None), 200)
        self.assertEqual(write(path, data), 403)
        self.assertEqual(write(path, {**data, 'isHidden': True, 'text': 'porn'}), 403)
        self.assertEqual(write('properties/target/comments/blocked', {**data, 'userId': 'blocked'}, 'blocked'), 403)
        self.assertEqual(write('properties/target/comments/spoof', {**data, 'userId': 'publisher'}), 403)
        self.assertEqual(write('properties/target/comments/safety-comment/replies/new', data), 200)

    def test_verified_office_publishes_immediately_but_cannot_be_impersonated(self):
        office = {'ownerId': 'publisher', 'isVerified': True, 'status': 'active'}
        self.assertEqual(write('offices/verified', office, 'SEED', timestamp=None), 200)
        data = {'userId': 'publisher', 'publisherUid': 'publisher', 'officeId': 'verified', 'status': 'approved', 'title': 'بيت للبيع'}
        self.assertEqual(write('properties/verified-direct', data, 'publisher'), 200)
        self.assertEqual(write('properties/spoof-office', {**data, 'userId': 'reporter', 'publisherUid': 'reporter'}), 403)
        for i, text in enumerate(['PORN', 'بيت\nPORN', 'إبَاحي', 'p\u200born']):
            self.assertEqual(write(f'properties/verified-bad-{i}', {**data, 'title': text}, 'publisher'), 403)

    def test_office_registration_and_owner_edits_remain_available(self):
        data = {'ownerId': 'reporter', 'name': 'مكتب الرمادي', 'status': 'pending'}
        self.assertEqual(write('officeRequests/new-office', data), 200)
        self.assertEqual(write('officeRequests/new-office', {'name': 'مكتب الأنبار'}, 'reporter', True, None), 200)
        self.assertEqual(write('officeRequests/blocked-office', {**data, 'ownerId': 'blocked'}, 'blocked'), 403)
        self.assertEqual(write('offices/owner-edit', {'ownerId': 'reporter', 'name': 'مكتب', 'status': 'active'}, 'SEED', timestamp=None), 200)
        self.assertEqual(write('offices/owner-edit', {'name': 'مكتب الرمادي'}, 'reporter', True, 'updatedAt'), 200)

    def test_reviews_and_owner_replies_publish_immediately(self):
        self.assertEqual(write('offices/reviewed', {'ownerId': 'publisher', 'status': 'active'}, 'SEED', timestamp=None), 200)
        data = {'userId': 'reporter', 'officeId': 'reviewed', 'comment': 'خدمة جيدة', 'status': 'published'}
        self.assertEqual(write('office_reviews/direct-review', data), 200)
        self.assertEqual(write('office_reviews/direct-review', {'hasOwnerReply': True, 'ownerReply': 'شكراً لكم'}, 'publisher', True, 'updatedAt'), 200)
        self.assertEqual(write('office_reviews/direct-review', {'ownerReply': 'PORN'}, 'publisher', True, 'updatedAt'), 403)
        self.assertEqual(write('office_reviews/direct-review', {'status': 'hidden'}, 'admin', True, None), 200)
        self.assertEqual(write('office_reviews/direct-review', data), 403)

    def test_no_self_approval_or_author_change(self):
        path = 'properties/safety-property'
        data = {'userId': 'reporter', 'publisherUid': 'reporter', 'status': 'pending', 'title': 'بيت للبيع'}
        self.assertEqual(write(path, data), 200)
        self.assertEqual(write(path, {**data, 'status': 'approved'}), 403)
        self.assertEqual(write(path, {**data, 'userId': 'publisher'}), 403)
        self.assertEqual(write(path, {'status': 'approved'}, 'admin', True, None), 200)
        self.assertEqual(write(path, {'title': 'تعديل بعد النشر'}, 'reporter', True, None), 403)
        self.assertEqual(write(path, {'title': 'تعديل بعد النشر', 'status': 'pending'}, 'reporter', True, None), 200)


if __name__ == '__main__': unittest.main(verbosity=2)
