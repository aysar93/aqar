import subprocess,json,pathlib,time,plistlib,re,os,shutil
D=pathlib.Path('build/ios-test-evidence');D.mkdir(parents=True,exist_ok=True)
def run(*a):return subprocess.check_output(a,text=True).strip()
app=pathlib.Path('build/ios/iphonesimulator/Runner.app');p=plistlib.loads((app/'Info.plist').read_bytes());bundle=p['CFBundleIdentifier'];assert bundle=='local.aqar.fullMediaTest'
devices=json.loads(run('xcrun','simctl','list','devices','available','-j'))
candidates=[d for runtime,ds in devices['devices'].items() if 'iOS' in runtime for d in ds if d['name'].startswith('iPhone')];assert candidates,'No iPhone simulator available'
d=candidates[0];uid=d['udid']
if d['state']!='Booted':run('xcrun','simctl','boot',uid)
run('xcrun','simctl','bootstatus',uid,'-b');run('xcrun','simctl','install',uid,str(app))
raw=D/'console.raw';handle=raw.open('w')
proc=subprocess.Popen(['flutter','run','--no-pub','--debug','--target=lib/main_full_test.dart','--use-application-binary='+str(app),'-d',uid],stdout=handle,stderr=subprocess.STDOUT,text=True,stdin=subprocess.PIPE)
for attempt in range(18):
 time.sleep(5)
 if proc.poll() is not None:break
 if 'MEDIA_TEST_FIRST_FRAME' in raw.read_text(errors='replace'):break
time.sleep(15)
processes=run('ps','-axo','pid=,command=');matches=[x.strip() for x in processes.splitlines() if 'Runner.app/Runner' in x and '/CoreSimulator/' in x]
alive=bool(matches)
run('xcrun','simctl','io',uid,'screenshot',str(D/'full-app-simulator.png'))
if proc.poll() is None:proc.terminate()
try:proc.wait(timeout=10)
except subprocess.TimeoutExpired:proc.kill();proc.wait()
handle.close()
def redact(text):
 key=os.environ.get('MEDIA_TEST_FIREBASE_API_KEY','')
 if key:text=text.replace(key,'<CLIENT KEY REDACTED>')
 text=re.sub(r'AIza[0-9A-Za-z_-]{25,}','<CLIENT KEY REDACTED>',text)
 text=re.sub(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+','<JWT REDACTED>',text)
 text=re.sub(r'https?://(?:127\.0\.0\.1|localhost):\d+/[^\s]+','<LOCAL DEBUG URI REDACTED>',text)
 return text
text=redact(raw.read_text(errors='replace'));errors=re.findall(r'Unhandled Exception|FATAL EXCEPTION|terminating.*uncaught|core/duplicate-app',text,re.I);firstFrame='MEDIA_TEST_FIRST_FRAME' in text;(D/'console-redacted.log').write_text(text);raw.unlink()
for report in pathlib.Path.home().joinpath('Library/Logs/DiagnosticReports').glob('Runner*'):
 if report.is_file() and time.time()-report.stat().st_mtime<600:
  (D/report.name).write_text(redact(report.read_text(errors='replace')))
r={'simulator':d['name'],'bundle':bundle,'processAliveAfterFlutterDebugLaunch':alive,'processEvidence':matches,'firstFlutterFrameObserved':firstFrame,'unhandledOrFatalCount':len(errors),'physicalDeviceTest':False,'cloudCRUD':'NOT RUN','note':'Startup smoke only; screenshot and diagnostics must be reviewed'}
(D/'simulator-smoke.json').write_text(json.dumps(r,indent=2));print(json.dumps({'simulator':d['name'],'processAlive':alive,'diagnosticsCaptured':True}));assert alive and firstFrame and not errors,'Startup validation failed; inspect redacted console/crash reports and first-frame evidence'
