"""Validate production *build inputs* offline. Does not contact Firebase or sign."""
import json
import pathlib
import plistlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = 'aqar-9f3f9'
SENDER = '1031621585901'
BUNDLE = 'com.andalus.aqar'


def validate(config, android, ios):
    if config.get('PUSH_BRIDGE') is not True or config.get('FCM_MIGRATION') is not False:
        raise ValueError('Explicit bridge candidate flags required')
    if config.get('BRIDGE_ONESIGNAL_APP_ID') != '810a4d8d-cfac-492a-956e-0cff98248d25':
        raise ValueError('Wrong production OneSignal app')
    if android['project_info']['project_id'] != PROJECT or str(android['project_info']['project_number']) != SENDER:
        raise ValueError('Wrong Android production Firebase project')
    matches = [c for c in android['client'] if c['client_info']['android_client_info']['package_name'] == BUNDLE]
    if len(matches) != 1 or matches[0]['client_info']['mobilesdk_app_id'] != '1:1031621585901:android:25571868cd8afe2d4b95e4':
        raise ValueError('Wrong Android Firebase application')
    if (ios.get('PROJECT_ID'), ios.get('GCM_SENDER_ID'), ios.get('BUNDLE_ID'), ios.get('GOOGLE_APP_ID')) != (
        PROJECT, SENDER, BUNDLE, '1:1031621585901:ios:a8834b5b6455a5224b95e4'):
        raise ValueError('Wrong iOS production Firebase application')
    return {'project': PROJECT, 'sender': SENDER, 'bundle': BUNDLE, 'compileOnly': True, 'productionContacted': False}


if __name__ == '__main__':
    config = json.loads((ROOT / 'config/push-bridge.rc.json').read_text())
    android = json.loads((ROOT / 'android/app/google-services.json').read_text())
    with (ROOT / 'ios/Runner/GoogleService-Info.plist').open('rb') as stream:
        ios = plistlib.load(stream)
    result = validate(config, android, ios)
    dart = (ROOT / 'lib/firebase_options.dart').read_text()
    if '1:1031621585901:android:25571868cd8afe2d4b95e4' not in dart or '1:1031621585901:ios:a8834b5b6455a5224b95e4' not in dart:
        raise ValueError('Dart/native Firebase app mismatch')
    if '--apply-ios' in sys.argv:
        path = ROOT / 'ios/Runner/Info.plist'
        with path.open('rb') as stream:
            info = plistlib.load(stream)
        info['AqarPushBridgeCandidate'] = True
        with path.open('wb') as stream:
            plistlib.dump(info, stream)
    print(json.dumps(result))
