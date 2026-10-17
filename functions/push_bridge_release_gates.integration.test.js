'use strict';
const {test,before,beforeEach,after}=require('node:test'),assert=require('node:assert/strict');
const fs=require('fs'),Module=require('module');
if(process.env.GCLOUD_PROJECT!=='demo-aqar'||!['127.0.0.1:8185','localhost:8185'].includes(process.env.FIRESTORE_EMULATOR_HOST))throw Error('DEMO_EMULATOR_ONLY');
let db;const sent=[];const load=Module._load;
async function observe(provider,data){
 const item=await db.doc('notifications/'+data.notificationId).get();
 assert.equal(item.exists,true,'inbox must exist BEFORE provider invocation');assert.equal(item.data().userId,data.userId);
 sent.push({provider,userId:data.userId,notificationId:data.notificationId});return provider==='fcm'?'fake-fcm-id':{id:'fake-onesignal-id'};
}
Module._load=function(name,...args){
 if(name==='firebase-admin/messaging')return {getMessaging:()=>({send:m=>observe('fcm',m.data)})};
 if(name==='firebase-admin/auth')return {getAuth:()=>({getUser:async uid=>({uid,disabled:false})})};
 return load.call(this,name,...args);
};
const handlers=require('./index');
const bridge=require('./push_bridge_functions');
const {dispatchBridge}=require('./push_bridge_dispatch'),{canonicalEvent,planDevices}=require('./push_bridge_policy');
const {hash}=require('./push_policy'),{getFirestore,Timestamp}=require('firebase-admin/firestore');db=getFirestore();
require('./push_onesignal').sendOneSignal=m=>observe('onesignal',m.data);
Module._load=load;
const os='12345678-1234-4234-a234-123456789abc',legacy='22345678-1234-4234-a234-123456789abc';
const inst='a'.repeat(32),other='b'.repeat(32),token='synthetic-emulator-token-only';
const cohort=()=>({userIds:['owner'],installations:[{uid:'owner',id:inst}],legacyTargets:[{uid:'owner',key:'legacy:'+hash(legacy)}],providers:['fcm','onesignal']});
const rollout=extra=>({mode:'fcm',percent:100,legacyIngressCoordinated:true,cohort:cohort(),...extra});
let env;
before(async()=>{const {initializeTestEnvironment}=require('../test/firestore/node_modules/@firebase/rules-unit-testing');env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});});
after(async()=>{await env.cleanup();await db.terminate();});
beforeEach(async()=>{
 await env.clearFirestore();sent.length=0;process.env.FUNCTIONS_EMULATOR='false';process.env.PUSH_BRIDGE_ENABLED='true';process.env.FCM_MIGRATION_ENABLED='true';process.env.BRIDGE_ONESIGNAL_APP_ID='isolated-emulator-only';
 for(const uid of ['owner','sender','admin','outsider'])await db.doc('users/'+uid).set({isAdmin:uid==='admin',notificationsEnabled:true,isBlocked:false});
 await db.doc('settings/app_settings').set({adminUid:'admin'});
 await db.doc('push_bridge_config/rollout').set(rollout());
 await db.doc('push_installations/'+inst).set({uid:'owner',active:true,tokenHash:hash(token),oneSignalId:os});
 await db.doc('push_tokens/'+hash(token)).set({uid:'owner',installationId:inst,active:true,token,updatedAt:Timestamp.now()});
 await db.doc('push_subscription_bindings/'+hash(os)).set({uid:'owner',installationId:inst,active:true});
});
async function inboxEvent(id,data={}){const ref=db.doc('notifications/'+id);await ref.set({userId:'owner',type:'general',title:'isolated',message:'saved body',createdAt:Timestamp.now(),readBy:[],...data});return {authId:'admin',authType:'api_key',params:{notificationId:id},data:{before:{exists:false},after:await ref.get()}};}
const accepted=async()=> (await db.collection('push_deliveries').where('status','==','accepted').get()).size;

test('inbox gate: admin/inbox + legacy HTTP retain correct visible content before each provider',async()=>{
 const {createLegacyIngress}=require('../integrations/vercel/legacy-ingress.cjs');
 for(const [i,type] of ['general','property','property_approved','property_rejected','office','office_notification','office_approved','booking','comment','reply'].entries()){
  const id='inbox-'+i,event=await inboxEvent(id,{type,propertyId:'p',officeId:'o',commentId:'c'+i,replyId:'r'+i,requestId:'booking-id'});
  await bridge.deliverBridgeNotification.run(event);
  const item=(await db.doc('notifications/'+id).get()).data();assert.equal(item.userId,'owner');assert.equal(item.message,'saved body');assert.equal(item.requestId,'booking-id');
  let status;await createLegacyIngress({db,dispatch:p=>dispatchBridge(p,db)})({method:'POST',body:{notificationId:id,userId:'outsider'},socket:{remoteAddress:'127.0.0.1'}},{status(n){status=n;return this;},json(){}});assert.equal(status,200);
 }
 assert.equal(sent.length,10);assert.equal(await accepted(),10);
 const {getDoc,doc}=require('../test/firestore/node_modules/firebase/firestore');
 const {assertSucceeds,assertFails}=require('../test/firestore/node_modules/@firebase/rules-unit-testing');
 await assertSucceeds(getDoc(doc(env.authenticatedContext('owner').firestore(),'notifications/inbox-0')));
 await assertFails(getDoc(doc(env.authenticatedContext('outsider').firestore(),'notifications/inbox-0')));
});

