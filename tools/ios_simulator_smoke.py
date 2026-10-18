import subprocess,json,pathlib,time,plistlib
D=pathlib.Path('build/ios-test-evidence');D.mkdir(parents=True,exist_ok=True)
def run(*a):return subprocess.check_output(a,text=True).strip()
app=pathlib.Path('build/ios/iphonesimulator/Runner.app');p=plistlib.loads((app/'Info.plist').read_bytes());assert p['CFBundleIdentifier']=='local.aqar.fullMediaTest'
all=json.loads(run('xcrun','simctl','list','devices','available','-j'))
candidates=[d for runtime,ds in all['devices'].items() if 'iOS' in runtime for d in ds if d['name'].startswith('iPhone')];assert candidates,'No iPhone simulator available'
d=candidates[0];uid=d['udid']
if d['state']!='Booted':run('xcrun','simctl','boot',uid)
run('xcrun','simctl','bootstatus',uid,'-b');run('xcrun','simctl','install',uid,str(app))
launch=run('xcrun','simctl','launch',uid,'local.aqar.fullMediaTest');time.sleep(12)
run('xcrun','simctl','io',uid,'screenshot',str(D/'full-app-simulator.png'))
processes=run('xcrun','simctl','spawn',uid,'launchctl','list')
alive='local.aqar.fullMediaTest' in processes
(D/'simulator-smoke.json').write_text(json.dumps({'simulator':d['name'],'bundle':p['CFBundleIdentifier'],'launchResult':launch,'processAliveAfter12Seconds':alive,'physicalDeviceTest':False,'cloudCRUD':'NOT RUN','note':'Startup smoke only; screenshot requires review'},indent=2));assert alive,'Test process did not remain alive'
