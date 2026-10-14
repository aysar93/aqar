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
