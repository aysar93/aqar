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
if config.get('PUSH_BRIDGE') is True:
    assert config.get('BRIDGE_ONESIGNAL_APP_ID') == '2ef06b79-ae17-4ae0-afd1-3c2a766de0f4', 'Dedicated test OneSignal app required'
for native_key, config_key in [("PROJECT_ID", "STAGING_PROJECT_ID"), ("GOOGLE_APP_ID", "STAGING_APP_ID"), ("GCM_SENDER_ID", "STAGING_SENDER_ID"), ("API_KEY", "STAGING_API_KEY")]:
    assert str(native[native_key]) == config[config_key], f"Mismatch: {native_key}"
assert native["BUNDLE_ID"] == "com.andalus.aqar.staging"
out = root / "work" / "ios-fcm-staging"
out.mkdir(parents=True, exist_ok=True)
pbx = (root / "ios/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
pbx = pbx.replace("PRODUCT_BUNDLE_IDENTIFIER = com.andalus.aqar;", "PRODUCT_BUNDLE_IDENTIFIER = com.andalus.aqar.staging;")
pbx = pbx.replace("PRODUCT_BUNDLE_IDENTIFIER = com.andalus.aqar.RunnerTests;", "PRODUCT_BUNDLE_IDENTIFIER = com.andalus.aqar.staging.RunnerTests;")
(out / "project.pbxproj").write_text(pbx, encoding="utf-8")
with (root / 'ios/Runner/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
# The isolated test app must not initialize the production social application.
for key in ['CFBundleURLTypes', 'FacebookAppID', 'FacebookClientToken', 'FacebookDisplayName']:
    info.pop(key, None)
info['FacebookAutoInitEnabled'] = False
info['FacebookAutoLogAppEventsEnabled'] = False
info['FacebookAdvertiserIDCollectionEnabled'] = False
info['CFBundleDisplayName'] = 'Aqar FCM staging'
with (out / 'Info.plist').open('wb') as stream:
    plistlib.dump(info, stream)
with (out / "GoogleService-Info.plist").open("wb") as stream:
    plistlib.dump(native, stream)
if '--apply' in sys.argv[3:]:
    import shutil
    shutil.copyfile(out / 'project.pbxproj', root / 'ios/Runner.xcodeproj/project.pbxproj')
    shutil.copyfile(out / 'Info.plist', root / 'ios/Runner/Info.plist')
    shutil.copyfile(out / 'GoogleService-Info.plist', root / 'ios/Runner/GoogleService-Info.plist')
print("Validated and prepared iOS staging inputs:", out)
