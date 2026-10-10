const {test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185' || process.env.GCLOUD_PROJECT!=='demo-aqar') throw Error('Isolated demo emulator required');
process.env.BOOKING_CLOUDINARY_CLOUD_NAME='test-only';
process.env.BOOKING_CLOUDINARY_API_KEY='test-key';
process.env.BOOKING_CLOUDINARY_API_SECRET='test-secret';
initializeApp({projectId:'demo-aqar'});
const db=getFirestore(),f=require('./booking_legacy_external_media');
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
