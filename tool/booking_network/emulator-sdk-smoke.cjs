'use strict';
// Real JS SDK + original backend smoke. NOT the Flutter/native client proof.
require('./loopback-only.cjs');
const path=require('node:path'),fs=require('node:fs'),crypto=require('node:crypto');
const {createRequire}=require('node:module');
const dep=createRequire(path.resolve(__dirname,'../../functions/package.json'));
const sdkRoot=process.env.BOOKING_FIREBASE_JS_SDK_ROOT;
if(!sdkRoot)throw Error('Existing local Firebase JS SDK root required; no install');
const sdk=createRequire(path.resolve(sdkRoot,'package.json'));
Object.assign(process.env,{GCLOUD_PROJECT:'demo-aqar',FIRESTORE_EMULATOR_HOST:'127.0.0.1:8185',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:9099',FIREBASE_STORAGE_EMULATOR_HOST:'127.0.0.1:9198'});
const {initializeApp,deleteApp}=sdk('firebase/app');
const {getAuth,connectAuthEmulator,createUserWithEmailAndPassword,deleteUser}=sdk('firebase/auth');
const {getFunctions,connectFunctionsEmulator,httpsCallable}=sdk('firebase/functions');
const {initializeApp:adminInit,deleteApp:adminDelete}=dep('firebase-admin/app');
const {getFirestore}=dep('firebase-admin/firestore'),{getStorage}=dep('firebase-admin/storage');
const events=[];const record=(event,data={})=>events.push({event,atUtc:new Date().toISOString(),...data});
(async()=>{
 const app=initializeApp({apiKey:'synthetic-emulator-key',appId:'demo-local',projectId:'demo-aqar'});
 const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
 const holdImage=process.argv.includes('--hold-image'),cutChunk=process.argv.includes('--cut-chunk');
 const functions=getFunctions(app);connectFunctionsEmulator(functions,'127.0.0.1',holdImage||cutChunk?5001:5002);
 const admin=adminInit({projectId:'demo-aqar',storageBucket:'demo-aqar.appspot.com'}),db=getFirestore(admin),bucket=getStorage(admin).bucket();
 let user;
 try {
  user=(await createUserWithEmailAndPassword(auth,'local-'+crypto.randomUUID()+'@test.invalid',crypto.randomBytes(20).toString('hex'))).user;
  const uid=user.uid,venue='local_'+crypto.randomUUID().replaceAll('-','');
  await db.doc('users/'+uid).set({name:'local synthetic owner',phone:'07700000000',isBlocked:false});
  await db.doc('booking_venues/'+venue).set({ownerId:uid,active:true,mediaPaths:[]});
  if(process.argv.includes('--image')||holdImage){
   const png=await dep('sharp')({create:{width:32,height:32,channels:3,background:{r:0,g:170,b:136}}}).png().toBuffer();
   if(holdImage)await fetch('http://127.0.0.1:5001/__arm',{method:'POST',body:JSON.stringify({function:'uploadBookingImage',mode:'hold-response'})});
   let completed=false;
   const pending=httpsCallable(functions,'uploadBookingImage',{timeout:180000})({kind:'venue',venueId:venue,base64:png.toString('base64')}).then(r=>{completed=true;return r;});
   if(holdImage){
    const deadline=Date.now()+150000;let state;
    do{state=await (await fetch('http://127.0.0.1:5001/__state')).json();if(state.held)break;await new Promise(r=>setTimeout(r,100));}while(Date.now()<deadline);
    if(!state.held||completed)throw Error('RESPONSE_GATE_NOT_PROVEN');
    const before=await db.collection('booking_media_reviews').where('venueId','==',venue).get();
    if(before.size!==1||before.docs[0].data().status!=='pending')throw Error('PRE_RELEASE_STATE_MISSING');
    record('BACKEND_COMMITTED_BEFORE_SDK_CALLBACK',{documents:before.size,callbackDelivered:completed});
    await fetch('http://127.0.0.1:5001/__release',{method:'POST'});
   }
   const result=(await pending).data;
   const rows=await db.collection('booking_media_reviews').where('venueId','==',venue).get();
   const data=rows.docs[0]?.data(),[saved]=await bucket.file(result.path).download();
   if(rows.size!==1||data.status!=='pending'||data.size!==saved.length)throw Error('IMAGE_STATE_MISMATCH');
   record('IMAGE_VERIFIED',{documents:rows.size,status:data.status,bytes:saved.length});
   record('RESULT',{result:holdImage?'PASS_LOCAL_BACKEND_RESPONSE_GATE_JS_SDK_ONLY':'PASS_ORIGINAL_IMAGE_BACKEND_JS_SDK_ONLY',notFlutterNative:true});
   return;
  }
  const bytes=Buffer.alloc(128*1024);bytes.writeUInt32BE(bytes.length,0);bytes.write('ftypisom',4,'ascii');
  const reservation=(await httpsCallable(functions,'reserveBookingVideo',{timeout:180000})({venueId:venue,size:bytes.length})).data;
  record('RESERVED',{mediaId:reservation.mediaId});
  const token=await user.getIdToken();
  const chunkUrl=`http://127.0.0.1:${cutChunk?5001:5002}/demo-aqar/us-central1/uploadBookingVideoChunk?mediaId=${reservation.mediaId}&index=0`;
  if(cutChunk){
   await fetch('http://127.0.0.1:5001/__arm',{method:'POST',body:JSON.stringify({function:'uploadBookingVideoChunk',mode:'cut',offset:65536})});
   let failed=false;try{await fetch(chunkUrl,{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/octet-stream'},body:bytes});}catch(_){failed=true;}
   const [before]=await bucket.getFiles({prefix:'_booking_upload_parts/'+reservation.mediaId+'/'});
   if(!failed||before.length!==0)throw Error('CUT_NOT_ISOLATED');
   const state=await (await fetch('http://127.0.0.1:5001/__state')).json();
   record('CUT_NO_PART',{parts:before.length,proxyCut:state.events.filter(e=>e.event==='REQUEST_CUT').at(-1)});
  }
  const response=await fetch(chunkUrl,{
   method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/octet-stream'},body:bytes});
  record('CHUNK_RESPONSE',{status:response.status});if(response.status!==200)throw Error('CHUNK_FAILED');
  if(cutChunk){
   const [parts]=await bucket.getFiles({prefix:'_booking_upload_parts/'+reservation.mediaId+'/'});
   const [saved]=await parts[0].download();
   const same=crypto.createHash('sha256').update(saved).digest('hex')===crypto.createHash('sha256').update(bytes).digest('hex');
   if(parts.length!==1||!same)throw Error('RETRY_DUPLICATED_OR_CHANGED');
   record('RESULT',{result:'PASS_LOCAL_ORIGINAL_CHUNK_GATE_ONLY',parts:parts.length,hashMatches:same,manualRetry:true,notFlutterNative:true});return;
  }
  await httpsCallable(functions,'finishBookingVideo')({mediaId:reservation.mediaId});
  const data=(await db.doc('booking_media_reviews/'+reservation.mediaId).get()).data();
  const [files]=await bucket.getFiles({prefix:'_booking_upload_parts/'+reservation.mediaId+'/'});
  const [saved]=await bucket.file(reservation.path).download();
  const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
  if(data.status!=='pending'||hash(saved)!==hash(bytes)||files.length!==0)throw Error('INCONSISTENT_FINAL');
  record('VERIFIED',{status:data.status,parts:files.length,bytes:saved.length,sha256:hash(saved)});
  record('RESULT',{result:'PASS_ORIGINAL_BACKEND_JS_SDK_ONLY',notFlutterNative:true});
 }catch(error){record('RESULT',{result:'BLOCKED',code:typeof error.code==='string'?error.code:'LOCAL_FLOW_FAILED'});process.exitCode=1;}
 finally{
  if(user)await deleteUser(user);await deleteApp(app);await adminDelete(admin);
  const output=cutChunk?'chunk-cut-gate.json':holdImage?'image-response-gate.json':process.argv.includes('--image')?'image-smoke.json':'sdk-smoke.json';
  fs.writeFileSync(path.join(__dirname,'.local',output),JSON.stringify({project:'demo-aqar',events,cloudRequests:0,nativeFlutterClientInvoked:false},null,2));
  console.log(JSON.stringify({project:'demo-aqar',events,cloudRequests:0,nativeFlutterClientInvoked:false}));
 }
})().catch(()=>{console.error('LOCAL_BOOTSTRAP_FAILED');process.exitCode=1;});
