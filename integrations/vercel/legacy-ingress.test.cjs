const {test}=require('node:test'),assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {createLegacyIngress}=require('./legacy-ingress.cjs');
const hash=x=>createHash('sha256').update(x).digest('hex');
const key='a'.repeat(64);
function fixture({verified=true,available=true}={}) {
 const documents=new Map();
 if(available)documents.set('push_bridge_inbox/'+hash('n'),{notificationId:'n',eventKey:key});
 documents.set('push_bridge_events/'+key,{notificationId:'n',key,userId:'real-recipient',title:'saved title',...(verified?{verifiedAt:Date.now()}:{})});
 const db={doc:path=>({path,get:async()=>({data:()=>documents.get(path)})}),runTransaction:async fn=>fn({get:ref=>ref.get(),set:(ref,value)=>documents.set(ref.path,value)})};
 const sends=[];const handler=createLegacyIngress({db,dispatch:async event=>sends.push(event)});
 const res={status(code){this.code=code;return this;},json(value){this.value=value;return this;}};
 return {handler,res,sends};
}
test('legacy payload cannot override authenticated recipient, text, event or broad audience',async()=>{
 const f=fixture();await f.handler({method:'POST',body:{notificationId:'n',target:'all',userId:'victim',title:'forged',eventId:'other'}},f.res);
 assert.equal(f.res.code,200);assert.equal(f.sends[0].userId,'real-recipient');assert.equal(f.sends[0].title,'saved title');
});
test('missing IDs and not-yet-verified events never invoke either provider',async()=>{
 for(const options of [{available:false},{verified:false}]){const f=fixture(options);await f.handler({method:'POST',body:{notificationId:'n'}},f.res);assert.equal(f.res.code,202);assert.equal(f.sends.length,0);}
 const f=fixture();await f.handler({method:'POST',body:{target:'all'}},f.res);assert.equal(f.res.code,400);
});
test('rate limit rejects repeated anonymous wakeups without sending caller data',async()=>{
 const f=fixture({available:false});for(let i=0;i<121;i++)await f.handler({method:'POST',body:{notificationId:'n'}},f.res);
 assert.equal(f.res.code,429);assert.equal(f.sends.length,0);
});
