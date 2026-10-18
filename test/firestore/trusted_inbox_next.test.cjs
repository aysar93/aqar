'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),fs=require('fs');
if(process.env.GCLOUD_PROJECT!=='demo-aqar'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8186')throw Error('LOCAL_DEMO_ONLY');
process.env.TRUSTED_INBOX_ENABLED='true';process.env.PUSH_BRIDGE_ENABLED='true';process.env.FCM_MIGRATION_ENABLED='true';process.env.FUNCTIONS_EMULATOR='true';
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const sdk=require('firebase/firestore');
const Module=require('module'),original=Module._load;let providerCalls=0;
Module._load=function(name,...args){
 if(name==='firebase-admin/auth')return {getAuth:()=>({getUser:async uid=>({uid,disabled:false})})};
 if(name==='firebase-admin/messaging')return {getMessaging:()=>({send:async()=>{providerCalls++;throw Error('PROVIDER_FORBIDDEN');}})};
 return original.call(this,name,...args);
};
const functionsRequire=Module.createRequire(require('path').resolve('functions/package.json'));
const {initializeApp,deleteApp}=functionsRequire('firebase-admin/app');
const app=initializeApp({projectId:'demo-aqar'}),{getFirestore,FieldValue}=functionsRequire('firebase-admin/firestore'),db=getFirestore();
db.settings({credentials:{client_email:'demo@demo-aqar.iam.gserviceaccount.com',private_key:'unused-emulator-only'}});
const h=require('../../functions/trusted_inbox/handlers'),core=require('../../functions/trusted_inbox/core'),bridge=require('../../functions/push_bridge_functions');
Module._load=original;
let env;after(async()=>{await env?.cleanup();await deleteApp(app);});
const source=(data)=>({exists:true,data:()=>data});
const request=(uid,id,data)=>({authId:uid,authType:'api_key',params:{requestId:id},data:source({createdBy:uid,requestVersion:1,...data})});
test('new trusted inbox: authorization, projection, rules, replay, history and bounded fanout',async t=>{
 const check=(name,fn)=>t.test(name,{skip:!!process.env.TRUSTED_CASE_ONLY&&!name.includes(process.env.TRUSTED_CASE_ONLY)},fn);
 env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{rules:fs.readFileSync('functions/trusted_inbox/firestore.next.rules','utf8')}});await env.clearFirestore();
 for(const [uid,isAdmin] of [['owner',false],['sender',false],['admin',true]])await db.doc('users/'+uid).set({isAdmin,isBlocked:false});
 await db.doc('settings/app_settings').set({allowNotifications:true,adminUid:'admin'});
 await db.doc('push_bridge_config/rollout').set({mode:'paused',percent:0,legacyIngressCoordinated:true,cohort:{userIds:[],installations:[],legacyTargets:[],providers:[]}});
 let item;
 await check('only authenticated administrator requests create trusted recipient items; invalid requests stop permanently',async()=>{
  const payload={target:'user',userId:'owner',type:'general',title:'Synthetic next inbox',message:'local emulator only',deliveryType:'external'};
  await h.requestCreated(request('sender','forged',payload),db);assert.equal((await db.collection('trusted_notifications').get()).size,0);
  await h.requestCreated(request('admin','malformed',{...payload,type:'chat_message'}),db);assert.equal((await db.collection('trusted_notifications').get()).size,0);
  await h.requestCreated(request('admin','valid',payload),db);const rows=await db.collection('trusted_notifications').get();assert.equal(rows.size,1);item=rows.docs[0];assert.equal(item.data().userId,'owner');assert.equal(item.data().verified,true);assert.equal(providerCalls,0);
 });
  await check('clients cannot forge, retarget, erase, read others or mutate source fields; owner state survives replay',async()=>{
  if(!item){await h.requestCreated(request('admin','valid',{target:'user',userId:'owner',type:'general',title:'Synthetic',message:'local only'}),db);item=(await db.collection('trusted_notifications').get()).docs[0];}
  const owner=env.authenticatedContext('owner').firestore(),sender=env.authenticatedContext('sender').firestore(),admin=env.authenticatedContext('admin').firestore(),ref=sdk.doc(owner,item.ref.path);
  const clientItem={...item.data(),createdAt:sdk.Timestamp.now()};
  await assertFails(sdk.setDoc(sdk.doc(sender,'trusted_notifications/forged'),clientItem));
  await assertFails(sdk.setDoc(sdk.doc(admin,'trusted_notifications/admin-forged'),clientItem));
  await assertFails(sdk.getDoc(sdk.doc(sender,item.ref.path)));
  await assertFails(sdk.updateDoc(ref,{userId:'sender'}));await assertFails(sdk.updateDoc(ref,{title:'changed'}));await assertFails(sdk.deleteDoc(ref));
  await assertSucceeds(sdk.updateDoc(ref,{readBy:['owner'],isRead:true,isDismissed:true,updatedAt:sdk.serverTimestamp()}));
  const event=(await db.collection('push_bridge_events').get()).docs[0].data();await core.persistTrusted(event,db);
  assert.deepEqual((await item.ref.get()).data().readBy,['owner']);assert.equal((await item.ref.get()).data().isDismissed,true);
  await assertSucceeds(sdk.getDocs(sdk.query(sdk.collection(owner,'trusted_notifications'),sdk.where('userId','==','owner'),sdk.where('isDismissed','==',false),sdk.orderBy('createdAt','desc'))));
  await assertFails(sdk.setDoc(sdk.doc(sender,'notification_requests/bad'),{createdBy:'sender',requestVersion:1,title:'x',message:'x',type:'general',target:'user',createdAt:sdk.serverTimestamp()}));
  await assertSucceeds(sdk.setDoc(sdk.doc(admin,'notification_requests/allowed'),{createdBy:'admin',requestVersion:1,title:'x',message:'x',type:'general',target:'user',userId:'owner',createdAt:sdk.serverTimestamp()}));
  await assertFails(sdk.updateDoc(sdk.doc(admin,'notification_requests/allowed'),{userId:'sender'}));
  await db.doc('notification_history/old').set({...item.data(),readBy:['owner'],isRead:true,isDismissed:false});
  await assertSucceeds(sdk.getDoc(sdk.doc(owner,'notification_history/old')));await assertFails(sdk.getDoc(sdk.doc(sender,'notification_history/old')));
  await assertSucceeds(sdk.updateDoc(sdk.doc(owner,'notification_history/old'),{isDismissed:true,updatedAt:sdk.serverTimestamp()}));assert.equal((await db.doc('notification_history/old').get()).exists,true);
  // Legacy namespace is intentionally unchanged: legitimate old writers still work.
  await assertSucceeds(sdk.setDoc(sdk.doc(sender,'notifications/legacy-comment'),{userId:'owner',type:'comment',title:'old',message:'old',createdAt:sdk.serverTimestamp()}));
 });
 await check('actual comment source projects a trusted item; hidden parent never projects a reply',async()=>{
  await db.doc('properties/p').set({publisherUid:'owner',status:'approved'});await db.doc('properties/p/comments/c').set({userId:'sender',text:'source',isHidden:false});
  await bridge.bridgeCommentCreated.run({authId:'sender',authType:'api_key',params:{propertyId:'p',commentId:'c'},data:source({userId:'sender',isHidden:false})});
  let rows=await db.collection('trusted_notifications').where('type','==','comment').get();assert.equal(rows.size,1);assert.equal(rows.docs[0].data().userId,'owner');
  await db.doc('properties/p/comments/c').update({isHidden:true});await db.doc('properties/p/comments/c/replies/r').set({userId:'owner',isHidden:false});
  await bridge.bridgeReplyCreated.run({authId:'owner',authType:'api_key',params:{propertyId:'p',commentId:'c',replyId:'r'},data:source({userId:'owner',isHidden:false})});
  assert.equal((await db.collection('trusted_notifications').where('type','==','reply').get()).size,0);
 });
 await check('office followers page beyond 100 safely; repeated jobs do not reset read state or duplicate',async()=>{
  await db.doc('offices/o').set({ownerId:'sender',isVerified:true,status:'active'});await db.doc('properties/office-p').set({publisherUid:'sender',officeId:'o',status:'approved',title:'Source title'});
  const batch=db.batch();for(let i=0;i<101;i++){const uid='follower-'+String(i).padStart(3,'0');batch.set(db.doc('users/'+uid),{isBlocked:false});batch.set(db.doc('office_followers/'+uid),{userId:uid,officeId:'o',isActive:true});}await batch.commit();
  await h.propertyApproved({authId:'sender',authType:'api_key',params:{propertyId:'office-p'},data:{before:{exists:false},after:source((await db.doc('properties/office-p').get()).data())}},db);
  const job=(await db.collection('trusted_notification_jobs').where('kind','==','office').get()).docs[0];assert.ok(job);
  const event={params:{jobId:job.id}};await h.fanoutJob(event,db);assert.equal((await job.ref.get()).data().status,'pending');await h.fanoutJob(event,db);await h.fanoutJob(event,db);
  assert.equal((await job.ref.get()).data().status,'complete');const rows=await db.collection('trusted_notifications').where('officeId','==','o').get();assert.equal(rows.size,101);assert.equal(new Set(rows.docs.map(d=>d.data().userId)).size,101);assert.ok(rows.docs.every(d=>d.data().title==='عقار جديد من المكتب الذي تتابعه'));
  assert.equal((await db.collection('notifications').where('officeId','==','o').get()).size,101);
 });
 await check('new source reply and chat plus administrator broadcast share verified projection and unique recipient identities',async()=>{
  await db.doc('properties/new-p').set({publisherUid:'owner',status:'approved'});await db.doc('properties/new-p/comments/new-c').set({userId:'sender',isHidden:false});await db.doc('properties/new-p/comments/new-c/replies/new-r').set({userId:'owner',isHidden:false});
  await bridge.bridgeReplyCreated.run({authId:'owner',authType:'api_key',params:{propertyId:'new-p',commentId:'new-c',replyId:'new-r'},data:source({userId:'owner',isHidden:false})});
  const reply=(await db.collection('trusted_notifications').where('replyId','==','new-r').get()).docs[0];assert.equal(reply.data().userId,'sender');
  await db.doc('chats/owner/messages/new-m').set({senderId:'owner',message:'verified chat source'});
  await bridge.bridgeChatMessageCreated.run({authId:'owner',authType:'api_key',params:{chatId:'owner',messageId:'new-m'},data:source({senderId:'owner',message:'verified chat source'})});
  const chat=(await db.collection('trusted_notifications').where('messageId','==','new-m').get()).docs[0];assert.equal(chat.data().userId,'admin');
  await h.requestCreated(request('admin','broadcast',{target:'all',type:'general',title:'Synthetic broadcast',message:'local only',deliveryType:'internal'}),db);
  const job=(await db.collection('trusted_notification_jobs').where('kind','==','admin').get()).docs[0];await h.fanoutJob({params:{jobId:job.id}},db);
  const audience=(await db.collection('users').get()).size,rows=await db.collection('trusted_notifications').where('title','==','Synthetic broadcast').get();assert.equal(rows.size,Math.min(100,audience));assert.equal(new Set(rows.docs.map(d=>d.id)).size,rows.size);
  assert.equal((await db.collection('notifications').where('title','==','Synthetic broadcast').get()).size,rows.size);
  assert.equal(providerCalls,0);assert.equal((await db.collection('push_deliveries').get()).size,0);
 });
 await check('pause and empty cohorts remain authoritative, with zero provider calls or delivery claims',async()=>{
  assert.equal(providerCalls,0);assert.equal((await db.collection('push_deliveries').get()).size,0);const rollout=(await db.doc('push_bridge_config/rollout').get()).data();assert.equal(rollout.mode,'paused');assert.deepEqual(rollout.cohort.userIds,[]);
 });
});
