const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { hash, pushEvent, messageFor, permanentErrors } = require('./push_policy');

// Default off. Configure only on a test project until device acceptance.
const enabled = () => process.env.FCM_MIGRATION_ENABLED === 'true';
function requestDevice(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'سجّل الدخول أولاً');
  if (!enabled()) throw new HttpsError('failed-precondition', 'انتقال الإشعارات غير مفعّل');
  const id = request.data?.installationId;
  if (typeof id !== 'string' || !/^[a-f0-9]{32}$/.test(id)) throw new HttpsError('invalid-argument', 'معرّف الجهاز غير صالح');
  return { uid: request.auth.uid, id };
}

exports.registerPushDevice = onCall(async request => {
  const { uid, id } = requestDevice(request);
  const { token, platform } = request.data || {};
  if (typeof token !== 'string' || token.length < 20 || token.length > 4096 || !['android', 'iOS', 'web'].includes(platform)) throw new HttpsError('invalid-argument', 'رمز الجهاز غير صالح');
  const db = getFirestore();
  const user = await db.doc(`users/${uid}`).get();
  if (!user.exists || user.data().isBlocked === true) throw new HttpsError('permission-denied', 'الحساب غير متاح');
  const tokenHash = hash(token);
  const installation = db.doc(`push_installations/${id}`);
  await db.runTransaction(async tx => {
    const previous = (await tx.get(installation)).data();
    let old;
    if (previous?.tokenHash && previous.tokenHash !== tokenHash) old = await tx.get(db.doc(`push_tokens/${previous.tokenHash}`));
    if (old?.exists && old.data().installationId === id) tx.update(old.ref, { active: false, updatedAt: FieldValue.serverTimestamp() });
    tx.set(db.doc(`push_tokens/${tokenHash}`), { uid, token, installationId: id, platform, active: true, updatedAt: FieldValue.serverTimestamp() });
    tx.set(installation, { uid, tokenHash, updatedAt: FieldValue.serverTimestamp() });
  });
  return { registered: true };
});

exports.unregisterPushDevice = onCall(async request => {
  const { uid, id } = requestDevice(request);
  const db = getFirestore();
  await db.runTransaction(async tx => {
    const installation = await tx.get(db.doc(`push_installations/${id}`));
    const data = installation.data();
    if (data?.uid !== uid || !data.tokenHash) return;
    const token = await tx.get(db.doc(`push_tokens/${data.tokenHash}`));
    if (token.exists && token.data().uid === uid && token.data().installationId === id) tx.update(token.ref, { active: false, updatedAt: FieldValue.serverTimestamp() });
  });
  return { detached: true };
});

exports.deliverFcmNotification = onDocumentWritten({ document: 'notifications/{notificationId}', retry: true }, async event => {
  if (!enabled()) return;
  const after = event.data?.after.exists ? event.data.after.data() : null;
  const before = event.data?.before.exists ? event.data.before.data() : null;
  const push = pushEvent(after, before, event.params.notificationId);
  if (!push) return;
  const db = getFirestore();
  const userRef = db.doc(`users/${push.userId}`);
  const devices = await db.collection('push_tokens').where('uid', '==', push.userId).get();
  for (const device of devices.docs) {
    const stateRef = db.doc(`push_deliveries/${hash(`${push.key}:${device.id}`)}`);
    // Claim before contacting FCM. An ambiguous result is never automatically
    // resent: FCM offers no atomic transaction with Firestore/exactly-once send.
    const claimed = await db.runTransaction(async tx => {
      const [state, latestDevice, user, inbox] = await Promise.all([tx.get(stateRef), tx.get(device.ref), tx.get(userRef), tx.get(event.data.after.ref)]);
      const current = latestDevice.data();
      if (state.exists || !inbox.exists || !user.exists || user.data().notificationsEnabled === false || user.data().isBlocked === true || !current?.active || current.uid !== push.userId || !current.updatedAt || Date.now() - current.updatedAt.toMillis() > 60 * 86400000) return null;
      if (push.type === 'chat_message') {
        if (inbox.data().messageId !== push.messageId || inbox.data().unreadCount === 0) return null;
        const source = await tx.get(db.doc(`chats/${push.chatId}/messages/${push.messageId}`));
        if (!source.exists || source.data().deletedAt) return null;
      }
      tx.create(stateRef, { status: 'attempting', uid: push.userId, eventKey: push.key, notificationId: push.notificationId, tokenHash: device.id, createdAt: FieldValue.serverTimestamp() });
      return current;
    });
    if (!claimed) continue;
    try {
      // FCM has no emulator. Never make a network send from the Functions emulator.
      const messageId = process.env.FUNCTIONS_EMULATOR === 'true'
        ? `emulator-mock:${push.key}`
        : await getMessaging().send(messageFor(push, claimed.token));
      await stateRef.update({ status: 'accepted', messageId, updatedAt: FieldValue.serverTimestamp() });
    } catch (error) {
      // Record uncertainty; no blind retries and no deletion of token records.
      await stateRef.update({ status: permanentErrors.has(error.code) ? 'invalid_token' : 'review_required', errorCode: String(error.code || 'unknown'), updatedAt: FieldValue.serverTimestamp() });
      if (permanentErrors.has(error.code)) await db.runTransaction(async tx => {
        const current = await tx.get(device.ref);
        if (current.data()?.uid === push.userId && current.data()?.installationId === claimed.installationId && current.data()?.updatedAt?.isEqual(claimed.updatedAt)) tx.update(device.ref, { active: false });
      });
    }
  }
});
