import os,pathlib,plistlib,json
p=pathlib.Path('ios/Runner/GoogleService-Info.plist')
c=plistlib.loads(pathlib.Path('tools/test-firebase-ios.template.plist').read_bytes())
assert c['PROJECT_ID']=='aqar-media-test-20261018' and c['BUNDLE_ID']=='local.aqar.fullMediaTest'
k=os.environ.get('MEDIA_TEST_FIREBASE_API_KEY','')
c['API_KEY']=k or 'media-test-build-only-no-auth'
c['STORAGE_BUCKET']='aqar-media-test-20261018-media'
p.write_bytes(plistlib.dumps(c))
pathlib.Path('build').mkdir(exist_ok=True)
pathlib.Path('build/test-dart-defines.json').write_text(json.dumps({'MEDIA_TEST_FIREBASE_API_KEY':k or 'media-test-build-only-no-auth'}))
pathlib.Path('build/cloud-config-status.json').write_text(json.dumps({'testProjectOnly':True,'runtimeCloudConfigured':bool(k),'cloudIntegrationTests':'NOT RUN; isolated cloud is closed'}))
print('Isolated native configuration prepared; values omitted; cloud configured='+str(bool(k)))

# Firebase Core compares native/default and explicit Dart options. A different
# storage bucket is a duplicate-app error even when the project/app ID match.
import re
source=pathlib.Path('lib/full_test_options.dart').read_text()
ios=source.split('const iosOptions =')[1].split(';')[0]
parity={}
for field,native in [('appId','GOOGLE_APP_ID'),('messagingSenderId','GCM_SENDER_ID'),('projectId','PROJECT_ID'),('storageBucket','STORAGE_BUCKET'),('iosBundleId','BUNDLE_ID')]:
 match=re.search(field+r"[: ]+['\"]([^'\"]+)",ios)
 parity[field]=bool(match and match.group(1)==c.get(native))
assert all(parity.values()),'Native/Dart isolated configuration mismatch; values omitted'
assert "String.fromEnvironment('MEDIA_TEST_FIREBASE_API_KEY'" in ios
out=pathlib.Path('build/ios-test-evidence');out.mkdir(parents=True,exist_ok=True)
(out/'native-config-parity.json').write_text(json.dumps({'matchingFields':parity,'APIKeyFromSharedCIEnvironment':True,'valuesLogged':False},indent=2))
print('Native/Dart isolated configuration parity PASS; values omitted')
