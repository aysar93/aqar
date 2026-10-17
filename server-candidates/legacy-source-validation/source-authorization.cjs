'use strict';
// Internal policy only. Inputs must be Firestore snapshots fetched by the
// authenticated source/notification handler, never fields from an HTTP body.
const id=v=>typeof v==='string'&&v.length>0&&v.length<=128&&!v.includes('/');
const visible=s=>!!s&&s.isHidden!==true&&s.isDeleted!==true&&s.deletedAt==null;
function authorize({actor,type,declaredRecipient,property,parent,reply}){
 if(!id(actor)||!visible(parent))return {authorized:false};
 let recipient;
 if(type==='comment'&&parent.userId===actor)recipient=property?.publisherUid;
 if(type==='reply'&&visible(reply)&&reply.userId===actor)recipient=parent.userId;
 if(!id(recipient)||recipient!==declaredRecipient)return {authorized:false};
 return {authorized:true,recipient,title:type==='comment'?'تعليق جديد':'رد جديد'};
}
module.exports={authorize};
