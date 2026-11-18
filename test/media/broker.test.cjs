const fs=require('fs'),assert=require('assert'),crypto=require('crypto');
const root=require('node:path').resolve(__dirname,'../../functions');
const {createPrivateUploadHandler,validateBody,firestoreQuota}=require(root+'/media_private_upload');
const {createPrivateReadHandler,authorizedPath}=require(root+'/media_private_read');
const files=new Map(),data=new Map();let saves=0,quotas=0,verifiedRevocation=false,checks=0;
data.set('users/alice',{isBlocked:false,isAdmin:false});data.set('users/admin',{isBlocked:false,isAdmin:true});data.set('users/bob',{isBlocked:false,isAdmin:false});data.set('users/blocked',{isBlocked:true,isAdmin:false});
data.set('chats/alice',{isBlocked:false,isClosed:false});data.set('settings/app_settings',{allowChat:true,chatPreferences:{voiceEnabled:true,voiceSeconds:120}});
data.set('bookings/book',{customerId:'alice',ownerId:'bob',status:'held',holdUntil:Date.now()+3600000});
const db={doc:path=>({path,get:async()=>({data:()=>data.get(path)})})};
const auth={verifyIdToken:async(token,check)=>{verifiedRevocation=check;if(token==='invalid')throw Error('auth');return {uid:token,firebase:{sign_in_provider:'password'}}}};
const bucket={name:'demo-media',file:path=>({
getMetadata:async()=>{if(!files.has(path))throw Object.assign(Error('notfound'),{code:404});return [files.get(path).metadata]},
save:async(bytes,options)=>{assert.equal(options.preconditionOpts.ifGenerationMatch,0);assert.equal(options.metadata.cacheControl,'no-store');assert(!options.metadata.metadata.firebaseStorageDownloadTokens);if(files.has(path))throw Object.assign(Error('race'),{code:412});saves++;files.set(path,{bytes,metadata:{size:bytes.length,...options.metadata}})},
download:async()=>[files.get(path).bytes]})};
const upload=createPrivateUploadHandler({auth,db,bucket,authorizeQuota:async()=>{quotas++}});
const read=createPrivateReadHandler({auth,db,bucket});
const png=Buffer.from([137,80,78,71,13,10,26,10,0,0]);
function response(){return {code:0,body:null,headers:{},status(s){this.code=s;return this},json(x){this.body=x;return this},end(){return this},send(x){this.body=x;return this},set(k,v){this.headers[k]=v;return this}}}
async function send(handler,uid,body={},method='POST',query={}){if(method==='POST' && body.content && !body.uploadId) body={...body,uploadId:crypto.createHash('sha256').update(JSON.stringify(body)).digest('hex').slice(0,32)};const res=response();await handler({method,headers:uid?{authorization:'Bearer '+uid}:{},body,query},res);return res}
(async()=>{
 let result=await send(upload,'alice',{purpose:'license',content:png.toString('base64')});assert.equal(result.code,200);assert(verifiedRevocation);checks+=2;
 const path=result.body.path;assert(!result.body.url.includes('token='));assert(!files.get(path).metadata.metadata.firebaseStorageDownloadTokens);checks+=2;
 await send(upload,'alice',{purpose:'license',content:png.toString('base64')});assert.equal(saves,1);assert.equal(quotas,1);checks+=2;
 for(const [uid,expected]of [['alice',200],['admin',200],['bob',403],['blocked',403],[null,401]]){result=await send(read,uid,{},'GET',{path});assert.equal(result.code,expected);checks++}
 result=await send(read,'alice',{},'HEAD',{path});assert.equal(result.code,200);assert.equal(result.headers['Cache-Control'],'no-store');checks+=2;
 for(const uid of [null,'invalid','blocked']){result=await send(upload,uid,{purpose:'license',content:png.toString('base64')});assert.notEqual(result.code,200);checks++}
 for(const body of [{purpose:'banner',content:png.toString('base64')},{purpose:'license',content:Buffer.from('<html>').toString('base64')},{purpose:'chatImage',chatId:'other',content:png.toString('base64')},{purpose:'chatImage',chatId:'../alice',content:png.toString('base64')}]){result=await send(upload,'alice',body);assert.notEqual(result.code,200);checks++}
 result=await send(upload,'alice',{purpose:'property',content:png.toString('base64')});assert.equal(result.code,200);assert(result.body.path.startsWith('uploads/public/property/alice/'));checks+=2;
 result=await send(upload,'admin',{purpose:'banner',content:png.toString('base64')});assert.equal(result.code,200);checks++;
 result=await send(upload,'alice',{purpose:'chatImage',chatId:'alice',content:png.toString('base64')});assert.equal(result.code,200);checks++;
 result=await send(read,'bob',{},'GET',{path:result.body.path});assert.equal(result.code,403);checks++;
 const staged='staging/private/cloudinary-hwxcrlcj/image/asset/v1/file.jpg';
 assert.equal(await authorizedPath({db,bucket,uid:'alice',user:data.get('users/alice'),path:staged}),false);checks++;
 data.set('media_asset_acl/asset',{object:staged,classification:'private',approved:false,owners:['alice']});
 assert.equal(await authorizedPath({db,bucket,uid:'alice',user:data.get('users/alice'),path:staged}),false);checks++;
 data.get('media_asset_acl/asset').approved=true;
 assert.equal(await authorizedPath({db,bucket,uid:'alice',user:data.get('users/alice'),path:staged}),true);checks++;
 files.get(path).metadata.metadata.firebaseStorageDownloadTokens='synthetic-secret-test-only';result=await send(read,'alice',{},'GET',{path});assert.equal(result.code,409);checks++;
 const quotaDb={doc:path=>({path}),runTransaction:async fn=>fn({get:async()=>({data:()=>({count:20,bytes:100})}),set(){throw Error('Quota bypass')}})};
 await assert.rejects(firestoreQuota(quotaDb)( {uid:'alice',bytes:10}));checks++;

 // Legacy records omit flags; match Firestore get('isBlocked', false),
 // but reject malformed/null/true flags instead of treating them as active.
 delete data.get('users/alice').isBlocked;
 delete data.get('chats/alice').isBlocked;
 delete data.get('chats/alice').isClosed;
 result=await send(upload,'alice',{purpose:'chatImage',chatId:'alice',content:png.toString('base64'),uploadId:'d'.repeat(32)});assert.equal(result.code,200);checks++;
 result=await send(read,'alice',{},'GET',{path:result.body.path});assert.equal(result.code,200);checks++;
 for(const flag of [true,null,'false',0]) {
  data.get('users/alice').isBlocked=flag;
  result=await send(upload,'alice',{purpose:'avatar',content:png.toString('base64'),uploadId:'e'.repeat(32)});assert.equal(result.code,403);checks++;
 }
 data.get('users/alice').isBlocked=false;
 for(const flag of [true,null,'false',0]) {
  data.get('chats/alice').isBlocked=flag;
  result=await send(upload,'alice',{purpose:'chatImage',chatId:'alice',content:png.toString('base64'),uploadId:'f'.repeat(32)});assert.equal(result.code,403);checks++;
 }
 console.log(checks+' private broker checks passed; no network or production I/O');
})().catch(e=>{console.error(e.message);process.exitCode=1});
