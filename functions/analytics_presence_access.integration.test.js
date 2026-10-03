// This file deliberately refuses to run without BOTH isolated local emulators.
const test = require('node:test');
const assert = require('node:assert/strict');
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185' ||
    process.env.FIREBASE_DATABASE_EMULATOR_HOST !== '127.0.0.1:9195') {
  throw new Error('Local demo-aqar Firestore + RTDB emulators required');
}
const { initializeApp: initializeAdmin, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getDatabase: adminDatabase } = require('firebase-admin/database');

initializeAdmin({ projectId: 'demo-aqar', databaseURL: 'https://demo-aqar-default-rtdb.firebaseio.com' });
const firestore = getFirestore();
const admin = adminDatabase();
const { authorizePresenceDashboard, syncPresenceAdminRole, syncPresenceAdminForTest } = require('./analytics_presence_access');
const apps = [];
function client(uid, provider = 'password') {
  // Admin SDK's documented limited-privilege override uses real RTDB rules,
  // including actual transport disconnects, without another npm dependency.
  const app = initializeAdmin({ projectId: 'demo-aqar',
    databaseURL: 'https://demo-aqar-default-rtdb.firebaseio.com',
    databaseAuthVariableOverride: uid == null ? null : {
      uid, token: { firebase: { sign_in_provider: provider } },
    },
  }, `${uid}-${apps.length}`);
  apps.push(app);
  return adminDatabase(app);
}
const ref = (db, path) => db.ref(path);
const set = (reference, value) => reference.set(value);
const get = reference => reference.get();
const remove = reference => reference.remove();
const onDisconnect = reference => reference.onDisconnect();
const goOffline = db => db.goOffline();
const goOnline = db => db.goOnline();
const serverTimestamp = () => ({ '.sv': 'timestamp' });
const onlineQuery = db => ref(db, 'presence').orderByChild('connections').startAt(true);
function onValue(reference, callback, onError) {
  reference.on('value', callback, onError);
  return () => reference.off('value', callback);
}
function waitFor(db, path, predicate) {
  return new Promise((resolve, reject) => {
    let unsubscribe;
    const timer = setTimeout(() => { unsubscribe?.(); reject(new Error(`Timed out: ${path}`)); }, 8000);
    unsubscribe = onValue(ref(db, path), snapshot => {
      if (predicate(snapshot.val())) {
        clearTimeout(timer); unsubscribe?.(); resolve(snapshot.val());
      }
    }, error => { clearTimeout(timer); unsubscribe?.(); reject(error); });
  });
}

test.after(async () => {
  for (const app of apps) await deleteApp(app);
  await firestore.terminate();
  goOffline(admin);
});

