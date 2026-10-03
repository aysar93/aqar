"""Isolated Firestore emulator tests. Never runs against production."""
import unittest
from firestore_reports_rules_test import call, write, NAME, value

class OfficeGiftRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for path, data in [
            ('users/admin', {'isAdmin': True}),
            ('users/owner', {'isAdmin': False}),
            ('users/other', {'isAdmin': False}),
            ('offices/gift-office', {'ownerId': 'owner', 'status': 'active'}),
            ('subscription_packages/gold', {'name': 'Gold', 'isActive': True}),
        ]:
            assert write(path, data, 'SEED', timestamp=None) == 200

    def request(self, **extra):
        return dict(officeId='gift-office', ownerId='owner', status='pending',
                    paymentMethod='', paymentStatus='pending', **extra)

    def test_admin_can_grant_active_gift_to_another_owner(self):
        gift = self.request()
        gift.update(status='active', paymentMethod='gift', giftedBy='admin', price=0)
        self.assertEqual(write('office_subscriptions/admin-gift', gift, 'admin'), 200)

    def test_owner_cannot_grant_active_subscription(self):
        data = self.request()
        data['status'] = 'active'
        self.assertEqual(write('office_subscriptions/self-active', data, 'owner'), 403)

    def test_owner_cannot_impersonate_gift_even_while_pending(self):
        data = self.request()
        data['paymentMethod'] = 'gift'
        self.assertEqual(write('office_subscriptions/self-gift', data, 'owner'), 403)
        data['paymentMethod'] = ''
        data['giftedBy'] = 'admin'
        self.assertEqual(write('office_subscriptions/forged-admin', data, 'owner'), 403)

    def test_normal_owner_request_still_works(self):
        self.assertEqual(write('office_subscriptions/normal', self.request(), 'owner'), 200)
        self.assertEqual(write('office_subscriptions/foreign', self.request(), 'other'), 403)
        self.assertEqual(call('/office_subscriptions/normal', 'owner'), 200)
        self.assertEqual(call('/office_subscriptions/normal', 'other'), 403)
        self.assertEqual(write('office_subscriptions/normal', {'status': 'active'}, 'owner', True, None), 403)

    def test_only_admin_can_manage_packages(self):
        data = {'name': 'Gold', 'isActive': True}
        self.assertEqual(write('subscription_packages/admin-new', data, 'admin'), 200)
        self.assertEqual(write('subscription_packages/owner-new', data, 'owner'), 403)
        self.assertEqual(write('subscription_packages/gold', {'isActive': False}, 'owner', True, None), 403)
        self.assertEqual(call('/subscription_packages/gold', 'owner'), 200)
        self.assertEqual(call('/subscription_packages/gold'), 403)

    def test_admin_can_atomically_grant_sync_and_notify(self):
        docs = [
            ('office_subscriptions/atomic-gift', {'officeId': 'gift-office', 'ownerId': 'owner', 'status': 'active', 'paymentMethod': 'gift', 'giftedBy': 'admin'}),
            ('offices/gift-office', {'subscriptionId': 'atomic-gift', 'subscriptionStatus': 'active'}),
            ('notifications/gift-notice', {'userId': 'owner', 'officeId': 'gift-office', 'type': 'office_notification', 'title': 'Gift'}),
        ]
        writes = []
        for path, data in docs:
            w = {'update': {'name': NAME + path, 'fields': {k: value(v) for k, v in data.items()}}}
            if path.startswith('offices/'):
                w['updateMask'] = {'fieldPaths': list(data)}
            writes.append(w)
        self.assertEqual(call(':commit', 'admin', {'writes': writes}), 200)
        self.assertEqual(call('/notifications/gift-notice', 'owner'), 200)
        self.assertEqual(call('/notifications/gift-notice', 'other'), 403)

if __name__ == '__main__':
    unittest.main()
