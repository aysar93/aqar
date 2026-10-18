import os,pathlib,plistlib,json
p=pathlib.Path('ios/Runner/GoogleService-Info.plist')
c=plistlib.loads(pathlib.Path('tools/test-firebase-ios.template.plist').read_bytes())
assert c['PROJECT_ID']=='aqar-media-test-20261018' and c['BUNDLE_ID']=='local.aqar.fullMediaTest'
k=os.environ.get('MEDIA_TEST_FIREBASE_API_KEY','')
c['API_KEY']=k or 'media-test-build-only-no-auth'
p.write_bytes(plistlib.dumps(c))
pathlib.Path('build').mkdir(exist_ok=True)
pathlib.Path('build/cloud-config-status.json').write_text(json.dumps({'testProjectOnly':True,'runtimeCloudConfigured':bool(k),'cloudIntegrationTests':'NOT RUN; isolated cloud is closed'}))
print('Isolated native configuration prepared; values omitted; cloud configured='+str(bool(k)))
