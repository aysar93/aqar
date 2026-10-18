'use strict';
const {createHash}=require('node:crypto');
const hash=value=>createHash('sha256').update(value).digest('hex');
// This replaces /send ONLY after an explicit deployment approval. It accepts
// the old HTTP shape but never trusts its recipient, text, type, or audience.
// Only an immutable event authenticated by the Firestore trigger can be woken.
function createLegacyIngress({db,dispatch,clock=Date.now}) {
 return async function legacyIngress(req,res) {
  if(req.method!=='POST')return res.status(405).json({success:false,error:'method_not_allowed'});
  const id=req.body?.notificationId||req.body?.data?.notificationId;
  if(typeof id!=='string'||!id||id.length>128||id.includes('/'))return res.status(400).json({success:false,error:'notification_id_required'});
  try {
   const ip=String(req.socket?.remoteAddress||'unknown');
   const rate=db.doc('push_ingress_limits/'+hash(ip));
   const allowed=await db.runTransaction(async tx=>{
    const previous=(await tx.get(rate)).data()||{};const now=clock();const within=now-Number(previous.start||0)<60000;
    const count=within?Number(previous.count||0)+1:1;
    if(count>120)return false;tx.set(rate,{start:within?previous.start:now,count});return true;
   });
   if(!allowed)return res.status(429).json({success:false,error:'rate_limited'});
   const pointer=(await db.doc('push_bridge_inbox/'+hash(id)).get()).data();
   if(!pointer)return res.status(202).json({success:true,pendingVerification:true,pushSent:false,reason:'awaiting_verified_firestore_event'});
   if(pointer.notificationId!==id||!/^[a-f0-9]{64}$/.test(pointer.eventKey))throw Error('Invalid protected pointer');
   const event=(await db.doc('push_bridge_events/'+pointer.eventKey).get()).data();
   if(!event||event.key!==pointer.eventKey||!event.verifiedAt)return res.status(202).json({success:true,pendingVerification:true,pushSent:false});
   const verifiedAt=typeof event.verifiedAt==='number'?event.verifiedAt:event.verifiedAt.toMillis?.();
   if(!verifiedAt||clock()-verifiedAt>30*60000)return res.status(200).json({success:true,skipped:true,pushSent:false,reason:'stale_verified_event'});
   await dispatch(event);
   return res.status(200).json({success:true,notificationId:id,handled:true,deliveryConfirmed:false});
  }catch(_){return res.status(503).json({success:false,error:'bridge_temporarily_unavailable'});}
 };
}
module.exports={createLegacyIngress};