test('inbox gate: comment/reply/chat source-only events create visible items and fold later verified duplicates',async()=>{
 await db.doc('properties/p').set({publisherUid:'owner'});
 const comment=db.doc('properties/p/comments/c');await comment.set({userId:'sender'});
 const parent=db.doc('properties/p/comments/parent');await parent.set({userId:'owner'});
 const reply=db.doc('properties/p/comments/parent/replies/r');await reply.set({userId:'sender'});
 const chat=db.doc('chats/owner/messages/m');await chat.set({senderId:'admin',message:'source chat',isRead:false});
 const events=[
  [bridge.bridgeCommentCreated,{authId:'sender',authType:'api_key',params:{propertyId:'p',commentId:'c'},data:await comment.get()},{type:'comment',propertyId:'p',commentId:'c'}],
  [bridge.bridgeReplyCreated,{authId:'sender',authType:'api_key',params:{propertyId:'p',commentId:'parent',replyId:'r'},data:await reply.get()},{type:'reply',propertyId:'p',commentId:'parent',replyId:'r'}],
  [bridge.bridgeChatMessageCreated,{authId:'admin',authType:'api_key',params:{chatId:'owner',messageId:'m'},data:await chat.get()},{type:'chat_message',chatId:'owner',messageId:'m',unreadCount:1}],
 ];
 for(const [i,[handler,event,data]] of events.entries()){
  await handler.run(event);const modern=await inboxEvent('modern-'+i,data);await bridge.deliverBridgeNotification.run(modern);await handler.run(event);
 }
 assert.equal(sent.length,3);assert.equal(await accepted(),3);
 const items=(await db.collection('notifications').get()).docs;assert.equal(items.length,3);
 for(const item of items){assert.equal(item.data().userId,'owner');assert.ok(item.data().createdAt);assert.equal(item.data().bridgeEventKey.length,64);}
 const {getDoc,doc}=require('../test/firestore/node_modules/firebase/firestore');
 const {assertSucceeds,assertFails}=require('../test/firestore/node_modules/@firebase/rules-unit-testing');
 await assertSucceeds(getDoc(doc(env.authenticatedContext('owner').firestore(),items[0].ref.path)));
 await assertFails(getDoc(doc(env.authenticatedContext('outsider').firestore(),items[0].ref.path)));
});

test('inbox gate: pause and opt-out retain source inbox; wrong recipient, deleted item and failed persistence cannot send',async()=>{
 const push=canonicalEvent({userId:'owner',type:'comment',propertyId:'p',commentId:'c',message:'retained'},null,'source-only');
 await db.doc('push_bridge_config/rollout').set(rollout({mode:'paused'}));await dispatchBridge(push,db);
 const items=await db.collection('notifications').get();assert.equal(items.size,1);assert.equal(sent.length,0);
 await db.doc('users/owner').update({notificationsEnabled:false});await db.doc('push_bridge_config/rollout').set(rollout());await dispatchBridge(push,db);assert.equal(sent.length,0);
 await db.doc('users/owner').update({notificationsEnabled:true});await items.docs[0].ref.delete();await dispatchBridge(push,db);assert.equal((await db.collection('notifications').get()).size,0);assert.equal(sent.length,0);
 const wrong=canonicalEvent({userId:'owner',type:'general'},null,'wrong');await db.doc('notifications/wrong').set({userId:'outsider',type:'general'});await dispatchBridge(wrong,db);assert.equal(sent.length,0);
 const failing={doc:db.doc.bind(db),collection:db.collection.bind(db),runTransaction:async()=>{throw Error('simulated inbox write failure');}};
 await assert.rejects(dispatchBridge(canonicalEvent({userId:'owner',type:'general'},null,'fail'),failing));assert.equal(sent.length,0);assert.equal(await accepted(),0);
});

