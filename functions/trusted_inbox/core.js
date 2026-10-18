'use strict';
const {FieldValue,Timestamp}=require('firebase-admin/firestore');
const {hash,validId}=require('./shared/push_policy');
const enabled=()=>process.env.TRUSTED_INBOX_ENABLED==='true';
const safe=(v,max)=>typeof v==='string'?v.slice(0,max):'';
function itemFor(event){
 if(!event||!validId(event.userId)||event.userId==='all'||!/^[a-f0-9]{64}$/.test(event.key||''))throw Error('INVALID_TRUSTED_EVENT');
 const id='event_'+event.key;
 const item={notificationId:id,eventId:event.key,userId:event.userId,type:safe(event.type,64)||'general',title:safe(event.title,120)||'عقارات الأنبار',message:safe(event.message,2000),target:'user',readBy:[],isRead:false,isDismissed:false,verified:true,schemaVersion:1,createdAt:event.createdAt?.toMillis?event.createdAt:FieldValue.serverTimestamp()};
 for(const k of ['propertyId','officeId','chatId','messageId','commentId','replyId','requestId','subscriptionId'])if(validId(event[k]))item[k]=event[k];
 if(event.type==='chat_message')item.unreadCount=1;
 return {id,item};
}
async function persistTrusted(event,db){
 const {id,item}=itemFor(event),ref=db.doc('trusted_notifications/'+id);
 await db.runTransaction(async tx=>{if(!(await tx.get(ref)).exists)tx.create(ref,item);});
 return id;
}
module.exports={enabled,itemFor,persistTrusted,hash,validId,FieldValue,Timestamp};
