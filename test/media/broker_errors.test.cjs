const assert=require('node:assert'),fs=require('node:fs'),{createPrivateUploadHandler}=require('../../functions/media_private_upload'),{createPrivateReadHandler}=require('../../functions/media_private_read');
const captured=[],old=console.error;console.error=(...x)=>captured.push(x);let count=0;
const auth={verifyIdToken:async()=>({uid:'alice',firebase:{sign_in_provider:'password'}})},db={doc:()=>({get:async()=>({data:()=>({isBlocked:false,isAdmin:false})})})};
function res(){return{code:0,status(n){this.code=n;return this},json(){return this},end(){return this},set(){return this}}}
const payload={purpose:'license',uploadId:'a'.repeat(32),content:Buffer.from([137,80,78,71,13,10,26,10,0,0]).toString('base64')};
(async()=>{
 for(const code of [403,'ECONNRESET',500]){
  const bucket={name:'demo-media',file:()=>({getMetadata:async()=>{throw Object.assign(Error('Secret message must not be logged'),{code})}})};
  for(const kind of ['upload','read']){let r=res();const handler=kind==='upload'?createPrivateUploadHandler({auth,db,bucket,authorizeQuota:async()=>{}}):createPrivateReadHandler({auth,db,bucket});await handler({method:kind==='upload'?'POST':'GET',headers:{authorization:'Bearer synthetic-token'},body:payload,query:{path:'uploads/private/license/alice/a.png'}},r);assert.equal(r.code,503);count++}
 }
 const bucket={name:'demo-media',file:()=>({getMetadata:async()=>{throw Object.assign(Error('missing'),{code:404})}})};
 let r=res();await createPrivateUploadHandler({auth,db,bucket,authorizeQuota:async()=>{throw Error('UPLOAD_QUOTA')}})({method:'POST',headers:{authorization:'Bearer synthetic-token'},body:payload},r);assert.equal(r.code,429);count++;
 r=res();await createPrivateReadHandler({auth,db,bucket})({method:'GET',headers:{authorization:'Bearer synthetic-token'},query:{path:'uploads/private/license/alice/a.png'}},r);assert.equal(r.code,404);count++;
 const invalidAuth={verifyIdToken:async()=>{throw Object.assign(Error('secret auth detail'),{code:'auth/id-token-expired'})}};
 for(const kind of ['upload','read']){r=res();const handler=kind==='upload'?createPrivateUploadHandler({auth:invalidAuth,db,bucket,authorizeQuota:async()=>{}}):createPrivateReadHandler({auth:invalidAuth,db,bucket});await handler({method:kind==='upload'?'POST':'GET',headers:{authorization:'Bearer synthetic-token'},body:payload,query:{path:'uploads/private/license/alice/a.png'}},r);assert.equal(r.code,401);count++}
 assert(!JSON.stringify(captured).includes('secret')&&!JSON.stringify(captured).includes('Secret')&&!JSON.stringify(captured).includes('synthetic-token'));count++;
 old('Backend error classification checks passed',count)
})().catch(e=>{old(e.message);process.exitCode=1}).finally(()=>console.error=old);
