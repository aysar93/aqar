const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { hash, pushEvent, messageFor, permanentErrors } = require('./push_policy');
const {subscriptionId} = require('./push_bridge_policy');

// Default off. Configure only on a test project until device acceptance.
const enabled = () => process.env.FCM_MIGRATION_ENABLED === 'true';
function requestDevice(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'سجّل الدخول أولاً');
  if (!enabled()) throw new HttpsError('failed-precondition', 'انتقال الإشعارات غير مفعّل');
  const id = request.data?.installationId;
  if (typeof id !== 'string' || !/^[a-f0-9]{32}$/.test(id)) throw new HttpsError('invalid-argument', 'معرّف الجهاز غير صالح');
  return { uid: request.auth.uid, id };
}

exports.registerPushDevice = onCall(require('./push_onesignal').providerSecretOptions(), async request => {
  const { uid, id } = requestDevice(request);
  const { token, platform, oneSignalId, revokeSecret, providerToken, generation=0 } = request.data || {};
  if (typeof token !== 'string' || token.length < 20 || token.length > 4096 || !['android', 'iOS', 'web'].includes(platform)) throw new HttpsError('invalid-argument', 'رمز الجهاز غير صالح');
  if (oneSignalId !== undefined && !subscriptionId(oneSignalId)) throw new HttpsError('invalid-argument', 'معرّف OneSignal غير صالح');
  if (revokeSecret !== undefined && !/^[a-f0-9]{64}$/.test(revokeSecret)) throw new HttpsError('invalid-argument', 'صلاحية الإلغاء غير صالحة');
  if(!Number.isSafeInteger(generation)||generation<0)throw new HttpsError('invalid-argument','جيل التسجيل غير صالح');
  const db = getFirestore();
  const user = await db.doc(`users/${uid}`).get();
  if (!user.exists || user.data().isBlocked === true) throw new HttpsError('permission-denied', 'الحساب غير متاح');
  const tokenHash = hash(token);
  if (oneSignalId) {
    // Never accept another user's public legacy subscription ID as proof of
    // device ownership. Verify the provider's secret transport token as well.
    const rateRef=db.doc(`push_registration_limits/${uid}`);
    await db.runTransaction(async tx=>{
      const v=(await tx.get(rateRef)).data()||{};const now=Date.now();const within=now-Number(v.providerWindow||0)<15*60000;const n=within?Number(v.providerAttempts||0)+1:1;
      if(n>30)throw new HttpsError('resource-exhausted','محاولات تسجيل كثيرة');
      tx.set(rateRef,{...v,providerWindow:within?v.providerWindow:now,providerAttempts:n});
    });
    try { await require('./push_onesignal').verifySubscriptionBinding({oneSignalId,token,platform,providerToken}); }
    catch (_) { throw new HttpsError('failed-precondition','تعذر التحقق من اشتراك OneSignal؛ أعد المحاولة'); }
  }
  const installation = db.doc(`push_installations/${id}`);
  await db.runTransaction(async tx => {
    const previous = (await tx.get(installation)).data();
    const sameOwner = previous?.uid === uid;
    if(generation<Number(previous?.generation||0))throw new HttpsError('failed-precondition','تسجيل جهاز قديم؛ أعد المحاولة');
    if (revokeSecret && (previous?.revokedHashes || []).includes(hash(revokeSecret))) throw new HttpsError('failed-precondition', 'انتهت صلاحية تسجيل هذا الجهاز');
    const limitsRef = db.doc(`push_registration_limits/${uid}`);
    const limits = (await tx.get(limitsRef)).data() || {};
    const previousLimitsRef = previous?.uid && previous.uid !== uid ? db.doc(`push_registration_limits/${previous.uid}`) : null;
    const previousLimits = previousLimitsRef ? (await tx.get(previousLimitsRef)).data() || {} : null;
    const owned = new Set(limits.installations || []);
    if (!owned.has(id) && owned.size >= 10) throw new HttpsError('resource-exhausted', 'الحد الأقصى عشرة أجهزة؛ سجّل الخروج من جهاز قديم');
    const now = Date.now();
    const withinWindow = now - Number(limits.windowStartedAt || 0) < 15 * 60000;
    const attempts = withinWindow ? Number(limits.attempts || 0) + 1 : 1;
    if (attempts > 30) throw new HttpsError('resource-exhausted', 'محاولات تسجيل كثيرة؛ أعد المحاولة لاحقًا');
    let old;
    if (previous?.tokenHash && previous.tokenHash !== tokenHash) old = await tx.get(db.doc(`push_tokens/${previous.tokenHash}`));
    const previousBindingRef=previous?.oneSignalId?db.doc(`push_subscription_bindings/${hash(previous.oneSignalId)}`):null;
    const previousBinding=previousBindingRef?(await tx.get(previousBindingRef)).data():null;
    if (old?.exists && old.data().installationId === id) tx.update(old.ref, { active: false, updatedAt: FieldValue.serverTimestamp() });
    owned.add(id);
    tx.set(limitsRef, {...limits, installations:[...owned], attempts, windowStartedAt:withinWindow?limits.windowStartedAt:now});
    if (previousLimitsRef) tx.set(previousLimitsRef, {...previousLimits, installations:(previousLimits.installations || []).filter(value=>value!==id)});
    if(previousBindingRef && previousBinding?.installationId===id && previous.oneSignalId!==oneSignalId && (!sameOwner || oneSignalId))tx.set(previousBindingRef,{...previousBinding,active:false,updatedAt:FieldValue.serverTimestamp()});
    tx.set(db.doc(`push_tokens/${tokenHash}`), { uid, token, installationId: id, platform, active: true, updatedAt: FieldValue.serverTimestamp() });
    tx.set(installation, { uid, tokenHash, active:true, platform,generation,
      ...(oneSignalId?{oneSignalId}:sameOwner && previous.oneSignalId?{oneSignalId:previous.oneSignalId}:{}),
      ...(revokeSecret?{revokeHash:hash(revokeSecret)}:sameOwner && previous.revokeHash?{revokeHash:previous.revokeHash}:{}),
      revokedHashes:previous?.revokedHashes || [],
      updatedAt: FieldValue.serverTimestamp() });
    if(oneSignalId)tx.set(db.doc(`push_subscription_bindings/${hash(oneSignalId)}`),{uid,installationId:id,active:true,updatedAt:FieldValue.serverTimestamp()});
  });
  return { registered: true };
});

