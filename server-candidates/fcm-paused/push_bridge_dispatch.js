'use strict';
// Shared delivery core. Does not load callable/Auth wrappers in Vercel.
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {getMessaging}=require('firebase-admin/messaging');
const logger=require('firebase-functions/logger');
const {hash}=require('./push_policy');
const {planDevices,rolloutAllows,cohortAllows}=require('./push_bridge_policy');
const {deliverBridge}=require('./push_bridge_delivery');
async function dispatchBridge(push,db=getFirestore()) {
 const [recipient,settings,rolloutDoc,devices,installations]=await Promise.all([
  db.doc('users/'+push.userId).get(),db.doc('settings/app_settings').get(),db.doc('push_bridge_config/rollout').get(),
  db.collection('push_tokens').where('uid','==',push.userId).where('active','==',true).limit(101).get(),
  db.collection('push_installations').where('uid','==',push.userId).where('active','==',true).limit(101).get(),
 ]);
 if(!recipient.exists||recipient.data().isBlocked===true)return [];
 // Inbox persistence is independent of push preference, pause and cohort.
 const visible=await ensureVisibleInbox(push,db);
 if(!visible)return [];
 push=visible;
 if(recipient.data().notificationsEnabled===false||settings.data()?.allowNotifications===false)return [];
 if(rolloutDoc.data()?.legacyIngressCoordinated!==true){logger.warn('push_bridge_ingress_not_coordinated');return [];}
 if(devices.size>100||installations.size>100){logger.error('push_bridge_inventory_limit',{uidHash:hash(push.userId)});return [];}
 const legacyId=recipient.data().oneSignalId;
 const legacyBinding=typeof legacyId==='string'?(await db.doc('push_subscription_bindings/'+hash(legacyId)).get()).data():null;
 const legacyToken=recipient.data().fcmToken;
 const approval=typeof legacyToken==='string'?(await db.doc('push_legacy_token_approvals/'+hash(legacyToken)).get()).data():null;
 const targets=planDevices({uid:push.userId,devices:devices.docs.map(d=>({...d.data(),tokenHash:d.id,updatedAtMs:d.data().updatedAt?.toMillis()||0})),installations:installations.docs.map(d=>({...d.data(),id:d.id})),legacySubscriptionId:legacyId,legacyBinding,legacyFcmToken:legacyToken,legacyFcmApproval:approval,rollout:rolloutDoc.data()||{mode:'legacy'}});
 if(!targets.length)return [];
 const store={
  claim:async(id,e,t)=>db.runTransaction(async tx=>{
   const ref=db.doc('push_deliveries/'+id);
   // Preserve identity when an old profile subscription is learned as a
   // registered installation while an event is already being dispatched.
   const alias=t.oneSignalId?db.doc('push_deliveries/'+require('./push_bridge_policy').deliveryId(e,{key:'legacy:'+hash(t.oneSignalId)})):null;
   const [claim,user,global,rollout]=await Promise.all([tx.get(ref),tx.get(recipient.ref),tx.get(settings.ref),tx.get(rolloutDoc.ref)]);
   const aliasState=alias && alias.path!==ref.path?await tx.get(alias):null;
   let registration,token,binding,recoveryApproval;
   if(t.oneSignalId)binding=await tx.get(db.doc('push_subscription_bindings/'+hash(t.oneSignalId)));
   if(t.legacyFcmApprovalHash)recoveryApproval=await tx.get(db.doc('push_legacy_token_approvals/'+t.legacyFcmApprovalHash));
   if(t.installationId){registration=await tx.get(db.doc('push_installations/'+t.installationId));if(t.tokenHash)token=await tx.get(db.doc('push_tokens/'+t.tokenHash));}
   const visibleInbox=await tx.get(db.doc('notifications/'+e.notificationId));
   if(!visibleInbox.exists||visibleInbox.data().userId!==e.userId)return false;
   if(e.type==='chat_message') {
    const message=await tx.get(db.doc(`chats/${e.chatId}/messages/${e.messageId}`));
    const inbox=visibleInbox;
    if(!message.exists||message.data().deletedAt||message.data().isRead===true||message.data().status==='read'||inbox.exists && (inbox.data().unreadCount===0 || inbox.data().messageId && inbox.data().messageId!==e.messageId))return false;
   }
   if(claim.exists||aliasState?.exists||!user.exists||user.data().isBlocked===true||user.data().notificationsEnabled===false||global.data()?.allowNotifications===false||rollout.data()?.mode==='paused'||rollout.data()?.legacyIngressCoordinated!==true)return false;
   // A rollback or cohort reduction can race the initial device planning read.
   // Recheck the current rollout in the same transaction that claims delivery.
   if(!cohortAllows(e.userId,t,rollout.data()))return false;
   if(t.provider==='fcm' && t.installationId && !rolloutAllows(t.installationId,rollout.data()))return false;
   if(t.installationId && (!registration.exists||registration.data().active===false||registration.data().uid!==e.userId||registration.data().tokenHash!==t.tokenHash && t.provider==='fcm'))return false;
   if(t.provider==='fcm' && t.installationId && (!token?.data()?.active||token.data().uid!==e.userId||token.data().token!==t.endpoint))return false;
   if(t.legacyFcmApprovalHash && (user.data().fcmToken!==t.endpoint||rollout.data()?.legacyRecovery!=='fcm'||!rollout.data()?.legacyRecoveryAllowlist?.includes(e.userId)||recoveryApproval?.data()?.uid!==e.userId||recoveryApproval.data().active!==true||recoveryApproval.data().expiresAtMs<=Date.now()))return false;
   if(t.provider==='onesignal' && (t.installationId?registration.data().oneSignalId:user.data().oneSignalId)!==t.endpoint)return false;
   if(t.installationId && t.oneSignalId && (!binding?.exists||binding.data().uid!==e.userId||binding.data().installationId!==t.installationId||binding.data().active!==true))return false;
   if(!t.installationId && binding?.exists)return false;
   tx.create(ref,{status:'attempting',uid:e.userId,eventKey:e.key,notificationId:e.notificationId,targetKey:t.key,provider:t.provider,tokenHash:t.tokenHash||null,legacyFcmApprovalHash:t.legacyFcmApprovalHash||null,tokenUpdatedAt:token?.data()?.updatedAt||null,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
   if(alias && alias.path!==ref.path)tx.create(alias,{status:'alias',canonicalDeliveryId:id,createdAt:FieldValue.serverTimestamp()});
   return true;
  }),
  finish:async(id,values)=>{
   const ref=db.doc('push_deliveries/'+id);
   await db.runTransaction(async tx=>{
    const state=(await tx.get(ref)).data();
    const tokenRef=values.status==='invalid_token' && state?.tokenHash?db.doc('push_tokens/'+state.tokenHash):null;
    const device=tokenRef?(await tx.get(tokenRef)).data():null;
    const approvalRef=values.status==='invalid_token' && state?.legacyFcmApprovalHash?db.doc('push_legacy_token_approvals/'+state.legacyFcmApprovalHash):null;
    const approval=approvalRef?(await tx.get(approvalRef)).data():null;
    tx.update(ref,{...values,updatedAt:FieldValue.serverTimestamp()});
    if(tokenRef && device?.uid===state.uid && device.updatedAt?.isEqual(state.tokenUpdatedAt))tx.update(tokenRef,{active:false});
    if(approvalRef && approval?.uid===state.uid)tx.update(approvalRef,{active:false});
   });
   if(values.status==='review_required')logger.error('push_delivery_review_required',{deliveryId:id,errorCode:values.errorCode});
  },
 };
 const emulator=process.env.FUNCTIONS_EMULATOR==='true';
 const provider=require('./push_onesignal');
 return deliverBridge({event:push,targets,store,appId:emulator?'emulator-app':process.env.BRIDGE_ONESIGNAL_APP_ID,
  sendFcm:emulator?async()=>`emulator-mock:${push.key}`:m=>getMessaging().send(m),
  sendOneSignal:emulator?async()=>({id:`emulator-onesignal:${push.key}`}):provider.sendOneSignal});
}
// A canonical event has one visible inbox item, including source-only events.
// Prefer an existing verified client item. If a source raced it, fold the later
// verified duplicate into the chosen item without replacing recipient content.
async function ensureVisibleInbox(push,db) {
 const {canonicalEvent}=require('./push_bridge_policy');
 const eventRef=db.doc('push_bridge_events/'+push.key);
 return db.runTransaction(async tx=>{
  const state=await tx.get(eventRef),originalRef=db.doc('notifications/'+push.notificationId);
  const original=await tx.get(originalRef);
  const selected=state.data()?.visibleNotificationId || (original.exists?push.notificationId:'bridge_'+push.key);
  const ref=db.doc('notifications/'+selected);
  const visible=ref.path===originalRef.path?original:await tx.get(ref);
  // Never revive an item the recipient has already removed.
  if(state.data()?.visibleNotificationId && !visible.exists)return null;
  if(original.exists && (original.data().userId!==push.userId ||
      canonicalEvent(original.data(),null,push.notificationId)?.key!==push.key))return null;
  if(visible.exists && visible.data().userId!==push.userId)return null;
  if(!visible.exists){
   const item={notificationId:selected,userId:push.userId,type:push.type,title:String(push.title||'عقارات الأنبار').slice(0,120),
    message:String(push.message||push.body||'').slice(0,500),target:'user',deliveryType:'internal',
    bridgeEventKey:push.key,readBy:[],createdAt:FieldValue.serverTimestamp()};
   for(const field of ['propertyId','officeId','chatId','messageId','commentId','replyId','requestId','subscriptionId','unreadCount'])
    if(push[field]!==undefined)item[field]=push[field];
   tx.create(ref,item);
  }
  if(original.exists && ref.path!==originalRef.path){
   // This item is a verified duplicate for this event and recipient only.
   const reads=value=>Array.isArray(value)?value:[];
   const readBy=[...new Set([...reads(visible.data()?.readBy),...reads(original.data().readBy)])];
   const readState={...(readBy.length?{readBy}:{}),...(original.data().isRead===true?{isRead:true}:{}),
    ...(original.data().unreadCount===0?{unreadCount:0}:{})};
   if(Object.keys(readState).length)tx.update(ref,readState);
   tx.delete(originalRef);
  }
  tx.set(eventRef,{visibleNotificationId:selected},{merge:true});
  return {...push,notificationId:selected};
 });
}
module.exports={dispatchBridge,ensureVisibleInbox};
