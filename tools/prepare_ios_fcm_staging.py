"""Generate reviewed iOS staging inputs without replacing checked-in files."""
import json
import pathlib
import plistlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
config = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
with pathlib.Path(sys.argv[2]).open("rb") as stream:
    native = plistlib.load(stream)
project = config["STAGING_PROJECT_ID"]
assert project.startswith("aqar-fcm-test-") and project != "aqar-9f3f9"
assert config["FCM_MIGRATION"] is True and config["STAGING_EMULATORS"] is False
for native_key, config_key in [("PROJECT_ID", "STAGING_PROJECT_ID"), ("GOOGLE_APP_ID", "STAGING_APP_ID"), ("GCM_SENDER_ID", "STAGING_SENDER_ID"), ("API_KEY", "STAGING_API_KEY")]:
    assert str(native[native_key]) == config[config_key], f"Mismatch: {native_key}"
assert native["BUNDLE_ID"] == "com.andalus.aqar.staging"
out = root / "work" / "ios-fcm-staging"
out.mkdir(parents=True, exist_ok=True)
pbx = (root / "ios/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
pbx = pbx.replace("PRODUCT_BUNDLE_IDENTIFIER = com.andalus.aqar;", "PRODUCT_BUNDLE_IDENTIFIER = com.andalus.aqar.staging;")
pbx = pbx.replace("PRODUCT_BUNDLE_IDENTIFIER = com.andalus.aqar.RunnerTests;", "PRODUCT_BUNDLE_IDENTIFIER = com.andalus.aqar.staging.RunnerTests;")
(out / "project.pbxproj").write_text(pbx, encoding="utf-8")
with (out / "GoogleService-Info.plist").open("wb") as stream:
    plistlib.dump(native, stream)
print("Validated and prepared iOS staging inputs:", out)