exports.unregisterPushDevice = onCall(async request => {
  // A bounded, random, installation-scoped revocation capability lets a
  // durable offline logout finish after Firebase Auth has signed out. It can
  // only disable this registration, never read tokens or register another UID.
  if (!enabled()) throw new HttpsError('failed-precondition', 'انتقال الإشعارات غير مفعّل');
  const id = request.data?.installationId;
  if (typeof id !== 'string' || !/^[a-f0-9]{32}$/.test(id)) throw new HttpsError('invalid-argument', 'معرّف الجهاز غير صالح');
  const secret = request.data?.revokeSecret;
  if (!request.auth?.uid && !(typeof secret==='string' && /^[a-f0-9]{64}$/.test(secret))) throw new HttpsError('unauthenticated', 'سجّل الدخول أولاً');
  const db = getFirestore();
  const detached = await db.runTransaction(async tx => {
    const installation = await tx.get(db.doc(`push_installations/${id}`));
    const data = installation.data();
    if (!installation.exists && typeof secret==='string' && /^[a-f0-9]{64}$/.test(secret)) {
      // Never let an anonymous caller create arbitrary installation documents.
      // An unknown capability is retried by the client if an earlier register
      // request is still in flight.
      if(!request.auth?.uid)return false;
      const profile=await tx.get(db.doc('users/'+request.auth.uid));
      if(!profile.exists||profile.data().isBlocked===true)return false;
      const rateRef=db.doc('push_registration_limits/'+request.auth.uid);
      const rate=(await tx.get(rateRef)).data()||{};const now=Date.now();
      const within=now-Number(rate.revokeWindow||0)<15*60000;
      const attempts=within?Number(rate.revokeAttempts||0)+1:1;
      if(attempts>30)throw new HttpsError('resource-exhausted','محاولات كثيرة');
      tx.set(rateRef,{...rate,revokeWindow:within?rate.revokeWindow:now,revokeAttempts:attempts});
      const generation=Number.isSafeInteger(request.data?.generation)?Math.max(0,request.data.generation):0;
      tx.set(installation.ref,{active:false,uid:request.auth?.uid||null,generation,revokedHashes:[hash(secret)],updatedAt:FieldValue.serverTimestamp()});
      return true;
    }
    const capability = typeof secret==='string' && /^[a-f0-9]{64}$/.test(secret) && data?.revokeHash===hash(secret);
    if (!data?.tokenHash || (secret !== undefined ? !capability : data.uid !== request.auth?.uid)) return true;
    const uid=data.uid;
    const token = await tx.get(db.doc(`push_tokens/${data.tokenHash}`));
    const limitsRef=db.doc(`push_registration_limits/${uid}`);
    const limits=(await tx.get(limitsRef)).data() || {};
    const bindingRef=data.oneSignalId?db.doc(`push_subscription_bindings/${hash(data.oneSignalId)}`):null;
    const binding=bindingRef?(await tx.get(bindingRef)).data():null;
    if (token.exists && token.data().uid === uid && token.data().installationId === id) tx.update(token.ref, { active: false, updatedAt: FieldValue.serverTimestamp() });
    const generation=Number.isSafeInteger(request.data?.generation)?Math.max(data.generation||0,request.data.generation):data.generation||0;
    tx.update(installation.ref,{active:false,generation,revokedHashes:[...new Set([...(data.revokedHashes||[]),...(data.revokeHash?[data.revokeHash]:[])])].slice(-256),updatedAt:FieldValue.serverTimestamp()});
    tx.set(limitsRef,{...limits,installations:(limits.installations||[]).filter(value=>value!==id)});
    if(bindingRef && binding?.installationId===id && binding.uid===uid)tx.set(bindingRef,{...binding,active:false,updatedAt:FieldValue.serverTimestamp()});
    return true;
  });
  return { detached };
});

