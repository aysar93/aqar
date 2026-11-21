// Read-only compatibility for pre-Firebase booking images. Never uploads or deletes.
const {onRequest, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret, defineString} = require('firebase-functions/params');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {createHash} = require('node:crypto');
const {LIMITS, validId, canRead} = require('./booking_media_policy');
const cloud = defineString('BOOKING_CLOUDINARY_CLOUD_NAME');
const apiKey = defineSecret('BOOKING_CLOUDINARY_API_KEY');
const apiSecret = defineSecret('BOOKING_CLOUDINARY_API_SECRET');
const db = getFirestore();
const ref = id => db.doc(`booking_media_reviews/${validId(id)}`);
const error = message => { throw new HttpsError('failed-precondition', message); };
async function bridgeAuth(req) {
  const token=String(req.headers.authorization||'').replace(/^Bearer /,'');
  const auth=await getAuth().verifyIdToken(token,true);
  return {auth:{uid:auth.uid,token:auth}};
}
async function readable(mediaId, req) {
  const m=(await ref(mediaId).get()).data();
  const v=m?.kind==='venue'?(await db.doc(`booking_venues/${m.venueId}`).get()).data():null;
  let uid, u;
  if(req.headers.authorization) { const a=await bridgeAuth(req); uid=a.auth.uid; u=(await db.doc(`users/${uid}`).get()).data(); }
  if(m?.kind==='banner' && m.status==='approved') {
    const banners=await db.collection('booking_banners').where('mediaId','==',mediaId).get();
    if(banners.docs.some(d=>d.data().isActive===true)) return m;
  }
  const owner=m?.kind==='venue'?(await db.doc(`users/${m.ownerUid}`).get()).data():null;
  if(m?.kind==='venue' && (!owner || owner.isBlocked) && !(u?.isAdmin===true && !u?.isBlocked)) error('media_unavailable');
  if(!canRead(m,v,u,uid)) error('media_unavailable');
  return m;
}
exports.bookingImage = onRequest({secrets:[apiKey,apiSecret],timeoutSeconds:120},async(req,res)=>{
  res.set('Cache-Control','private, no-store'); res.set('Access-Control-Allow-Origin','*'); res.set('Access-Control-Allow-Headers','Authorization');
  if(req.method==='OPTIONS') return res.sendStatus(204);
  try {
    if(req.method!=='GET') return res.sendStatus(405);
    const m=await readable(validId(req.query.mediaId),req);
    if(m.provider!=='cloudinary' || m.resource_type!=='image' || m.public_id!==`bookings/${m.venueId}/${m.ownerUid}/${validId(req.query.mediaId)}` || !['jpg','png'].includes(m.format)) return res.sendStatus(404);
    const toSign=`${m.public_id}.${m.format}`;
    const sig=createHash('sha1').update(toSign+apiSecret.value()).digest('base64url').slice(0,8);
    const url=`https://res.cloudinary.com/${encodeURIComponent(cloud.value())}/image/authenticated/s--${sig}--/v${m.version}/${toSign}`;
    const response=await fetch(url,{signal:AbortSignal.timeout(90000)});
    if(!response.ok) return res.sendStatus(502);
    const bytes=Buffer.from(await response.arrayBuffer());
    if(bytes.length>LIMITS.image) return res.sendStatus(502);
    res.type(m.type).send(bytes);
  } catch (_) { res.sendStatus(403); }
});