test('cohort gate: missing/empty cohort, excluded account/device/provider and unapproved legacy cannot send',async()=>{
 const id='candidate';const e=await inboxEvent(id),push=canonicalEvent(e.data.after.data(),null,id);
 const cases=[{...rollout(),cohort:undefined},rollout({cohort:{}}),rollout({cohort:{...cohort(),userIds:['outsider']}}),rollout({cohort:{...cohort(),installations:[{uid:'owner',id:other}],legacyTargets:[]}}),rollout({cohort:{...cohort(),providers:[]}}),rollout({cohort:{...cohort(),userIds:['owner','outsider'],installations:[{uid:'outsider',id:inst}],legacyTargets:[]}})];
 for(const r of cases){if(r.cohort===undefined)delete r.cohort;await db.doc('push_bridge_config/rollout').set(r);assert.deepEqual(await dispatchBridge(push,db),[]);}
 assert.equal(sent.length,0);assert.equal(await accepted(),0);
 const base={uid:'owner',devices:[],installations:[],legacySubscriptionId:legacy};
 assert.deepEqual(planDevices({...base,rollout:rollout({mode:'legacy',cohort:{...cohort(),legacyTargets:[]}})}),[]);
 await db.doc('push_installations/'+other).set({uid:'owner',active:true,oneSignalId:legacy});await db.doc('push_subscription_bindings/'+hash(legacy)).set({uid:'owner',installationId:other,active:true});
 await db.doc('push_bridge_config/rollout').set(rollout());await dispatchBridge(push,db);assert.equal(sent.length,1);assert.equal(sent[0].provider,'fcm');
});

test('cohort gate: allowed OneSignal and legacy FCM are explicit, all other subscriptions stay excluded',async()=>{
 const first=await inboxEvent('allowed-os');await db.doc('push_bridge_config/rollout').set(rollout({mode:'legacy',cohort:{...cohort(),providers:['onesignal']}}));await dispatchBridge(canonicalEvent(first.data.after.data(),null,'allowed-os'),db);
 assert.equal(sent.length,1);assert.equal(sent[0].provider,'onesignal');
 const legacyToken='legacy-synthetic-token-without-device';await db.doc('users/outsider').update({oneSignalId:legacy,fcmToken:legacyToken});
 await db.doc('push_legacy_token_approvals/'+hash(legacyToken)).set({uid:'outsider',active:true,tokenHash:hash(legacyToken),expiresAtMs:Date.now()+60000});
 const r=rollout({legacyRecovery:'fcm',legacyRecoveryAllowlist:['outsider'],cohort:{userIds:['outsider'],installations:[],legacyTargets:[{uid:'outsider',key:'legacy:'+hash(legacy)}],providers:['fcm']}});await db.doc('push_bridge_config/rollout').set(r);
 const p=canonicalEvent({userId:'outsider',type:'general',message:'legacy inbox'},null,'legacy-fcm');await dispatchBridge(p,db);assert.equal(sent.length,2);assert.equal(sent[1].userId,'outsider');assert.equal(sent[1].provider,'fcm');
 await db.doc('push_bridge_config/rollout').set({...r,cohort:{...r.cohort,legacyTargets:[]}});await dispatchBridge({...p,key:hash('another-event'),notificationId:'excluded-legacy'},db);assert.equal(sent.length,2);
});

test('cohort gate: removal after planning cancels FCM and OneSignal claims; old sender cannot bypass bridge pause',async()=>{
 for(const provider of ['fcm','onesignal']){
  await db.doc('push_bridge_config/rollout').set(rollout({mode:provider==='fcm'?'fcm':'legacy'}));
  const e=await inboxEvent('race-'+provider),push=canonicalEvent(e.data.after.data(),null,'race-'+provider);let transactions=0;
  const racing={doc:db.doc.bind(db),collection:db.collection.bind(db),runTransaction:async cb=>{transactions++;if(transactions===2)await db.doc('push_bridge_config/rollout').update({'cohort.userIds':[]});return db.runTransaction(cb);}};
  await dispatchBridge(push,racing);assert.equal(sent.length,0);assert.equal(await accepted(),0);
 }
 const e=await inboxEvent('old-bypass');await handlers.sendNotificationToUser.run({data:e.data.after,params:e.params});assert.equal(sent.length,0);
});



test('inbox gate: concurrent source/client publication keeps one visible item and one claim',async()=>{
 await db.doc('properties/p').set({publisherUid:'owner'});
 const ref=db.doc('properties/p/comments/concurrent');await ref.set({userId:'sender'});
 const modern=await inboxEvent('concurrent-client',{type:'comment',propertyId:'p',commentId:'concurrent'});
 const source={authId:'sender',authType:'api_key',params:{propertyId:'p',commentId:'concurrent'},data:await ref.get()};
 await Promise.all([bridge.bridgeCommentCreated.run(source),bridge.deliverBridgeNotification.run(modern)]);
 assert.equal((await db.collection('notifications').get()).size,1);assert.equal(sent.length,1);assert.equal(await accepted(),1);
});
