const {test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185' || process.env.GCLOUD_PROJECT!=='demo-aqar') throw Error('Isolated demo emulator required');
process.env.BOOKING_WORKER_URL='https://worker.test';
process.env.BOOKING_IMAGE_PROXY_URL='https://image.test/bookingImage';
process.env.BOOKING_CLOUDINARY_CLOUD_NAME='test-only';
process.env.BOOKING_CLOUDINARY_API_KEY='test-key';
process.env.BOOKING_CLOUDINARY_API_SECRET='test-secret';
process.env.BOOKING_WORKER_SECRET='test-worker-secret';
initializeApp({projectId:'demo-aqar'});
const db=getFirestore(),f=require('./booking_external_media');
const call=(name,uid,data)=>f[name].run({auth:uid?{uid,token:{}}:null,data});
test('transactional quotas, ownership, image review, banner replacement and retry lifecycle',async t=>{
  const prefix=`media_${Date.now()}`,owner=prefix+'_owner',admin=prefix+'_admin',other=prefix+'_other',blocked=prefix+'_blocked',venueId=prefix+'_venue';
  for(const uid of [owner,admin,other,blocked]) await db.doc(`users/${uid}`).set({isAdmin:uid===admin,isBlocked:uid===blocked});
  await db.doc(`booking_venues/${venueId}`).set({ownerId:owner,active:true,category:'farm',mediaPaths:[]});
  const attempts=[]; let failDelete=false;
  // Every provider call is mocked. Fail if a request would leave the test.
  t.mock.method(globalThis,'fetch',async(url,options)=>{
    if(String(url).startsWith('https://api.cloudinary.com/')) {
      if(String(url).endsWith('/destroy')) {attempts.push(options.body.get('public_id')); if(failDelete) return new Response('',{status:503}); return Response.json({result:'ok'});}
      assert.equal(options.body.get('type'),'authenticated');
      assert.equal(options.body.get('overwrite'),'false');
      return Response.json({public_id:options.body.get('public_id'),resource_type:'image',format:'jpg',version:1,bytes:4});
    }
    if(String(url)==='https://worker.test/bookings/delete') return Response.json({ok:true});
    throw Error('Unexpected network request');
  });
  const data={venueId,size:12};
  for(const uid of [null,other,blocked]) await assert.rejects(call('reserveBookingVideo',uid,data));
  await assert.rejects(call('reserveBookingVideo',owner,{...data,size:50*1024*1024+1}));
  const image=await call('uploadBookingImage',owner,{venueId,base64:Buffer.from([255,216,255,0]).toString('base64')});
  let m=(await db.doc(`booking_media_reviews/${image.mediaId}`).get()).data();
  assert.equal(m.ownerUid,owner); assert.equal(m.status,'pending'); assert.equal(m.provider,'cloudinary');
  await assert.rejects(call('reviewBookingExternalMedia',owner,{mediaId:image.mediaId,approved:true}));
  await assert.rejects(call('reviewBookingExternalMedia',admin,{mediaId:image.mediaId,approved:'true'}));
  await call('reviewBookingExternalMedia',admin,{mediaId:image.mediaId,approved:true});
  assert.deepEqual((await db.doc(`booking_venues/${venueId}`).get()).data().mediaPaths,[image.path]);
  await assert.rejects(call('removeBookingExternalMedia',other,{venueId,path:image.path}));
  await call('removeBookingExternalMedia',owner,{venueId,path:image.path});
  failDelete=true; await f.cleanupBookingExternalMedia.run({});
  m=(await db.doc(`booking_media_reviews/${image.mediaId}`).get()).data();
  assert.equal(m.status,'delete_pending'); assert.equal(m.attempts,1);
  await db.doc(`booking_media_reviews/${image.mediaId}`).update({nextAttemptAt:0}); failDelete=false;
  // Reference safety: home banners can reference an approved URL; do not delete it.
  await db.doc(`banners/${prefix}`).set({imageUrl:image.path});
  await f.cleanupBookingExternalMedia.run({}); assert.equal((await db.doc(`booking_media_reviews/${image.mediaId}`).get()).data().status,'delete_pending');
  await db.doc(`banners/${prefix}`).delete(); await f.cleanupBookingExternalMedia.run({});
  assert.equal((await db.doc(`booking_media_reviews/${image.mediaId}`).get()).data().status,'deleted');
  const upload=()=>call('uploadBookingImage',admin,{kind:'banner',venueId,base64:Buffer.from([255,216,255,0]).toString('base64')});
  const first=await upload(), second=await upload();
  const banner={title:'farm',subtitle:'banner',type:'farm',targetId:venueId,isActive:true,order:1};
  const b=await call('saveBookingBanner',admin,{banner,mediaId:first.mediaId});
  await assert.rejects(call('saveBookingBanner',admin,{banner,mediaId:first.mediaId}));
  await call('saveBookingBanner',admin,{bannerId:b.id,banner,mediaId:second.mediaId});
  assert.equal((await db.doc(`booking_media_reviews/${first.mediaId}`).get()).data().status,'delete_pending');
  await call('deleteBookingBanner',admin,{bannerId:b.id});
  assert.equal((await db.doc(`booking_media_reviews/${second.mediaId}`).get()).data().status,'delete_pending');
  await f.cleanupBookingExternalMedia.run({});
  // Concurrent reservations cannot pass the 30-file limit.
  for(let i=0;i<28;i++) await call('reserveBookingVideo',owner,data);
  const reservations=await Promise.allSettled(Array.from({length:4},()=>call('reserveBookingVideo',owner,data)));
  assert.equal(reservations.filter(r=>r.status==='fulfilled').length,2);
  const granted=reservations.find(r=>r.status==='fulfilled').value;
  await db.doc(`booking_media_reviews/${granted.mediaId}`).update({expiresAt:0});
  await f.cleanupBookingExternalMedia.run({});
  assert.equal((await db.doc(`booking_media_reviews/${granted.mediaId}`).get()).data().status,'deleted');
  await db.doc(`booking_venues/${venueId}`).update({ownerId:other});
  await assert.rejects(call('reserveBookingVideo',owner,data));
  // Firebase legacy files are never selected for automatic orphan cleanup.
  await db.doc(`booking_media_reviews/${prefix}_legacy`).set({venueId,ownerId:owner,path:`booking_media/${venueId}/${owner}/old.jpg`,status:'pending',expiresAt:0});
  await f.cleanupBookingExternalMedia.run({});
  assert.equal((await db.doc(`booking_media_reviews/${prefix}_legacy`).get()).data().status,'pending');
});

test('video bridge verifies token, secret, ownership, one-shot claim and deletion references',async t=>{
  const uid='bridge_owner',venueId='bridge_venue';
  await db.doc(`users/${uid}`).set({isBlocked:false});
  await db.doc(`booking_venues/${venueId}`).set({ownerId:uid,active:true,mediaPaths:[]});
  const grant=await call('reserveBookingVideo',uid,{venueId,size:12});
  t.mock.method(getAuth(),'verifyIdToken',async(token,revoked)=>{assert.equal(revoked,true); if(token!=='valid') throw Error('invalid'); return {uid,firebase:{sign_in_provider:'password'}};});
  async function bridge(action,extra={},secret='test-worker-secret',token='valid') {
    let status=200,value;
    const res={status(code){status=code;return this;},json(body){value=body;return this;},sendStatus(code){status=code;return this;}};
    await f.bookingVideoBridge({method:'POST',headers:{'x-booking-worker-secret':secret,authorization:`Bearer ${token}`},body:{mediaId:grant.mediaId,action,...extra}},res);
    return {status,value};
  }
  assert.equal((await bridge('claim',{},'wrong')).status,403);
  assert.equal((await bridge('claim',{},undefined,'invalid')).status,403);
  assert.equal((await bridge('claim')).status,200);
  assert.equal((await bridge('claim')).status,403);
  assert.equal((await bridge('finish',{size:13})).status,403);
  assert.equal((await bridge('finish',{size:12})).status,200);
  assert.equal((await bridge('delete')).status,403);
  await db.doc(`booking_media_reviews/${grant.mediaId}`).update({status:'delete_pending'});
  await db.doc(`booking_venues/${venueId}`).update({mediaPaths:[grant.path]});
  assert.equal((await bridge('delete')).status,403);
  await db.doc(`booking_venues/${venueId}`).update({mediaPaths:[]});
  assert.equal((await bridge('delete')).status,200);
  await db.doc(`booking_media_reviews/${grant.mediaId}`).update({key:'reels/original/unsafe.mp4'});
  assert.equal((await bridge('delete')).status,403);
});

test('image gateway gates pending, inactive, blocked-owner and removed assets',async t=>{
  const owner='proxy_owner',venueId='proxy_venue',mediaId='proxy-media';
  await db.doc(`users/${owner}`).set({isBlocked:false});
  await db.doc(`booking_venues/${venueId}`).set({ownerId:owner,active:true});
  const mRef=db.doc(`booking_media_reviews/${mediaId}`);
  await mRef.set({schemaVersion:2,kind:'venue',provider:'cloudinary',resource_type:'image',public_id:`bookings/${venueId}/${owner}/${mediaId}`,ownerUid:owner,ownerId:owner,venueId,status:'pending',format:'jpg',version:1,type:'image/jpeg'});
  t.mock.method(getAuth(),'verifyIdToken',async token=>{if(token!=='owner-token')throw Error('invalid');return {uid:owner,firebase:{sign_in_provider:'password'}};});
  t.mock.method(globalThis,'fetch',async url=>{assert.ok(String(url).startsWith('https://res.cloudinary.com/'));return new Response(new Uint8Array([255,216,255,0]));});
  async function read(token) {
    let status=200;
    const res={set(){return this;},type(){return this;},send(){return this;},sendStatus(code){status=code;return this;}};
    await f.bookingImage({method:'GET',headers:token?{authorization:`Bearer ${token}`}:{},query:{mediaId}},res);
    return status;
  }
  assert.equal(await read(),403); assert.equal(await read('invalid'),403);
  assert.equal(await read('owner-token'),200);
  await mRef.update({status:'approved'}); assert.equal(await read(),200);
  await db.doc(`booking_venues/${venueId}`).update({active:false}); assert.equal(await read(),403);
  await db.doc(`booking_venues/${venueId}`).update({active:true});
  await db.doc(`users/${owner}`).update({isBlocked:true}); assert.equal(await read(),403);
  await db.doc(`users/${owner}`).update({isBlocked:false});
  await mRef.update({status:'delete_pending'}); assert.equal(await read('owner-token'),403);
});
