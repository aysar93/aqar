import copy
import json
import pathlib
import plistlib
import unittest
from prepare_push_bridge_rc import validate

ROOT = pathlib.Path(__file__).resolve().parents[1]


class CandidateInputsTest(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / 'config/push-bridge.rc.json').read_text())
        self.android = json.loads((ROOT / 'android/app/google-services.json').read_text())
        with (ROOT / 'ios/Runner/GoogleService-Info.plist').open('rb') as stream:
            self.ios = plistlib.load(stream)

    def test_accepts_production_configuration_for_compile_only(self):
        self.assertTrue(validate(self.config, self.android, self.ios)['compileOnly'])

    def test_rejects_staging_or_mixed_project(self):
        for key, value in [('PROJECT_ID', 'aqar-fcm-test-20261014'), ('BUNDLE_ID', 'com.andalus.aqar.staging'), ('GCM_SENDER_ID', '371338154133')]:
            ios = copy.deepcopy(self.ios)
            ios[key] = value
            with self.assertRaises(ValueError):
                validate(self.config, self.android, ios)

    def test_rejects_missing_candidate_flag(self):
        config = dict(self.config, PUSH_BRIDGE=False)
        with self.assertRaises(ValueError):
            validate(config, self.android, self.ios)


if __name__ == '__main__':
    unittest.main()
