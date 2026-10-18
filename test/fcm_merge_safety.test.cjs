'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),cp=require('node:child_process'),vm=require('node:vm');
const {prepare}=require('../tools/prepare_fcm_bridge_codebase.cjs');
test('default configuration preserves legacy writers and excludes the FCM codebase',()=>{
 const config=JSON.parse(fs.readFileSync('firebase.json','utf8')),rules=fs.readFileSync(config.firestore.rules,'utf8'),index=fs.readFileSync('functions/index.js','utf8');
 assert.ok(!rules.includes('validPushSource'));assert.match(rules,/allow create: if isSignedIn\(\);/);assert.equal(config.functions.length,1);assert.equal(config.functions[0].codebase,'default');assert.ok(config.functions[0].ignore.includes('push_*.js'));assert.doesNotMatch(index,/require\(['"]\.\/push_(functions|bridge_functions)/);
 const deferred=fs.readFileSync('config/firestore/notifications-strict.deferred.rules','utf8');assert.match(deferred,/validPushSource/);assert.equal(JSON.parse(fs.readFileSync('firebase.push-test.json','utf8')).firestore.rules,'config/firestore/notifications-strict.deferred.rules');
});
test('offline FCM packaging exports only eight functions with the two existing isolated identities, without credentials',()=>{
 const manifest=prepare();assert.equal(manifest.functions.length,8);assert.equal(manifest.credentialsCopied,false);
 const generated='build/fcm-bridge-source/',index=fs.readFileSync(generated+'index.js','utf8'),events=fs.readFileSync(generated+'push_bridge_functions.js','utf8');assert.equal((events.match(/serviceAccount:'aqar-push-events@aqar-9f3f9\.iam\.gserviceaccount\.com'/g)||[]).length,4);assert.match(index,/aqar-push-runtime@/);assert.doesNotMatch(index,/chat_functions|analytics_presence_access|deliverFcmNotification|sendNotificationToUser/);
 const exports={},modules={};for(const name of manifest.functions)modules[name]=name;
 let options;vm.runInNewContext(index,{process:{env:{GCLOUD_PROJECT:'aqar-9f3f9'}},exports,require:name=>name==='firebase-admin/app'?{initializeApp:()=>{}}:name==='firebase-functions/v2'?{setGlobalOptions:v=>{options=v;}}:modules});assert.deepEqual(Object.keys(exports).sort(),manifest.functions.slice().sort());assert.equal(options.maxInstances,2);
 assert.ok(!fs.readdirSync(generated).some(n=>n.startsWith('.env')||/credential|service.account/i.test(n)));
});
test('independent deployment configuration fails closed without deployment approval',()=>{
 const config=JSON.parse(fs.readFileSync('firebase.fcm-production.paused.json','utf8'));assert.equal(config.functions[0].codebase,'push-bridge');assert.equal(config.functions[0].source,'build/fcm-bridge-source');assert.ok(!config.firestore&&!config.storage);
 const env={...process.env};delete env.FCM_PRODUCTION_DEPLOY_APPROVED;
 const result=cp.spawnSync(process.execPath,['tools/guard_fcm_deployment.cjs'],{encoding:'utf8',env});assert.equal(result.status,1);assert.match(result.stderr,/FCM_DEPLOYMENT_BLOCKED/);
});
test('existing broad and native workflows are manual; only targeted emulator CI is automatic',()=>{
 for(const name of fs.readdirSync('.github/workflows')){const s=fs.readFileSync('.github/workflows/'+name,'utf8');if(name==='fcm-merge-safety.yml'){assert.match(s,/pull_request:/);assert.doesNotMatch(s,/flutter build|firebase deploy|vercel deploy|secrets\./);}else assert.doesNotMatch(s,/^  (push|pull_request):/m);}
 const codemagic=fs.readFileSync('codemagic.yaml','utf8');assert.doesNotMatch(codemagic,/^\s+triggering:/m);
});
test('integration branch does not change Cloudinary, chat media or reels service code from main',()=>{
 for(const file of ['lib/services/cloudinary_service.dart','lib/chat/services/chat_audio_service.dart','lib/reels/services/reel_service.dart']){const original=cp.execFileSync('git',['show','origin/main:'+file]);assert.deepEqual(fs.readFileSync(file),original);}
});
