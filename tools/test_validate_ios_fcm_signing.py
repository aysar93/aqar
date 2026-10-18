import copy
import datetime
import unittest
from validate_ios_fcm_signing import validate, TEAM, BUNDLE


class SigningTest(unittest.TestCase):
    def setUp(self):
        self.now = datetime.datetime(2026, 10, 14, tzinfo=datetime.timezone.utc)
        self.profile = {'TeamIdentifier': [TEAM], 'Name': 'Staging test', 'UUID': 'fixture',
                        'ExpirationDate': datetime.datetime(2027, 1, 1),
                        'ProvisionedDevices': ['synthetic-device'],
                        'Entitlements': {'application-identifier': f'{TEAM}.{BUNDLE}',
                                         'aps-environment': 'production', 'get-task-allow': False}}

    def test_accepts_only_complete_adhoc_profile(self):
        self.assertEqual(validate(self.profile, self.now)['deviceCount'], 1)

    def test_rejects_production_bundle_and_wrong_team(self):
        for team, bundle in [(TEAM, 'com.andalus.aqar'), ('WRONGTEAM', BUNDLE)]:
            profile = copy.deepcopy(self.profile)
            profile['TeamIdentifier'] = [team]
            profile['Entitlements']['application-identifier'] = f'{team}.{bundle}'
            with self.assertRaises(ValueError):
                validate(profile, self.now)

    def test_rejects_development_or_missing_apns(self):
        for environment in ['development', None]:
            profile = copy.deepcopy(self.profile)
            profile['Entitlements']['aps-environment'] = environment
            with self.assertRaises(ValueError):
                validate(profile, self.now)

    def test_rejects_expired_and_device_free_profile(self):
        for key, value in [('ExpirationDate', datetime.datetime(2025, 1, 1)), ('ProvisionedDevices', [])]:
            profile = copy.deepcopy(self.profile)
            profile[key] = value
            with self.assertRaises(ValueError):
                validate(profile, self.now)

    def test_rejects_debug_profile(self):
        self.profile['Entitlements']['get-task-allow'] = True
        with self.assertRaises(ValueError):
            validate(self.profile, self.now)


if __name__ == '__main__':
    unittest.main()