test('RTDB least privilege and server-only admin bootstrap/revocation', async () => {
  const normal = client('normal');
  const viewer = client('viewer');
  const guest = client(null);
  await firestore.doc('users/normal').set({ isAdmin: false });
  await firestore.doc('users/viewer').set({ isAdmin: true });
  const request = uid => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });
  await assert.rejects(authorizePresenceDashboard.run(request('normal')),
    error => error.code === 'permission-denied');
  await assert.rejects(authorizePresenceDashboard.run({}), error => error.code === 'unauthenticated');
  await authorizePresenceDashboard.run(request('viewer'));
  const acl = (await admin.ref('admins/viewer').get()).val();
  assert.equal(acl.presenceDashboard, true);
  assert.equal(acl.version, 1);
  assert.ok(Number.isSafeInteger(acl.checkedAt));
  const legacy = client('legacy-admin');
  await admin.ref('admins/legacy-admin').set(true);
  await assert.rejects(get(onlineQuery(legacy))); // Unverified old ACL is not authority.
  await admin.ref('admins/ordinary-sentinel').set({ doNotTouch: true });
  await syncPresenceAdminRole.run({ params: { uid: 'ordinary-sentinel' }, data: {
    before: { data: () => undefined }, after: { data: () => ({ isAdmin: false }) },
  } });
  assert.deepEqual((await admin.ref('admins/ordinary-sentinel').get()).val(), { doNotTouch: true });
  await admin.ref('admins/admin-profile-sentinel').set({ doNotTouch: true });
  await syncPresenceAdminRole.run({ params: { uid: 'admin-profile-sentinel' }, data: {
    before: { data: () => ({ isAdmin: true, name: 'Before' }) },
    after: { data: () => ({ isAdmin: true, isBlocked: false, name: 'After', lastLogin: 123 }) },
  } });
  assert.deepEqual((await admin.ref('admins/admin-profile-sentinel').get()).val(), { doNotTouch: true });
  // Existing clients can still write their legacy node before adopting
  // connections, but cannot replace a node containing newer connections.
  await set(ref(normal, 'presence/normal'), { online: true, lastSeen: serverTimestamp() });
  await set(ref(normal, 'presence/normal/connections/device'), serverTimestamp());
  await admin.ref('presence/legacy-offline').set({ online: true, lastSeen: 123 });
  await get(ref(normal, 'presence/normal/connections/device'));
  await assert.rejects(get(ref(normal, 'presence')));
  await assert.rejects(get(ref(guest, 'presence')));
  await assert.rejects(get(onlineQuery(normal)));
  await assert.rejects(get(onlineQuery(guest)));
  await assert.rejects(set(ref(normal, 'admins/normal'), true));
  await assert.rejects(set(ref(normal, 'admins/normal'), { presenceDashboard: true, version: 1 }));
  await assert.rejects(set(ref(normal, 'admins/viewer/presenceDashboard'), false));
  await assert.rejects(remove(ref(normal, 'admins/viewer')));
  await assert.rejects(get(ref(normal, 'presence/viewer/connections/device')));
  await assert.rejects(set(ref(normal, 'presence/viewer/connections/spoof'), serverTimestamp()));
  await assert.rejects(onDisconnect(ref(normal, 'presence/viewer/connections/spoof')).remove());
  await assert.rejects(set(ref(normal, `presence/normal/connections/${'x'.repeat(65)}`), serverTimestamp()));
  await assert.rejects(set(ref(normal, 'presence/normal/connections/nested/child'), serverTimestamp()));
  await assert.rejects(set(ref(guest, 'presence/guest/connections/device'), serverTimestamp()));
  await assert.rejects(set(ref(normal, 'presence/normal/connections/bad'), { profile: 'large' }));
  await assert.rejects(set(ref(normal, 'presence/normal'), { online: false }));
  await assert.rejects(get(ref(viewer, 'presence'))); // Admin must use the bounded-state query.
  const online = (await get(onlineQuery(viewer))).val();
  assert.ok(online.normal.connections.device);
  assert.equal(online['legacy-offline'], undefined);
  await assert.rejects(authorizePresenceDashboard.run({
    ...request('normal'), data: { uid: 'viewer', isAdmin: true },
  }), error => error.code === 'permission-denied');
  await firestore.doc('users/blocked-admin').set({ isAdmin: true, isBlocked: true });
  await assert.rejects(authorizePresenceDashboard.run(request('blocked-admin')),
    error => error.code === 'permission-denied');
  await firestore.doc('users/viewer').set({ isAdmin: false });
  await syncPresenceAdminRole.run({ params: { uid: 'viewer' }, data: {
    before: { data: () => ({ isAdmin: true }) }, after: { data: () => ({ isAdmin: false }) },
  } });
  assert.equal((await admin.ref('admins/viewer').get()).val().presenceDashboard, false);
  await assert.rejects(get(onlineQuery(viewer)));
  // A delayed promotion event must not restore a role already removed.
  await syncPresenceAdminRole.run({ params: { uid: 'viewer' }, data: {
    before: { data: () => ({ isAdmin: false }) }, after: { data: () => ({ isAdmin: true }) },
  } });
  assert.equal((await admin.ref('admins/viewer').get()).val().presenceDashboard, false);
});

test('rollback bridge grants legacy query only to a verified server ACL',
  { skip: process.env.ANALYTICS_ADMIN_BRIDGE !== '1' }, async () => {
  await firestore.doc('users/bridge-admin').set({ isAdmin: true });
  await authorizePresenceDashboard.run({ auth: { uid: 'bridge-admin',
    token: { firebase: { sign_in_provider: 'password' } } } });
  const legacyQuery = db => ref(db, 'presence').orderByChild('online').equalTo(true);
  await get(legacyQuery(client('bridge-admin')));
  await assert.rejects(get(legacyQuery(client('ordinary-bridge-user'))));
  await admin.ref('admins/old-boolean-admin').set(true);
  await assert.rejects(get(legacyQuery(client('old-boolean-admin'))));
});

