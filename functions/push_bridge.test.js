const {test}=require('node:test'),assert=require('node:assert/strict');
const {canonicalEvent,planDevices,deliveryId,oneSignalMessage}=require('./push_bridge_policy');
const {deliverBridge}=require('./push_bridge_delivery');
const os='12345678-1234-4234-a234-123456789abc', old='22345678-1234-4234-a234-123456789abc';
const event=canonicalEvent({userId:'u',type:'comment',propertyId:'p',commentId:'c',title:'test'},null,'n');
const installation={id:'i',uid:'u',active:true,tokenHash:'h',oneSignalId:os};
const device={installationId:'i',uid:'u',active:true,token:'fcm-token',tokenHash:'h',updatedAtMs:Date.now()};
const plan=rollout=>planDevices({uid:'u',installations:[installation],devices:[device],legacySubscriptionId:old,rollout});
test('old/new sender share canonical identity across duplicate inbox documents and transports',()=>{
 assert.equal(event.key,canonicalEvent({...event,pushTransport:'legacy',key:'forged'},null,'other').key);
 assert.equal(canonicalEvent({...event,deliveryType:'internal'},null,'n'),null);
});
test('old + new recipient installations are routed individually; rollback keeps old subscriptions',()=>{
 assert.deepEqual(plan({mode:'legacy'}).map(x=>x.provider),['onesignal','onesignal']);
 assert.deepEqual(plan({mode:'fcm',percent:100}).map(x=>x.provider),['fcm','onesignal']);
 assert.deepEqual(plan({mode:'paused'}),[]);
 assert.equal(deliveryId(event,plan({mode:'legacy'})[0]),deliveryId(event,plan({mode:'fcm',percent:100})[0]));
});
test('mapped old profile subscription does not duplicate or survive detach',()=>{
 assert.equal(planDevices({uid:'u',installations:[installation],devices:[device],legacySubscriptionId:os}).length,1);
 assert.equal(planDevices({uid:'u',installations:[{...installation,active:false}],devices:[device],legacySubscriptionId:os}).length,0);
 assert.equal(planDevices({uid:'old-user',installations:[],devices:[],legacySubscriptionId:os,legacyBinding:{uid:'new-user',active:true}}).length,0);
});
test('OneSignal uses a stable UUID idempotency key per event/device and no broad audience',()=>{
 const message=oneSignalMessage(event,plan({mode:'legacy'})[0],'test-app');
 assert.match(message.idempotency_key,/^[a-f0-9-]{36}$/);assert.deepEqual(message.include_subscription_ids,[os]);assert.equal(message.included_segments,undefined);
});
test('legacy direct FCM recovery requires explicit UID cohort and unexpired, verified token approval',()=>{
 const token='old-version-fcm-token-secret';
 const {hash}=require('./push_policy');
 const base={uid:'u',devices:[],installations:[],legacySubscriptionId:old,legacyFcmToken:token,legacyFcmApproval:{uid:'u',active:true,tokenHash:hash(token),expiresAtMs:Date.now()+60000}};
 const recover=planDevices({...base,rollout:{mode:'fcm',legacyRecovery:'fcm',legacyRecoveryAllowlist:['u']}});
 assert.equal(recover[0].provider,'fcm');
 assert.equal(deliveryId(event,recover[0]),deliveryId(event,planDevices(base)[0]));
 assert.equal(planDevices({...base,rollout:{mode:'fcm',legacyRecovery:'fcm'}})[0].provider,'onesignal');
 assert.equal(planDevices({...base,legacyFcmApproval:{...base.legacyFcmApproval,expiresAtMs:0},rollout:{mode:'fcm',legacyRecovery:'fcm',legacyRecoveryAllowlist:['u']}})[0].provider,'onesignal');
});
test('concurrent old/new ingress, provider rollback, ambiguous failures never double-send',async()=>{
 const claims=new Map(),sends=[];
 const store={claim:async(id,e,t)=>{if(claims.has(id))return false;claims.set(id,{status:'attempting',provider:t.provider});return true;},finish:async(id,v)=>claims.set(id,v)};
 const run=targets=>deliverBridge({event,targets,store,sendFcm:async()=>{sends.push('fcm');throw {code:'timeout'};},sendOneSignal:async()=>{sends.push('onesignal');return {id:'ok'};},appId:'test'});
 await Promise.all([run(plan({mode:'fcm',percent:100})),run(plan({mode:'fcm',percent:100}))]);
 await run(plan({mode:'legacy'}));assert.deepEqual(sends.sort(),['fcm','onesignal']);assert.equal([...claims.values()].filter(x=>x.status==='review_required').length,1);
});
test('accepted send with failed receipt write stays claimed and is not sent again',async()=>{
 const claimed=new Set();let sends=0;
 const store={claim:async id=>{if(claimed.has(id))return false;claimed.add(id);return true;},finish:async()=>{throw Error('database unavailable');}};
 const run=()=>deliverBridge({event,targets:[plan({mode:'fcm',percent:100})[0]],store,sendFcm:async()=>{sends++;return 'ok';},sendOneSignal:async()=>{},appId:'test'});
 await assert.rejects(run());await run();assert.equal(sends,1);
});

test('unmapped legacy subscription blocks dual delivery when optional binding fails',()=>{
 const targets=planDevices({uid:'u',devices:[device],installations:[{...installation,oneSignalId:null}],legacySubscriptionId:old,rollout:{mode:'fcm',percent:100}});
 assert.deepEqual(targets.map(t=>t.provider),['onesignal']);
 assert.equal(targets[0].endpoint,old);
 const newUser=planDevices({uid:'u',devices:[device],installations:[{...installation,oneSignalId:null}],rollout:{mode:'fcm',percent:100}});
 assert.deepEqual(newUser.map(t=>t.provider),['fcm']);
});
