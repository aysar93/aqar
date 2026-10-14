'use strict';
const {hash, validId, pushEvent, messageFor} = require('./push_policy');
const subscriptionId = value => typeof value === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value);
function canonicalEvent(after, before, id) {
  // The transport is a recipient decision. Never accept an event identity
  // supplied by an HTTP caller or an inbox document's eventId/key fields.
  return pushEvent(after && {...after, pushTransport:'fcm_v1'}, before, id);
}
function rolloutAllows(installationId, rollout = {}) {
  if (rollout.mode !== 'fcm') return false;
  if (rollout.installationAllowlist?.includes(installationId)) return true;
  const percent = Math.max(0, Math.min(100, Number(rollout.percent) || 0));
  return parseInt(hash(installationId).slice(0, 8), 16) / 0x100000000 * 100 < percent;
}
function planDevices({uid, devices, installations, legacySubscriptionId, legacyBinding, legacyFcmToken, legacyFcmApproval, rollout={}, now=Date.now()}) {
  if (rollout.mode === 'paused') return [];
  const plans=[], knownSubscriptions=new Set(), seen=new Set();
  for(const installation of installations) {
    if(subscriptionId(installation.oneSignalId)) knownSubscriptions.add(installation.oneSignalId);
    if(installation.uid!==uid || installation.active===false) continue;
    const device=devices.find(d=>d.installationId===installation.id && d.uid===uid && d.active && d.tokenHash===installation.tokenHash && d.updatedAtMs>=now-60*86400000);
    const os=subscriptionId(installation.oneSignalId)?installation.oneSignalId:null;
    const fcm=!!device?.token;
    // Retain OneSignal as fallback, including a server-side rollback. An
    // FCM-only installation is allowed only by explicit rollout selection.
    const provider=fcm && rolloutAllows(installation.id,rollout)?'fcm':os?'onesignal':null;
    if(!provider)continue;
    const endpoint=provider==='fcm'?device.token:os;
    if(seen.has(provider+':'+endpoint))continue;
    seen.add(provider+':'+endpoint);
    plans.push({key:'installation:'+installation.id,installationId:installation.id,uid,provider,endpoint,tokenHash:device?.tokenHash||null,oneSignalId:os});
  }
  // Existing releases save a single OneSignal subscription in their profile.
  // Preserve it, unless already associated with an installation (including an
  // inactive/account-detached tombstone). Do not infer an entire user's devices.
  const recovery=rollout.legacyRecovery==='fcm' && rollout.legacyRecoveryAllowlist?.includes(uid) &&
    typeof legacyFcmToken==='string' && legacyFcmToken.length>=20 &&
    legacyFcmApproval?.uid===uid && legacyFcmApproval.active===true && legacyFcmApproval.tokenHash===hash(legacyFcmToken) && legacyFcmApproval.expiresAtMs>now;
  if(!legacyBinding && !knownSubscriptions.has(legacySubscriptionId)) {
    const key=subscriptionId(legacySubscriptionId)?'legacy:'+hash(legacySubscriptionId):'legacy-fcm:'+hash(String(legacyFcmToken));
    if(recovery)plans.push({key,uid,provider:'fcm',endpoint:legacyFcmToken,legacyFcmApprovalHash:hash(legacyFcmToken),oneSignalId:subscriptionId(legacySubscriptionId)?legacySubscriptionId:null});
    else if(subscriptionId(legacySubscriptionId))plans.push({key,uid,provider:'onesignal',endpoint:legacySubscriptionId,oneSignalId:legacySubscriptionId});
  }
  return plans;
}
function deliveryId(event, target) { return hash(JSON.stringify([event.key,target.key])); }
function uuidFor(value) { const h=hash(value);return `${h.slice(0,8)}-${h.slice(8,12)}-4${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`; }
function oneSignalMessage(event,target,appId) {
  const fcm=messageFor(event,'unused');
  return {app_id:appId,include_subscription_ids:[target.endpoint],headings:{en:fcm.notification.title},contents:{en:fcm.notification.body},data:{...fcm.data,eventId:event.key},idempotency_key:uuidFor(deliveryId(event,target)),...(event.type==='chat_message'?{collapse_id:'chat_'+event.chatId}:{})};
}
module.exports={subscriptionId,canonicalEvent,rolloutAllows,planDevices,deliveryId,oneSignalMessage};
