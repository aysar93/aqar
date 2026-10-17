'use strict';
const {onDocumentWrittenWithAuthContext,onDocumentCreatedWithAuthContext}=require('firebase-functions/v2/firestore');
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {onSchedule}=require('firebase-functions/v2/scheduler');
const {getFirestore,FieldValue,Timestamp}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
const logger=require('firebase-functions/logger');
const {hash,validId}=require('./push_policy');
const {canonicalEvent}=require('./push_bridge_policy');
const {dispatchBridge}=require('./push_bridge_dispatch');
const {providerSecretOptions}=require('./push_onesignal');
const bridgeEnabled=()=>process.env.PUSH_BRIDGE_ENABLED==='true' && process.env.FCM_MIGRATION_ENABLED==='true';

async function verifiedEvent(event,db) {
 const after=event.data?.after.exists?event.data.after.data():null;
 const before=event.data?.before.exists?event.data.before.data():null;
 if(!after||after.deliveryType==='internal'||!validId(after.userId)||after.userId==='all')return null;
 // Auth context belongs to the write, not a client-controlled createdBy field.
 // Missing actor, unauthenticated and service-account writes are not
 // silently promoted to administrative sends. Trusted backfills need their own
 // separately reviewed outbox path.
 const actor=event.authId;
 // Real Firebase REST writes can be labelled api_key while authId is the
 // verified Firebase UID. A cloud probe confirmed this; never classify solely
 // from the label, and never accept a public API key as a user identity.
 if(!validId(actor)||!['api_key','unknown'].includes(event.authType))return null;
 if(process.env.FUNCTIONS_EMULATOR!=='true') {
  try { const account=await getAuth().getUser(actor);if(account.disabled)return null; }
  catch (error) { if(['auth/user-not-found','auth/invalid-uid'].includes(error.code))return null;throw error; }
 }
 const profile=(await db.doc('users/'+actor).get()).data();
 if(!profile||profile.isBlocked===true)return null;
 const data={...after};
 if(data.type==='chat_message' && !validId(data.messageId) && validId(data.chatId)) {
  // Older collapsed chat documents do not carry a source message ID. A
  // read-only inbox update must never be mistaken for a new source message.
  if(before && before.message===data.message && before.title===data.title && before.unreadCount>=data.unreadCount)return null;
  const messages=await db.collection(`chats/${data.chatId}/messages`).orderBy('createdAt','desc').limit(1).get();
  if(messages.empty)return null;data.messageId=messages.docs[0].id;
 }
 let authorized=profile.isAdmin===true;
 if(!authorized && data.type==='chat_message' && validId(data.chatId) && validId(data.messageId)) {
  const [source,settings]=await Promise.all([db.doc(`chats/${data.chatId}/messages/${data.messageId}`).get(),db.doc('settings/app_settings').get()]);
  authorized=data.chatId===actor && data.userId===settings.data()?.adminUid && source.data()?.senderId===actor && !source.data()?.deletedAt;
  if(authorized){data.title='رسالة جديدة';data.message=String(source.data().message||'رسالة جديدة');}
 }
 if(!authorized && ['comment','reply'].includes(data.type) && validId(data.propertyId) && validId(data.commentId)) {
  const property=await db.doc('properties/'+data.propertyId).get();
  const parent=await db.doc(`properties/${data.propertyId}/comments/${data.commentId}`).get();
  if(data.type==='comment')authorized=property.data()?.publisherUid===data.userId && parent.data()?.userId===actor;
  else if(validId(data.replyId)) {const reply=await parent.ref.collection('replies').doc(data.replyId).get();authorized=parent.data()?.userId===data.userId && reply.data()?.userId===actor;}
  if(authorized){data.title=data.type==='comment'?'تعليق جديد':'رد جديد';data.message=data.title;}
 }
 if(!authorized)return null;
 return canonicalEvent(data,before,event.params.notificationId);
}


exports.deliverBridgeNotification=onDocumentWrittenWithAuthContext({document:'notifications/{notificationId}',retry:true,maxInstances:2,...providerSecretOptions()},async event=>{
 if(!bridgeEnabled())return;
 const db=getFirestore(),push=await verifiedEvent(event,db);
 if(!push){if(event.data?.after.exists)logger.warn('push_bridge_source_rejected',{notificationHash:hash(event.params.notificationId)});return;}
 // Immutable, protected snapshots allow the Vercel adapter to wake a known
 // event without trusting its unauthenticated legacy HTTP payload.
 await publishVerified(push,db);
});
async function publishVerified(push,db) {
 const ref=db.doc('push_bridge_events/'+push.key);
 await db.runTransaction(async tx=>{if(!(await tx.get(ref)).exists)tx.create(ref,{...push,verifiedAt:FieldValue.serverTimestamp()});});
 await db.doc('push_bridge_inbox/'+hash(push.notificationId)).set({eventKey:push.key,notificationId:push.notificationId,updatedAt:FieldValue.serverTimestamp()});
 await dispatchBridge(push,db);
}