test('a concurrent stale grant cannot overwrite an acknowledged revocation', async () => {
  await firestore.doc('users/racing-admin').set({ isAdmin: true });
  let release;
  let observed;
  const paused = new Promise(resolve => { release = resolve; });
  const read = new Promise(resolve => { observed = resolve; });
  const staleGrant = syncPresenceAdminForTest('racing-admin', async () => {
    observed();
    await paused;
  });
  await read;
  await firestore.doc('users/racing-admin').set({ isAdmin: false });
  await syncPresenceAdminForTest('racing-admin');
  release();
  await staleGrant;
  assert.equal((await admin.ref('admins/racing-admin').get()).val().presenceDashboard, false);
  await assert.rejects(get(onlineQuery(client('racing-admin'))));
});

test('duplicate role and deletion events do not rewrite ACL; deletion beats a stale grant', async () => {
  const doc = firestore.doc('users/replayed-admin');
  await doc.set({ isAdmin: false });
  const before = await doc.get();
  await doc.set({ isAdmin: true });
  const after = await doc.get();
  const promotion = { params: { uid: 'replayed-admin' }, data: { before, after } };
  await syncPresenceAdminRole.run(promotion);
  const granted = (await admin.ref('admins/replayed-admin').get()).val();
  await syncPresenceAdminRole.run(promotion);
  assert.deepEqual((await admin.ref('admins/replayed-admin').get()).val(), granted);

  let release;
  let observed;
  const paused = new Promise(resolve => { release = resolve; });
  const read = new Promise(resolve => { observed = resolve; });
  const staleGrant = syncPresenceAdminForTest('replayed-admin', async () => {
    observed(); await paused;
  });
  await read;
  await doc.delete();
  const deletion = { params: { uid: 'replayed-admin' },
    data: { before: after, after: await doc.get() } };
  await syncPresenceAdminRole.run(deletion);
  const denied = (await admin.ref('admins/replayed-admin').get()).val();
  assert.equal(denied.presenceDashboard, false);
  assert.equal(denied.checkedAt, granted.checkedAt); // Denial wins equal revision.
  await syncPresenceAdminRole.run(deletion);
  assert.deepEqual((await admin.ref('admins/replayed-admin').get()).val(), denied);
  release(); await staleGrant;
  assert.deepEqual((await admin.ref('admins/replayed-admin').get()).val(), denied);
  await assert.rejects(get(onlineQuery(client('replayed-admin'))));
});

test('two devices share a UID; onDisconnect removes only its connection', async () => {
  const android = client('multi', 'google.com');
  const ios = client('multi', 'apple.com');
  await waitFor(android, '.info/connected', value => value === true);
  await waitFor(ios, '.info/connected', value => value === true);
  const first = ref(android, 'presence/multi/connections/android');
  const second = ref(ios, 'presence/multi/connections/ios');
  await onDisconnect(first).remove();
  await onDisconnect(second).remove();
  await set(first, serverTimestamp());
  await set(second, serverTimestamp());
  assert.equal(Object.keys((await admin.ref('presence/multi/connections').get()).val()).length, 2);
  goOffline(android);
  await waitFor(ios, 'presence/multi/connections/ios', value => typeof value === 'number');
  await new Promise(resolve => setTimeout(resolve, 200));
  const remaining = (await admin.ref('presence/multi/connections').get()).val();
  assert.deepEqual(Object.keys(remaining), ['ios']);
  // Normal logout removes explicitly before authentication ends.
  await ref(ios, 'presence/multi/connections').update({ ios: null });
  await onDisconnect(second).cancel();
  assert.equal((await admin.ref('presence/multi/connections').get()).val(), null);
  goOnline(android);
  await waitFor(android, '.info/connected', value => value === true);
  await onDisconnect(first).remove();
  await set(first, serverTimestamp());
  assert.ok((await admin.ref('presence/multi/connections/android').get()).val());
  await remove(first);
});

test('every provider has the same UID-owned connections on Android and iOS', async () => {
  for (const platform of ['android', 'ios']) {
    for (const provider of ['phone', 'password', 'google.com', 'apple.com', 'facebook.com']) {
      const uid = `${platform}-${provider.replaceAll('.', '-')}`;
      const db = client(uid, provider);
      const connection = ref(db, `presence/${uid}/connections/${platform}`);
      await onDisconnect(connection).remove();
      await set(connection, serverTimestamp());
      assert.equal(typeof (await get(connection)).val(), 'number');
      await remove(connection);
      await onDisconnect(connection).cancel();
    }
  }
  const anonymous = client('anonymous', 'anonymous');
  await assert.rejects(set(ref(anonymous, 'presence/anonymous/connections/device'), serverTimestamp()));
});
