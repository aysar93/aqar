const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
if (!['127.0.0.1:8185', 'localhost:8185'].includes(process.env.FIRESTORE_EMULATOR_HOST) || process.env.GCLOUD_PROJECT !== 'demo-aqar') throw Error('ISOLATED_DEMO_EMULATOR_REQUIRED');
// Replace the messaging module before loading handlers. Never contact FCM.
const sends = [];
let failure;
const load = Module._load;
Module._load = function(name, ...args) {
  if (name === 'firebase-admin/messaging') return { getMessaging: () => ({ send: async message => { sends.push(message); if (failure) throw failure; return 'mock-accepted'; } }) };
  return load.call(this, name, ...args);
};
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
initializeApp({ projectId: 'demo-aqar' });
const db = getFirestore();
const { registerPushDevice, unregisterPushDevice, deliverFcmNotification } = require('./push_functions');
Module._load = load;
const { hash } = require('./push_policy');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('../test/firestore/node_modules/@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc } = require('../test/firestore/node_modules/firebase/firestore');
let env;
before(async () => { env = await initializeTestEnvironment({ projectId: 'demo-aqar', firestore: { rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8') } }); });
after(async () => { await env.cleanup(); await db.terminate(); });
beforeEach(async () => {
  process.env.FCM_MIGRATION_ENABLED = 'true'; sends.length = 0; failure = null;
  await env.clearFirestore();
  for (const uid of ['owner', 'sender', 'admin']) await db.doc(`users/${uid}`).set({ isAdmin: uid === 'admin', isBlocked: false, notificationsEnabled: true });
  await db.doc('settings/app_settings').set({ adminUid: 'admin' });
});
const request = (uid = 'owner', id = 'a'.repeat(32), token = 'token-'.repeat(12)) => ({ auth: { uid }, data: { installationId: id, token, platform: 'android' } });
async function event(id = 'n', data = {}) {
  const ref = db.doc(`notifications/${id}`);
  await ref.set({ userId: 'owner', type: 'general', title: 'title', message: 'body', pushTransport: 'fcm_v1', ...data });
  return { params: { notificationId: id }, data: { before: { exists: false }, after: await ref.get() } };
}
test('device authentication, default-off and invalid arguments', async () => {
  await assert.rejects(registerPushDevice.run({ data: {} }), e => e.code === 'unauthenticated');
  await assert.rejects(registerPushDevice.run(request('owner', 'bad')), e => e.code === 'invalid-argument');
  process.env.FCM_MIGRATION_ENABLED = 'false';
  await assert.rejects(registerPushDevice.run(request()), e => e.code === 'failed-precondition');
  await deliverFcmNotification.run(await event()); assert.equal(sends.length, 0);
});
test('multiple devices, duplicate token ownership, rotation, logout and account switch', async () => {
  await registerPushDevice.run(request());
  await registerPushDevice.run(request('owner', 'b'.repeat(32), 'second-'.repeat(12)));
  await deliverFcmNotification.run(await event()); assert.equal(sends.length, 2);
  await registerPushDevice.run(request('owner', 'a'.repeat(32), 'rotated-'.repeat(12)));
  assert.equal((await db.doc(`push_tokens/${hash('token-'.repeat(12))}`).get()).data().active, false);
  await registerPushDevice.run(request('sender', 'a'.repeat(32), 'rotated-'.repeat(12)));
  await unregisterPushDevice.run(request('owner')); // previous owner cannot detach new owner
  assert.equal((await db.doc(`push_tokens/${hash('rotated-'.repeat(12))}`).get()).data().uid, 'sender');
  await unregisterPushDevice.run(request('sender'));
  assert.equal((await db.doc(`push_tokens/${hash('rotated-'.repeat(12))}`).get()).data().active, false);
});
test('disabled preferences, internal delivery, stale tokens and legacy are skipped', async () => {
  await registerPushDevice.run(request());
  await db.doc('users/owner').update({ notificationsEnabled: false });
  await deliverFcmNotification.run(await event('disabled')); assert.equal(sends.length, 0);
  await db.doc('users/owner').update({ notificationsEnabled: true });
  await deliverFcmNotification.run(await event('internal', { deliveryType: 'internal' }));
  await deliverFcmNotification.run(await event('legacy', { pushTransport: 'legacy' }));
  await db.doc(`push_tokens/${hash(request().data.token)}`).update({ updatedAt: Timestamp.fromMillis(0) });
  await deliverFcmNotification.run(await event('stale')); assert.equal(sends.length, 0);
});
test('offline logout revocation survives sign-out and cannot revoke a newer login generation', async () => {
  const r=request();r.data.revokeSecret='1'.repeat(64);
  await registerPushDevice.run(r);
  await unregisterPushDevice.run({data:{installationId:r.data.installationId,revokeSecret:r.data.revokeSecret}});
  assert.equal((await db.doc(`push_tokens/${hash(r.data.token)}`).get()).data().active,false);
  await assert.rejects(registerPushDevice.run(r),e=>e.code==='failed-precondition');
  await registerPushDevice.run({...r,data:{...r.data,revokeSecret:'2'.repeat(64)}});
  await unregisterPushDevice.run({auth:{uid:'owner'},data:{installationId:r.data.installationId,revokeSecret:r.data.revokeSecret}});
  assert.equal((await db.doc(`push_tokens/${hash(r.data.token)}`).get()).data().active,true);
});
test('revocation before a delayed registration prevents reactivation', async()=>{
  const r=request();r.data.revokeSecret='3'.repeat(64);
  await unregisterPushDevice.run({auth:{uid:'owner'},data:{installationId:r.data.installationId,revokeSecret:r.data.revokeSecret}});
  await assert.rejects(registerPushDevice.run(r),e=>e.code==='failed-precondition');
});
test('late registration from a previous account generation cannot replace a new owner',async()=>{
 const r=request();r.data.generation=2;r.data.revokeSecret='4'.repeat(64);
 await registerPushDevice.run(r);
 await registerPushDevice.run({...r,auth:{uid:'sender'},data:{...r.data,generation:3,revokeSecret:'5'.repeat(64)}});
 await assert.rejects(registerPushDevice.run(r),e=>e.code==='failed-precondition');
 assert.equal((await db.doc(`push_tokens/${hash(r.data.token)}`).get()).data().uid,'sender');
});
test('unknown anonymous revocation capability cannot create billable tombstones',async()=>{
 const id='9'.repeat(32);
 assert.equal((await unregisterPushDevice.run({data:{installationId:id,revokeSecret:'6'.repeat(64)}})).detached,false);
 assert.equal((await db.doc('push_installations/'+id).get()).exists,false);
});
test('registration limits bound device count and refresh attempts',async()=>{
  for(let i=0;i<10;i++)await registerPushDevice.run(request('owner',i.toString(16).padStart(32,'0'),'device-token-'.repeat(3)+i));
  await assert.rejects(registerPushDevice.run(request('owner','f'.repeat(32))),e=>e.code==='resource-exhausted');
  for(let i=10;i<30;i++)await registerPushDevice.run(request('owner','0'.repeat(32)));
  await assert.rejects(registerPushDevice.run(request('owner','0'.repeat(32))),e=>e.code==='resource-exhausted');
});
test('global notification setting prevents sends; re-enable permits new events', async () => {
  await registerPushDevice.run(request());
  await db.doc('settings/app_settings').update({ allowNotifications: false });
  await deliverFcmNotification.run(await event('global-disabled'));
  assert.equal(sends.length, 0);
  await db.doc('settings/app_settings').update({ allowNotifications: true });
  await deliverFcmNotification.run(await event('global-enabled'));
  assert.equal(sends.length, 1);
});
test('concurrent retries are claimed once; collapsed chat sends successive source messages', async () => {
  await registerPushDevice.run(request());
  for (const id of ['m1', 'm2']) await db.doc(`chats/c/messages/${id}`).set({ senderId: 'sender' });
  const first = await event('chat_c_owner', { type: 'chat_message', chatId: 'c', messageId: 'm1' });
  await Promise.all([deliverFcmNotification.run(first), deliverFcmNotification.run(first)]);
  assert.equal(sends.length, 1);
  const second = await event('chat_c_owner', { type: 'chat_message', chatId: 'c', messageId: 'm2' });
  second.data.before = first.data.after;
  await deliverFcmNotification.run(second); assert.equal(sends.length, 2);
  const read = { ...second, data: { before: second.data.after, after: second.data.after } };
  await deliverFcmNotification.run(read); assert.equal(sends.length, 2);
  await deliverFcmNotification.run(first); assert.equal(sends.length, 2);
});
test('invalid tokens are deactivated without deletion; ambiguous failures require review', async () => {
  await registerPushDevice.run(request());
  failure = { code: 'messaging/registration-token-not-registered' };
  await deliverFcmNotification.run(await event('invalid'));
  assert.equal((await db.doc(`push_tokens/${hash(request().data.token)}`).get()).data().active, false);
  await registerPushDevice.run(request()); failure = { code: 'messaging/internal-error' };
  const failed = await event('ambiguous');
  await deliverFcmNotification.run(failed); await deliverFcmNotification.run(failed);
  assert.equal(sends.length, 2);
  assert.ok((await db.collection('push_deliveries').get()).docs.some(d => d.data().status === 'review_required'));
});
test('rules reject forged senders and arbitrary pushes; accept verified comments/replies/admin', async () => {
  const sender = env.authenticatedContext('sender').firestore();
  const admin = env.authenticatedContext('admin').firestore();
  const base = { userId: 'owner', type: 'general', createdBy: 'sender', pushTransport: 'fcm_v1' };
  await assertFails(setDoc(doc(sender, 'notifications/forged'), { ...base, createdBy: 'admin' }));
  await assertFails(setDoc(doc(sender, 'notifications/arbitrary'), base));
  await assertSucceeds(setDoc(doc(admin, 'notifications/admin'), { ...base, createdBy: 'admin' }));
  await db.doc('properties/p').set({ publisherUid: 'owner' });
  await db.doc('properties/p/comments/c').set({ userId: 'sender' });
  const comment = { ...base, type: 'comment', propertyId: 'p', commentId: 'c' };
  await assertSucceeds(setDoc(doc(sender, 'notifications/comment'), comment));
  await assertFails(setDoc(doc(sender, 'notifications/wrongRecipient'), { ...comment, userId: 'admin' }));
  await db.doc('properties/p/comments/c/replies/r').set({ userId: 'owner' });
  const owner = env.authenticatedContext('owner').firestore();
  await assertSucceeds(setDoc(doc(owner, 'notifications/reply'), { ...base, userId: 'sender', createdBy: 'owner', type: 'reply', propertyId: 'p', commentId: 'c', replyId: 'r' }));
  await assertFails(updateDoc(doc(owner, 'notifications/comment'), { message: 'forged', messageId: 'm' }));
  await assertSucceeds(updateDoc(doc(owner, 'notifications/comment'), { readBy: ['owner'], unreadCount: 0 }));
  for (const collection of ['push_tokens', 'push_installations', 'push_deliveries']) {
    await assertFails(getDoc(doc(sender, `${collection}/secret`)));
    await assertFails(setDoc(doc(admin, `${collection}/secret`), { token: 'forged' }));
  }
});
test('rules allow source-backed chat create/update, reject message and recipient spoofing', async () => {
  const sender = env.authenticatedContext('sender').firestore();
  for (const messageId of ['m1', 'm2']) await db.doc(`chats/sender/messages/${messageId}`).set({ senderId: 'sender' });
  const notification = { pushTransport: 'fcm_v1', createdBy: 'sender', userId: 'admin', chatId: 'sender', type: 'chat_message', messageId: 'm1' };
  const ref = doc(sender, 'notifications/chat_sender_admin');
  await assertSucceeds(setDoc(ref, notification));
  await assertSucceeds(updateDoc(ref, { messageId: 'm2' }));
  await assertFails(updateDoc(ref, { messageId: 'missing' }));
  await assertFails(updateDoc(ref, { userId: 'owner' }));
  await assertFails(updateDoc(ref, { pushTransport: 'legacy' }));
  await db.doc('notifications/legacy_chat').set({ ...notification, pushTransport: 'legacy' });
  await assertSucceeds(setDoc(doc(sender, 'notifications/legacy_chat'), { ...notification, messageId: 'm2' }));
});
test('bridge validates write actor, routes mixed devices and shares transactional claims across ingress', async()=>{
 const {verifiedEvent,dispatchBridge}=require('./push_bridge_functions').internals;
 const previous=process.env.FUNCTIONS_EMULATOR;process.env.FUNCTIONS_EMULATOR='true';
 const os='12345678-1234-4234-a234-123456789abc',legacy='22345678-1234-4234-a234-123456789abc';
 await registerPushDevice.run(request());
 await db.doc('push_installations/'+'a'.repeat(32)).update({oneSignalId:os});
 await db.doc('push_subscription_bindings/'+hash(os)).set({uid:'owner',installationId:'a'.repeat(32),active:true});
 await db.doc('users/owner').update({oneSignalId:legacy});
 await db.doc('push_bridge_config/rollout').set({mode:'fcm',percent:100,legacyIngressCoordinated:true});
 const e=await event('bridge',{pushTransport:'legacy'});
 assert.equal(await verifiedEvent({...e,authId:'sender',authType:'unknown'},db),null);
 assert.equal(await verifiedEvent({...e,authId:'admin',authType:'unauthenticated'},db),null);
 const push=await verifiedEvent({...e,authId:'admin',authType:'unknown'},db);assert.ok(push);
 assert.ok(await verifiedEvent({...e,authId:'admin',authType:'api_key'},db));
 try{
  await Promise.all([dispatchBridge(push,db),dispatchBridge(push,db)]);
  let claims=(await db.collection('push_deliveries').get()).docs.filter(d=>d.data().status==='accepted');
  assert.equal(claims.length,2);assert.deepEqual(claims.map(d=>d.data().provider).sort(),['fcm','onesignal']);
  await db.doc('push_bridge_config/rollout').set({mode:'legacy',legacyIngressCoordinated:true});
  await dispatchBridge(push,db);
  claims=(await db.collection('push_deliveries').get()).docs.filter(d=>d.data().status==='accepted');assert.equal(claims.length,2);
 }finally{if(previous===undefined)delete process.env.FUNCTIONS_EMULATOR;else process.env.FUNCTIONS_EMULATOR=previous;}
});
test('protected bridge and rate-limit collections reject client read/write',async()=>{
 const sender=env.authenticatedContext('sender').firestore();
 for(const collection of ['push_registration_limits','push_ingress_limits','push_bridge_events','push_bridge_inbox','push_subscription_bindings','push_bridge_config','push_legacy_token_approvals']){
  await assertFails(getDoc(doc(sender,collection+'/x')));await assertFails(setDoc(doc(sender,collection+'/x'),{forged:true}));
 }
});
test('delivery monitor detects stale attempts and failed sends; non-admin cannot inspect it',async()=>{
 const bridge=require('./push_bridge_functions');
 await db.doc('push_deliveries/stale').set({status:'attempting',createdAt:Timestamp.fromMillis(Date.now()-180000)});
 await db.doc('push_deliveries/review').set({status:'review_required',createdAt:Timestamp.now()});
 const health=await bridge.internals.deliveryHealth(db);
 assert.equal(health.staleAttempting,1);assert.equal(health.reviewRequired,1);
 await assert.rejects(bridge.reviewPushDeliveryHealth.run({auth:{uid:'sender'}}),e=>e.code==='permission-denied');
});
test('legacy source trigger and modern inbox share a delivery even without old inbox source IDs',async()=>{
 const bridge=require('./push_bridge_functions'),previous=process.env.FUNCTIONS_EMULATOR,enabled=process.env.PUSH_BRIDGE_ENABLED;
 process.env.FUNCTIONS_EMULATOR='true';process.env.PUSH_BRIDGE_ENABLED='true';
 try{
  await registerPushDevice.run(request());
  await db.doc('push_bridge_config/rollout').set({mode:'fcm',percent:100,legacyIngressCoordinated:true});
  await db.doc('properties/p').set({publisherUid:'owner'});
  const source=db.doc('properties/p/comments/c');await source.set({userId:'sender',text:'source comment'});
  await bridge.bridgeCommentCreated.run({authId:'sender',authType:'api_key',params:{propertyId:'p',commentId:'c'},data:await source.get()});
  const modern=await event('modern-comment',{type:'comment',propertyId:'p',commentId:'c'});
  const canonical=await bridge.internals.verifiedEvent({...modern,authId:'sender',authType:'api_key'},db);
  await bridge.internals.dispatchBridge(canonical,db);
  assert.equal((await db.collection('push_deliveries').where('status','==','accepted').get()).size,1);
 }finally{if(previous===undefined)delete process.env.FUNCTIONS_EMULATOR;else process.env.FUNCTIONS_EMULATOR=previous;if(enabled===undefined)delete process.env.PUSH_BRIDGE_ENABLED;else process.env.PUSH_BRIDGE_ENABLED=enabled;}
});