exports.deliverFcmNotification = onDocumentWritten({ document: 'notifications/{notificationId}', retry: true }, async event => {
  if (process.env.PUSH_BRIDGE_ENABLED === 'true') return;
  if (!enabled()) return;
  const after = event.data?.after.exists ? event.data.after.data() : null;
  const before = event.data?.before.exists ? event.data.before.data() : null;
  const push = pushEvent(after, before, event.params.notificationId);
  if (!push) return;
  const db = getFirestore();
  const userRef = db.doc(`users/${push.userId}`);
  const settingsRef = db.doc('settings/app_settings');
  const devices = await db.collection('push_tokens').where('uid', '==', push.userId).get();
  for (const device of devices.docs) {
    const stateRef = db.doc(`push_deliveries/${hash(`${push.key}:${device.id}`)}`);
    // Claim before contacting FCM. An ambiguous result is never automatically
    // resent: FCM offers no atomic transaction with Firestore/exactly-once send.
    const claimed = await db.runTransaction(async tx => {
      const [state, latestDevice, user, inbox, settings] = await Promise.all([tx.get(stateRef), tx.get(device.ref), tx.get(userRef), tx.get(event.data.after.ref), tx.get(settingsRef)]);
      const current = latestDevice.data();
      if (state.exists || !inbox.exists || settings.data()?.allowNotifications === false || !user.exists || user.data().notificationsEnabled === false || user.data().isBlocked === true || !current?.active || current.uid !== push.userId || !current.updatedAt || Date.now() - current.updatedAt.toMillis() > 60 * 86400000) return null;
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
