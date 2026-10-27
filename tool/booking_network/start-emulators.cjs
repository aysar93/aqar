'use strict';
const fs=require('node:fs'), path=require('node:path'), {spawn}=require('node:child_process');
const repo=path.resolve(__dirname,'../..'), runtime=path.join(__dirname,'.local');
if(process.argv[2]!=='--run') throw Error('Explicit --run required; local demo only');
fs.mkdirSync(runtime,{recursive:true});
const source=path.join(runtime,'functions');fs.mkdirSync(source,{recursive:true});
const dependencies=path.join(source,'node_modules');
if(!fs.existsSync(dependencies)) fs.symlinkSync(path.join(repo,'functions/node_modules'),dependencies,'junction');
fs.writeFileSync(path.join(source,'index.js'),"module.exports=require('../../emulator-index.cjs');\n");
fs.writeFileSync(path.join(source,'package.json'),JSON.stringify({name:'booking-local-only',main:'index.js',engines:{node:'24'},dependencies:{'firebase-admin':'^14.5.0','firebase-functions':'^7.4.0'}}));
const config={functions:{source:'functions'},firestore:{rules:path.join(repo,'firestore.rules')},storage:{rules:path.join(repo,'storage.rules')},emulators:{
  auth:{host:'127.0.0.1',port:9099},functions:{host:'127.0.0.1',port:5002},
  firestore:{host:'127.0.0.1',port:8185},storage:{host:'127.0.0.1',port:9198},
  hub:{host:'127.0.0.1',port:4409},logging:{host:'127.0.0.1',port:4509},ui:{enabled:false},singleProjectMode:true}};
const configPath=path.join(runtime,'firebase.json');fs.writeFileSync(configPath,JSON.stringify(config));
const cli=path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/bin/firebase.js');
if(!fs.existsSync(cli))throw Error('Existing Firebase CLI required; no installation/download');
const env={...process.env,GCLOUD_PROJECT:'demo-aqar',GOOGLE_CLOUD_PROJECT:'demo-aqar',
 FIRESTORE_EMULATOR_HOST:'127.0.0.1:8185',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:9099',FIREBASE_STORAGE_EMULATOR_HOST:'127.0.0.1:9198',
 FIREBASE_CONFIG:JSON.stringify({projectId:'demo-aqar',storageBucket:'demo-aqar.appspot.com'}),
 FIREBASE_CLI_DISABLE_UPDATE_CHECK:'1',CI:'true',
 // Local CLI worker startup only; not a deployed handler/security/TTL setting.
 FUNCTIONS_DISCOVERY_TIMEOUT:'120',
 BOOKING_LOCAL_INGRESS_LOG:path.join(runtime,'ingress-events.jsonl'),
 NODE_OPTIONS:`--require "${path.join(__dirname,'loopback-only.cjs').replaceAll('\\','/')}" --require "${path.join(__dirname,'receiver-observer.cjs').replaceAll('\\','/')}"`};
delete env.FIREBASE_TOKEN; delete env.GOOGLE_APPLICATION_CREDENTIALS;
const log=fs.openSync(path.join(runtime,'startup.log'),'a');
const child=spawn(process.execPath,[cli,'emulators:start','--project','demo-aqar','--config',configPath,'--only','auth,firestore,storage,functions','--non-interactive'],{cwd:runtime,env,stdio:['inherit',log,log],windowsHide:true});
console.log(JSON.stringify({project:'demo-aqar',pid:child.pid,log:'tool/booking_network/.local/startup.log',productionOrStageConfigUsed:false}));
process.on('SIGINT',()=>child.kill('SIGINT'));process.on('SIGTERM',()=>child.kill('SIGTERM'));
child.on('exit',code=>{fs.closeSync(log);process.exitCode=code||0;});
