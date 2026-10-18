const {test}=require('node:test'),assert=require('node:assert/strict');
const Module=require('node:module');
const previous=Module._load;
// Bootstrap guard tests must never obtain credentials or initialize an SDK.
Module._load=function(name,...args){
 if(name==='firebase-admin/app')return {getApps:()=>[],initializeApp:()=>{throw Error('Unexpected SDK initialization');},cert:()=>{throw Error('Unexpected credential load');}};
 if(name==='firebase-admin/firestore')return {getFirestore:()=>{throw Error('Unexpected database initialization');}};
 return previous.call(this,name,...args);
};
const {handler,initializePreview}=require('./preview-entry.cjs');Module._load=previous;
const response=()=>({setHeader(){},end(body){this.body=JSON.parse(body);}});
test('production project and mixed injected database cannot initialize preview',()=>{
 const old=process.env.GCLOUD_PROJECT;
 try{process.env.GCLOUD_PROJECT='aqar-9f3f9';assert.throws(()=>initializePreview(),/Exact test/);
 process.env.GCLOUD_PROJECT='aqar-fcm-test-20261014';assert.throws(()=>initializePreview({db:{projectId:'aqar-9f3f9'}}),/Mixed database/);}
 finally{if(old===undefined)delete process.env.GCLOUD_PROJECT;else process.env.GCLOUD_PROJECT=old;}
});
test('preparsed Vercel payload limit and malformed JSON are rejected before credentials',async()=>{
 const large=response();await handler({method:'POST',url:'/send',body:{notificationId:'n',text:'x'.repeat(65536)}},large);assert.equal(large.statusCode,413);
 const bad=response();await handler({method:'POST',url:'/send',async *[Symbol.asyncIterator](){yield Buffer.from('{');}},bad);assert.equal(bad.statusCode,400);
});
test('bootstrap failure is logged without the request body or credential value',async()=>{
 const log=console.error,project=process.env.GCLOUD_PROJECT;let record;
 try{console.error=value=>{record=value;};process.env.GCLOUD_PROJECT='aqar-9f3f9';
 const res=response();await handler({method:'POST',url:'/send',body:{notificationId:'private-request-text'}},res);
 assert.equal(res.statusCode,503);assert.equal(record.stage,'initialize');
 assert.equal(JSON.stringify(record).includes('private-request-text'),false);
 assert.equal(record.projectMatches,false);
 }finally{console.error=log;if(project===undefined)delete process.env.GCLOUD_PROJECT;else process.env.GCLOUD_PROJECT=project;}
});
