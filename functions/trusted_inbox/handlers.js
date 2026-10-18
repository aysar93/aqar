'use strict';
const {getFirestore,FieldPath}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
const {enabled,persistTrusted,hash,validId,FieldValue,Timestamp}=require('./core');
const {canonicalEvent}=require('./shared/push_bridge_policy');
const {dispatchBridge,ensureVisibleInbox}=require('./shared/push_bridge_dispatch');
const logger=require('firebase-functions/logger');
async function actorFor(event,db){
 if(!validId(event.authId)||!['api_key','unknown'].includes(event.authType))return null;
 try{if((await getAuth().getUser(event.authId)).disabled)return null;}catch(e){if(['auth/user-not-found','auth/invalid-uid'].includes(e.code))return null;throw e;}
 const profile=(await db.doc('users/'+event.authId).get()).data();
 return profile&&profile.isBlocked!==true?profile:null;
}
function administrativePayload(data){
 if(typeof data.type!=='string'||data.type.length>64||typeof data.title!=='string'||data.title.length>120||typeof data.message!=='string'||data.message.length>2000)throw Error('INVALID_REQUEST');
 const out={type:data.type,title:data.title,message:data.message,deliveryType:data.deliveryType==='internal'?'internal':'external'};
 for(const k of ['propertyId','officeId','chatId','messageId','commentId','replyId','requestId','subscriptionId'])if(validId(data[k]))out[k]=data[k];
 return out;
}
async function publish(payload,id,db){
 const push=canonicalEvent({...payload,deliveryType:'external'},null,id);if(!push)throw Error('INVALID_CANONICAL_REQUEST');
 await persistTrusted(push,db); // Visible trusted item exists before any provider decision.
 const ref=db.doc('push_bridge_events/'+push.key);
 await db.runTransaction(async tx=>{if(!(await tx.get(ref)).exists)tx.create(ref,{...push,verifiedAt:FieldValue.serverTimestamp()});});
 if(payload.deliveryType==='internal'){await ensureVisibleInbox(push,db);return;}
 await db.doc('push_bridge_inbox/'+hash(id)).set({notificationId:id,eventKey:push.key,updatedAt:FieldValue.serverTimestamp()});
 await dispatchBridge(push,db); // Existing pause, empty-cohort and claim checks remain authoritative.
}
async function requestCreated(event,db=getFirestore()){
 if(!enabled()||!event.data?.exists)return;
 const profile=await actorFor(event,db),data=event.data.data();
 if(profile?.isAdmin!==true||data.createdBy!==event.authId||data.requestVersion!==1){logger.warn('trusted_inbox_request_rejected');return;}
 let payload;try{payload=administrativePayload(data);if(!canonicalEvent({...payload,userId:'validation-user',deliveryType:'external'},null,'validation-request'))throw Error('INVALID_REQUEST');}catch{logger.warn('trusted_inbox_request_invalid');return;}
 const id='request_'+event.params.requestId;
 if(data.target==='all'){
  const ref=db.doc('trusted_notification_jobs/'+hash(id));
  await db.runTransaction(async tx=>{if(!(await tx.get(ref)).exists)tx.create(ref,{kind:'admin',payload,sourceId:id,actorUid:event.authId,status:'pending',cursor:null,createdAt:FieldValue.serverTimestamp()});});return;
 }
 if(data.target!=='user'||!validId(data.userId)||data.userId==='all')return;
 if(!(await db.doc('users/'+data.userId).get()).exists)return;
 await publish({...payload,userId:data.userId},id,db);
}
async function mirrorVerified(event,db=getFirestore()){
 if(!enabled()||!event.data?.exists)return;
 const push=event.data.data();
 if(!push.verifiedAt||push.key!==event.params.eventId||canonicalEvent(push,null,push.notificationId)?.key!==push.key)return;
 // This collection already denies every client write; no client verified flag is trusted.
 await persistTrusted(push,db);
}
async function propertyApproved(event,db=getFirestore()){
 if(!enabled()||!event.data?.after.exists)return;
 const after=event.data.after.data(),before=event.data.before.exists?event.data.before.data():null;
 if(after.status!=='approved'||before?.status==='approved'||!validId(after.officeId))return;
 const actor=await actorFor(event,db),office=(await db.doc('offices/'+after.officeId).get()).data();
 if(!actor||!office||office.status!=='active'||office.isVerified!==true||!(actor.isAdmin===true||event.authId===office.ownerId&&event.authId===after.publisherUid))return;
 const sourceId='office_property_'+event.params.propertyId,ref=db.doc('trusted_notification_jobs/'+hash(sourceId));
 await db.runTransaction(async tx=>{if(!(await tx.get(ref)).exists)tx.create(ref,{kind:'office',officeId:after.officeId,propertyId:event.params.propertyId,sourceId,status:'pending',cursor:null,createdAt:FieldValue.serverTimestamp()});});
}
async function fanoutJob(event,db=getFirestore()){
 if(!enabled())return;
 const ref=db.doc('trusted_notification_jobs/'+event.params.jobId),snap=await ref.get(),job=snap.data();
 if(!job||job.status!=='pending')return;
 let payload,query;
 if(job.kind==='office'){
  const [p,o]=await Promise.all([db.doc('properties/'+job.propertyId).get(),db.doc('offices/'+job.officeId).get()]);
  if(p.data()?.status!=='approved'||p.data()?.officeId!==job.officeId||o.data()?.status!=='active'||o.data()?.isVerified!==true){await ref.update({status:'cancelled'});return;}
  payload={type:'property',title:'عقار جديد من المكتب الذي تتابعه',message:String(p.data().title||'تم نشر عقار جديد').slice(0,500),propertyId:job.propertyId,officeId:job.officeId,deliveryType:'internal'};
  query=db.collection('office_followers').where('officeId','==',job.officeId).where('isActive','==',true).orderBy(FieldPath.documentId());
 }else if(job.kind==='admin'){
  const profile=(await db.doc('users/'+job.actorUid).get()).data();
  if(profile?.isAdmin!==true||profile.isBlocked===true){await ref.update({status:'cancelled'});return;}
  try{if((await getAuth().getUser(job.actorUid)).disabled){await ref.update({status:'cancelled'});return;}}catch(e){if(e.code==='auth/user-not-found'){await ref.update({status:'cancelled'});return;}throw e;}
  payload=job.payload;query=db.collection('users').orderBy(FieldPath.documentId());
 }else return;
 if(job.cursor)query=query.startAfter(job.cursor);
 const page=await query.limit(100).get();
 // Idempotent per source/recipient; crashes or concurrent workers can safely revisit a page.
 for(const row of page.docs){
  const uid=job.kind==='office'?row.data().userId:row.id;
  if(!validId(uid)||uid==='all')continue;
  const user=(await db.doc('users/'+uid).get()).data();if(!user||user.isBlocked===true)continue;
  await publish({...payload,userId:uid},'job_'+hash(JSON.stringify([job.kind,job.sourceId,uid])),db);
 }
 await db.runTransaction(async tx=>{const current=(await tx.get(ref)).data();if(current?.status==='pending'&&current.cursor===job.cursor)tx.update(ref,{cursor:page.docs.at(-1)?.id||job.cursor,status:page.size<100?'complete':'pending',updatedAt:FieldValue.serverTimestamp()});});
}
module.exports={requestCreated,mirrorVerified,propertyApproved,fanoutJob,administrativePayload,publish};
