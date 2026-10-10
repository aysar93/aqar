const {test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185' || process.env.GCLOUD_PROJECT!=='demo-aqar') throw Error('Isolated demo emulator required');
initializeApp({projectId:'demo-aqar',storageBucket:'demo-aqar.appspot.com'});
const {getStorage}=require('firebase-admin/storage');
const db=getFirestore(),f=require('./booking_external_media');
const call=(name,uid,data)=>f[name].run({auth:uid?{uid,token:{}}:null,data});
test('transactional quotas, ownership, image review, banner replacement and retry lifecycle',async t=>{
  const prefix=`media_${Date.now()}`,owner=prefix+'_owner',admin=prefix+'_admin',other=prefix+'_other',blocked=prefix+'_blocked',venueId=prefix+'_venue';
  for(const uid of [owner,admin,other,blocked]) await db.doc(`users/${uid}`).set({isAdmin:uid===admin,isBlocked:uid===blocked});
  await db.doc(`booking_venues/${venueId}`).set({ownerId:owner,active:true,category:'farm',mediaPaths:[]});
  const attempts=[]; let failDelete=false;
  const File=getStorage().bucket().file('test').constructor;
  const originalDelete=File.prototype.delete;
  t.mock.method(File.prototype,'delete',async function(options){attempts.push(this.name);if(failDelete)throw Error('retry');return originalDelete.call(this,options);});
  t.mock.method(globalThis,'fetch',async()=>{throw Error('External network forbidden');});
  const jpeg=await require('sharp')({create:{width:2,height:2,channels:3,background:'red'}}).jpeg().toBuffer();
  await assert.rejects(call('uploadBookingImage',owner,{venueId,base64:Buffer.from([255,216,255,0]).toString('base64')}));
  const data={venueId,size:12};
  for(const uid of [null,other,blocked]) await assert.rejects(call('reserveBookingVideo',uid,data));
  await assert.rejects(call('reserveBookingVideo',owner,{...data,size:50*1024*1024+1}));
  const image=await call('uploadBookingImage',owner,{venueId,base64:jpeg.toString('base64')});
  let m=(await db.doc(`booking_media_reviews/${image.mediaId}`).get()).data();
  assert.equal(m.ownerUid,owner); assert.equal(m.status,'pending'); assert.equal(m.provider,'firebase');
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
  const upload=()=>call('uploadBookingImage',admin,{kind:'banner',venueId,base64:jpeg.toString('base64')});
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
  await db.doc(`users/${admin}`).update({isAdmin:false});
});

test('Firebase video validates bytes, ownership, expiry and one-shot finalization',async t=>{
  const uid='video_owner',venueId='video_venue';
  await db.doc(`users/${uid}`).set({isBlocked:false});
  await db.doc(`booking_venues/${venueId}`).set({ownerId:uid,active:true,mediaPaths:[]});
  const grant=await call('reserveBookingVideo',uid,{venueId,size:12});
  const file=getStorage().bucket().file(grant.path);
  await file.save(Buffer.from('xxxxnotvideo!'),{resumable:false,metadata:{contentType:'video/mp4'}});
  await assert.rejects(call('finishBookingVideo',uid,{mediaId:grant.mediaId}));
  await file.save(Buffer.from([0,0,0,12,102,116,121,112,105,115,111,109]),{resumable:false,metadata:{contentType:'video/mp4',metadata:{firebaseStorageDownloadTokens:'unsafe-token'}}});
  // Storage emulator keeps downloadTokens separately and does not implement null removal.
  // Assert the production GCS metadata patch rather than accepting a retained token as safe.
  const originalMetadata=file.constructor.prototype.setMetadata;
  let revoked=false;
  t.mock.method(file.constructor.prototype,'setMetadata',async function(metadata,...args){
    if(this.name===grant.path) {assert.equal(metadata.metadata.firebaseStorageDownloadTokens,null);revoked=true;}
    return originalMetadata.call(this,metadata,...args);
  });
  await call('finishBookingVideo',uid,{mediaId:grant.mediaId});
  assert.equal(revoked,true);
  assert.equal((await db.doc(`booking_media_reviews/${grant.mediaId}`).get()).data().status,'pending');
  await assert.rejects(call('finishBookingVideo',uid,{mediaId:grant.mediaId}));
  const orphan=await call('reserveBookingVideo',uid,{venueId,size:12});
  await getStorage().bucket().file(orphan.path).save(Buffer.alloc(12),{resumable:false,metadata:{contentType:'video/mp4'}});
  await db.doc(`booking_media_reviews/${orphan.mediaId}`).update({expiresAt:0});
  await f.cleanupBookingExternalMedia.run({});
  assert.equal((await getStorage().bucket().file(orphan.path).exists())[0],false);
  const transferred=await call('reserveBookingVideo',uid,{venueId,size:12});
  await db.doc(`booking_venues/${venueId}`).update({ownerId:'other'});
  await assert.rejects(call('finishBookingVideo',uid,{mediaId:transferred.mediaId}));
});
