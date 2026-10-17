'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {ignoreLegacySend}=require('../server-candidates/legacy-ingress-hardening/retired_push_ingress');
test('retired entry points cannot inspect payload, environment or a provider',async()=>{
 const hostile=new Proxy({},{get(){throw Error('retired sender read payload');}});
 for(const flag of [undefined,'false','true']){
  if(flag===undefined)delete process.env.PUSH_BRIDGE_ENABLED;else process.env.PUSH_BRIDGE_ENABLED=flag;
  assert.equal(await ignoreLegacySend(hostile),null);
 }
 for(const file of ['index.js','push_functions.js']){
  const source=fs.readFileSync(__dirname+'/../server-candidates/legacy-ingress-hardening/'+file,'utf8');
  const name=file==='index.js'?'sendNotificationToUser':'deliverFcmNotification';
  const tail=source.slice(source.indexOf('exports.'+name+' ='));
  const definition=tail.slice(0,tail.indexOf('\n);')+4);
  assert.match(definition,/require\('\.\/retired_push_ingress'\)\.ignoreLegacySend/);
  assert.doesNotMatch(definition,/getMessaging|dispatchBridge|\.send\(/);
 }
});
test('actual retired exports stay inert with bridge flags absent, false and true',async()=>{
 const vm=require('node:vm');let providerCalls=0;
 const wrap=(...args)=>({run:args.at(-1)});
 function load(file){
  const module={exports:{}};
  const mockRequire=name=>{
   if(name==='./retired_push_ingress')return {ignoreLegacySend};
   if(name==='firebase-functions/v2/firestore')return {onDocumentCreated:wrap,onDocumentWritten:wrap};
   if(name==='firebase-functions/v2/https')return {onCall:wrap,HttpsError:Error};
   if(name==='firebase-admin/app')return {initializeApp:()=>{}};
   if(name==='firebase-admin/firestore')return {getFirestore:()=>({}),FieldValue:{}};
   if(name==='firebase-admin/auth')return {getAuth:()=>{throw Error('unexpected auth access');}};
   if(name==='firebase-admin/messaging')return {getMessaging:()=>({send:()=>{providerCalls++;throw Error('provider must not run');}})};
   if(name==='./push_onesignal')return {providerSecretOptions:()=>({})};
   if(name.startsWith('./'))return {};
   return require(name);
  };
  vm.runInNewContext('(function(require,module,exports,process){'+fs.readFileSync(__dirname+'/../server-candidates/legacy-ingress-hardening/'+file,'utf8')+'\n})')(mockRequire,module,module.exports,{env:{}});
  return module.exports;
 }
 const handlers=[load('index.js').sendNotificationToUser,load('push_functions.js').deliverFcmNotification];
 for(const flag of [undefined,'false','true']){if(flag===undefined)delete process.env.PUSH_BRIDGE_ENABLED;else process.env.PUSH_BRIDGE_ENABLED=flag;for(const h of handlers)assert.equal(await h.run(new Proxy({},{get(){throw Error('payload read');}})),null);}
 assert.equal(providerCalls,0);
});
