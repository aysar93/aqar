'use strict';
const {createHash}=require('node:crypto');
function createCleanupRequestHandler({auth,db}) {
 return async(req,res)=>{
  try {
   if(req.method!=='POST')return res.status(405).end();
   const bearer=/^Bearer (\S+)$/.exec(req.headers.authorization||'');
   if(!bearer)return res.status(401).end();
   const token=await auth.verifyIdToken(bearer[1],true);
   if(!token.uid||token.firebase?.sign_in_provider==='anonymous')return res.status(403).end();
   const user=(await db.doc(`users/${token.uid}`).get()).data();
   if(!user||user.isBlocked!==false)return res.status(403).end();
   const path=req.body?.path,parts=typeof path==='string'?path.split('/'):[];
   const ordinary=parts.length===5&&parts[0]==='uploads'&&['public','private'].includes(parts[1])&&['property','avatar','office','banner','appLogo','license','receipt'].includes(parts[2])&&parts[3]===token.uid;
   const chat=parts.length===6&&parts[0]==='uploads'&&parts[1]==='private'&&['chat_images','chat_audio'].includes(parts[2])&&parts[4]===token.uid;
   if((!ordinary&&!chat)||path.includes('..')||!/^[a-f0-9]{32}\.(jpg|png|m4a)$/.test(parts.at(-1)))return res.status(403).end();
   const id=createHash('sha256').update(token.uid+'\0'+path).digest('hex');
   const ref=db.doc(`media_cleanup_requests/${id}`);
   await db.runTransaction(async tx=>{
    if((await tx.get(ref)).exists)return;
    tx.create(ref,{path,ownerUid:token.uid,state:'retained_pending_reference_barrier',requestedAtMillis:Date.now()});
   });
   // Queue acceptance never claims that a shared file has been deleted.
   return res.status(202).json({accepted:true,deleted:false});
  }catch(e){return res.status(String(e?.code||'').startsWith('auth/')?401:503).end();}
 };
}
module.exports={createCleanupRequestHandler};
