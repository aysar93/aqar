const { test, after } = require('node:test');
const assert = require('node:assert/strict');
if (process.env.GCLOUD_PROJECT !== 'demo-aqar' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185' || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') throw Error('DEMO_EMULATORS_REQUIRED');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const app = initializeApp({ projectId: 'demo-aqar' });
const db = getFirestore();
after(async () => { await db.terminate(); await deleteApp(app); });
const base = 'http://127.0.0.1:5001/demo-aqar/us-central1/';
async function call(name, data, token) {
  const response = await fetch(base + name, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify({ data }) });
  return { status: response.status, body: await response.json() };
}
test('HTTP callable authentication, Auth emulator identity, Firestore trigger and mocked delivery', async () => {
  assert.equal((await call('registerPushDevice', {})).status, 401);
  const auth = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ returnSecureToken: true }) });
  const { localId: uid, idToken } = await auth.json();
  assert.ok(uid); assert.ok(idToken);
  await db.doc(`users/${uid}`).set({ notificationsEnabled: true, isBlocked: false });
  const data = { installationId: 'c'.repeat(32), token: 'synthetic-emulator-token-'.repeat(3), platform: 'android' };
  assert.equal((await call('registerPushDevice', data, idToken)).body.result.registered, true);
  await db.doc('notifications/staging-http').set({ userId: uid, type: 'general', title: 'test', message: 'test', pushTransport: 'fcm_v1' });
  let delivered;
  for (let i = 0; i < 100; i++) {
    delivered = (await db.collection('push_deliveries').where('uid', '==', uid).get()).docs.find(d => d.data().status === 'accepted');
    if (delivered) break;
    await new Promise(r => setTimeout(r, 200));
  }
  assert.ok(delivered, 'Firestore event must invoke the actual emulated Function');
  assert.match(delivered.data().messageId, /^emulator-mock:/);
  assert.equal((await call('unregisterPushDevice', data, idToken)).body.result.detached, true);
});
