'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {configuration,validateClaims,makeRuntime}=require('./keyless-auth.cjs');
const {assertPaused,createApp}=require('./app.cjs');
const env={FCM_SERVER_PROFILE:'isolated',GCLOUD_PROJECT:'aqar-fcm-test-20261014',VERCEL_ENV:'preview',VERCEL_PROJECT_ID:'prj_TsHXMhxKETjzIjUbjXcxEPQDaKxy',GCP_PROJECT_NUMBER:'123456',FCM_MIGRATION_ENABLED:'true',PUSH_BRIDGE_ENABLED:'true',BRIDGE_ONESIGNAL_ENABLED:'false'};
const paused={mode:'paused',percent:0,legacyIngressCoordinated:false,installationAllowlist:[],legacyRecoveryAllowlist:[],cohort:{userIds:[],installations:[],legacyTargets:[],providers:['fcm']}};
test('production profile cannot bootstrap from Preview or the isolated project',()=>{
 assert.throws(()=>configuration({...env,FCM_SERVER_PROFILE:'production-paused'}),/CONTEXT_REJECTED/);
 assert.throws(()=>configuration({...env,GCLOUD_PROJECT:'aqar-9f3f9'}),/CONTEXT_REJECTED/);
 assert.throws(()=>configuration({...env,VERCEL_PROJECT_ID:'untrusted-project'}),/CONTEXT_REJECTED/);
 assert.throws(()=>configuration({...env,FCM_SERVER_PROFILE:'unknown'}),/CONTEXT_REJECTED/);
});
test('legacy JSON and OneSignal secrets are never read by keyless configuration',()=>{
 const source={...env};for(const k of ['FIREBASE_SERVICE_ACCOUNT','ONESIGNAL_API_KEY','BRIDGE_ONESIGNAL_API_KEY'])Object.defineProperty(source,k,{get(){throw Error('SECRET_WAS_READ');}});
 assert.equal(configuration(source).serviceAccount,'aqar-vercel-keyless-test@aqar-fcm-test-20261014.iam.gserviceaccount.com');
});
test('OIDC precheck rejects cross-project, team and environment before STS',()=>{
 const c=configuration(env),claims={iss:c.issuer,aud:c.audience,owner_id:c.team,project_id:c.vercelProject,environment:c.environment};
 const token=x=>'header.'+Buffer.from(JSON.stringify(x)).toString('base64url')+'.signature';
 assert.equal(validateClaims(token(claims),c),token(claims));
 for(const field of ['iss','aud','owner_id','project_id','environment'])assert.throws(()=>validateClaims(token({...claims,[field]:'wrong'}),c),/OIDC_CONTEXT_REJECTED/);
});
test('federated runtime uses only STS/impersonation and the explicit test database',async()=>{
 const c=configuration(env);let supplied,apps=[];
 const runtime=makeRuntime(c,{getToken:async()=>{throw Error('TOKEN_FETCHED_OUTSIDE_REQUEST');},ExternalAccountClient:{fromJSON(x){supplied=x;return {credentials:{},getAccessToken:async()=>({token:'in-memory-test-token'})};}},GoogleAuth:class{constructor(o){this.options=o;}},Firestore:class{constructor(o){this.options=o;}},initializeApp:a=>apps.push({options:a}),getApps:()=>apps});
 assert.equal(supplied.type,'external_account');assert(supplied.service_account_impersonation_url.includes(c.serviceAccount));
 assert(!('private_key'in supplied));assert(!('credential_source'in supplied));assert.equal(runtime.db.options.projectId,c.project);
 await assert.rejects(supplied.subject_token_supplier.getSubjectToken(),/OUTSIDE_REQUEST/);
});
test('HTTP candidate fails closed if paused state changes and does not leak auth errors',async()=>{
 let rollout=paused,dispatchCalls=0,infraErrors=[];
 const db={doc:()=>({get:async()=>({data:()=>rollout})})};
 const app=createApp({getRuntime:async()=>({db}),dispatch:async()=>dispatchCalls++,onError:error=>infraErrors.push(error)});
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));const base='http://127.0.0.1:'+server.address().port;
 try{
  assert.equal((await fetch(base+'/')).status,200);
  rollout={...paused,mode:'fcm'};assert.equal((await fetch(base+'/send',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({notificationId:'some-id'})})).status,503);assert.equal(dispatchCalls,0);
  rollout={...paused,cohort:{...paused.cohort,userIds:['unexpected-user']}};assert.equal((await fetch(base+'/')).status,503);assert.equal(dispatchCalls,0);
  assert.throws(()=>assertPaused({...paused,percent:1}),/INVARIANT_REQUIRED/);
  const errorCount=infraErrors.length;
  assert.equal((await fetch(base+'/send',{method:'POST',headers:{'Content-Type':'application/json'},body:'{malformed'})).status,400);
  assert.equal((await fetch(base+'/send',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({extra:'x'.repeat(66000)})})).status,413);
  assert.equal(infraErrors.length,errorCount,'Client input must not generate infrastructure alerts');
 }finally{await new Promise(r=>server.close(r));}
});
