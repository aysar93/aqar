import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("prepare", Path(__file__).with_name("prepare_booking_ios_staging.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class IsolatedIosPreparation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        for directory in ("lib", "ios/Runner", "ios/BookingsStaging"):
            (self.source / directory).mkdir(parents=True)
        (self.source / "pubspec.yaml").write_text("name: fixture\n")
        self.original = {"CFBundleDisplayName": "original", "CFBundleURLTypes": [{"CFBundleURLSchemes": ["original-oauth"]}]}
        (self.source / "ios/Runner/Info.plist").write_bytes(plistlib.dumps(self.original))
        (self.source / "ios/Runner/GoogleService-Info.plist").write_bytes(plistlib.dumps({"PROJECT_ID":"production-fixture"}))
        (self.source / "ios/BookingsStaging/Staging.xcconfig").write_text("// fixture\n")
        self.config = {"PROJECT_ID": module.PROJECT, "BUNDLE_ID": module.BUNDLE,
                       "GCM_SENDER_ID": module.SENDER,
                       "STORAGE_BUCKET": module.PROJECT + ".firebasestorage.app",
                       "GOOGLE_APP_ID": "1:" + module.SENDER + ":ios:synthetic",
                       "API_KEY": "synthetic-local-config-only"}
        self.plist = self.root / "stage.plist"

    def run_prepare(self):
        self.plist.write_bytes(plistlib.dumps(self.config))
        return module.prepare(self.source, self.plist, self.root / "isolated")

    def test_rejects_production_before_output_exists(self):
        self.config["PROJECT_ID"] = "aqar-9f3f9"
        with self.assertRaises(ValueError): self.run_prepare()
        self.assertFalse((self.root / "isolated").exists())

    def test_rejects_wrong_bundle_and_bucket(self):
        for key, value in (("BUNDLE_ID", "com.andalus.aqar"), ("STORAGE_BUCKET", "other.appspot.com")):
            with self.subTest(key=key):
                original = self.config[key]
                self.config[key] = value
                with self.assertRaises(ValueError): self.run_prepare()
                self.config[key] = original

    def test_isolates_resources_and_preserves_source(self):
        result = self.run_prepare()
        self.assertFalse(result["built"])
        source_config = plistlib.loads((self.source / "ios/Runner/GoogleService-Info.plist").read_bytes())
        self.assertEqual(source_config["PROJECT_ID"], "production-fixture")
        target = self.root / "isolated"
        stage_config = plistlib.loads((target / "ios/Runner/GoogleService-Info.plist").read_bytes())
        self.assertEqual(stage_config["PROJECT_ID"], module.PROJECT)
        info = plistlib.loads((target / "ios/BookingsStaging/Info.plist").read_bytes())
        self.assertNotIn("CFBundleURLTypes", info)
        self.assertEqual(plistlib.loads((self.source / "ios/Runner/Info.plist").read_bytes()), self.original)

    def test_refuses_existing_output(self):
        output = self.root / "isolated"
        output.mkdir()
        marker = output / "keep"
        marker.write_text("preserve")
        with self.assertRaises(ValueError): self.run_prepare()
        self.assertEqual(marker.read_text(), "preserve")


if __name__ == "__main__": unittest.main()
