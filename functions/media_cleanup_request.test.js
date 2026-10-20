const {test}=require('node:test');const assert=require('node:assert/strict');
const {createCleanupRequestHandler}=require('./media_cleanup_request');
test('cleanup requests require owner and are deduplicated without physical delete',async()=>{
 const queued=new Map();let writes=0;
 const db={doc:path=>({path,get:async()=>({data:()=>({isBlocked:false})})}),runTransaction:async fn=>fn({get:async ref=>({exists:queued.has(ref.path)}),create:(ref,value)=>{queued.set(ref.path,value);writes++}})};
 const handler=createCleanupRequestHandler({auth:{verifyIdToken:async(token,revoked)=>{assert.equal(revoked,true);return{uid:'alice',firebase:{sign_in_provider:'password'}}}},db});
 async function call(path,authenticated=true){const r={code:0,status(c){this.code=c;return this},end(){return this},json(v){this.body=v;return this}};await handler({method:'POST',headers:authenticated?{authorization:'Bearer synthetic-only'}:{},body:{path}},r);return r;}
 const path='uploads/public/property/alice/'+'a'.repeat(32)+'.jpg';
 assert.equal((await call(path,false)).code,401);
 assert.equal((await call(path.replace('/alice/','/bob/'))).code,403);
 assert.equal((await call('staging/private/original.jpg')).code,403);
 for(let i=0;i<2;i++){const r=await call(path);assert.equal(r.code,202);assert.equal(r.body.deleted,false)}
 assert.equal(writes,1);assert.equal([...queued.values()][0].state,'retained_pending_reference_barrier');
});