// Source triggers restore legacy events even when an old inbox payload lacks
// source IDs or the unauthenticated Vercel caller cannot be correlated. They
// produce the same canonical event keys as new-client inbox documents.
async function fromSource(event,payload) {
 if(!bridgeEnabled()||!event.data?.exists||event.data.data().isHidden===true||event.data.data().isDeleted===true||!payload||payload.userId===event.authId)return;
 const db=getFirestore();
 const id='source_'+hash(JSON.stringify(payload)).slice(0,48);
 const adapted={authId:event.authId,authType:event.authType,params:{notificationId:id},data:{before:{exists:false},after:{exists:true,data:()=>payload}}};
 const push=await verifiedEvent(adapted,db);if(push)await publishVerified(push,db);
}
exports.bridgeCommentCreated=onDocumentCreatedWithAuthContext({document:'properties/{propertyId}/comments/{commentId}',retry:true,maxInstances:2,...providerSecretOptions()},async event=>{
 if(!bridgeEnabled()||!event.data?.exists)return;
 const property=(await getFirestore().doc('properties/'+event.params.propertyId).get()).data();
 if(!validId(property?.publisherUid))return;
 return fromSource(event,{type:'comment',userId:property.publisherUid,propertyId:event.params.propertyId,commentId:event.params.commentId,title:'تعليق جديد',message:'تعليق جديد على عقارك'});
});
exports.bridgeReplyCreated=onDocumentCreatedWithAuthContext({document:'properties/{propertyId}/comments/{commentId}/replies/{replyId}',retry:true,maxInstances:2,...providerSecretOptions()},async event=>{
 if(!bridgeEnabled()||!event.data?.exists)return;
 const p=event.params,parent=(await getFirestore().doc(`properties/${p.propertyId}/comments/${p.commentId}`).get()).data();
 if(!validId(parent?.userId))return;
 return fromSource(event,{type:'reply',userId:parent.userId,propertyId:p.propertyId,commentId:p.commentId,replyId:p.replyId,title:'رد جديد',message:'رد جديد على تعليقك'});
});
exports.bridgeChatMessageCreated=onDocumentCreatedWithAuthContext({document:'chats/{chatId}/messages/{messageId}',retry:true,maxInstances:2,...providerSecretOptions()},async event=>{
 if(!bridgeEnabled()||!event.data?.exists)return;
 const source=event.data.data(),p=event.params;
 if(source.senderId!==event.authId||source.deletedAt)return;
 const actor=(await getFirestore().doc('users/'+event.authId).get()).data();
 const settings=(await getFirestore().doc('settings/app_settings').get()).data();
 const recipient=actor?.isAdmin===true?p.chatId:settings?.adminUid;
 if(!validId(recipient))return;
 return fromSource(event,{type:'chat_message',userId:recipient,chatId:p.chatId,messageId:p.messageId,unreadCount:1,title:'رسالة جديدة',message:String(source.message||'رسالة جديدة')});
});

exports.reviewPushDeliveryHealth=onCall(async request=>{
 if(!request.auth?.uid)throw new HttpsError('unauthenticated','سجّل الدخول');
 const db=getFirestore(),user=await db.doc('users/'+request.auth.uid).get();
 if(user.data()?.isAdmin!==true||user.data()?.isBlocked===true)throw new HttpsError('permission-denied','غير مسموح');
 return deliveryHealth(db);
});
async function deliveryHealth(db) {
 const [pending,review]=await Promise.all([db.collection('push_deliveries').where('status','==','attempting').limit(101).get(),db.collection('push_deliveries').where('status','==','review_required').limit(101).get()]);
 const stale=pending.docs.filter(d=>(d.data().createdAt?.toMillis()||0)<Date.now()-120000).map(d=>d.id);
 const health={staleAttempting:stale.length,reviewRequired:review.size,truncated:pending.size>100||review.size>100,checkedAt:new Date().toISOString()};
 if(stale.length||review.size||health.truncated)logger.error('push_delivery_health_degraded',health);
 return health;
}
exports.monitorPushDeliveryHealth=onSchedule({schedule:'every 5 minutes',maxInstances:1},async()=>{if(bridgeEnabled())await deliveryHealth(getFirestore());});
// Internal exports are intentionally non-enumerable so Firebase never deploys them.
Object.defineProperty(exports,'internals',{value:{verifiedEvent,dispatchBridge,deliveryHealth}});
