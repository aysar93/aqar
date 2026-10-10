// Booking-only lifecycle. Provider identifiers and secrets never come from clients.
const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineSecret, defineString} = require('firebase-functions/params');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {getStorage} = require('firebase-admin/storage');
const {createHash, randomUUID, timingSafeEqual} = require('node:crypto');
const {LIMITS, validId, imageBytes, canRead, canDeleteKey} = require('./booking_media_policy');
const cloud = defineString('BOOKING_CLOUDINARY_CLOUD_NAME');
const apiKey = defineSecret('BOOKING_CLOUDINARY_API_KEY');
const apiSecret = defineSecret('BOOKING_CLOUDINARY_API_SECRET');
const workerSecret = defineSecret('BOOKING_WORKER_SECRET');
const mediaBase = defineString('BOOKING_IMAGE_PROXY_URL');
const workerBase = defineString('BOOKING_WORKER_URL');
const secrets = [apiKey, apiSecret, workerSecret];
const db = getFirestore();
const ref = id => db.doc(`booking_media_reviews/${validId(id)}`);
const error = message => { throw new HttpsError('failed-precondition', message); };
async function actor(r, tx) {
  if (!r.auth || r.auth.token?.firebase?.sign_in_provider === 'anonymous') throw new HttpsError('unauthenticated','سجل الدخول');
  const u = (await tx.get(db.doc(`users/${r.auth.uid}`))).data();
  if (!u || u.isBlocked) throw new HttpsError('permission-denied','الحساب غير متاح');
  return {...u, uid:r.auth.uid};
}
function base(value) { const u = new URL(value); if (u.protocol !== 'https:' || u.search || u.hash) error('إعداد الخدمة غير صالح'); return value.replace(/\/$/,''); }
function signature(values) {
  const plain = Object.keys(values).sort().map(k=>`${k}=${values[k]}`).join('&');
  return createHash('sha1').update(plain + apiSecret.value()).digest('hex');
}
async function cloudAction(action, values, file) {
  const fields = {...values, timestamp:Math.floor(Date.now()/1000)};
  const form = new FormData();
  for (const [k,v] of Object.entries(fields)) form.set(k,String(v));
  form.set('signature',signature(fields)); form.set('api_key',apiKey.value());
  if (file) form.set('file',new Blob([file.bytes],{type:file.type}),'image');
  const response = await fetch(`https://api.cloudinary.com/v1_1/${encodeURIComponent(cloud.value())}/image/${action}`,{method:'POST',body:form,signal:AbortSignal.timeout(120000)});
  if (!response.ok) error('تعذر الاتصال بخدمة الصور');
  return response.json();
}
async function reserve(r, provider, size) {
  const kind = r.data.kind === 'banner' ? 'banner' : 'venue';
  const venueId = kind === 'venue' || r.data.venueId ? validId(r.data.venueId) : 'banners';
  const mediaId = randomUUID();
  const path = provider === 'r2' ? `${base(workerBase.value())}/bookings/media/${mediaId}.mp4` : `${base(mediaBase.value())}?mediaId=${mediaId}`;
  await db.runTransaction(async tx=>{
    const u = await actor(r,tx);
    const v = kind === 'venue' ? (await tx.get(db.doc(`booking_venues/${venueId}`))).data() : null;
    if (kind === 'banner' ? u.isAdmin !== true : !v || v.ownerId !== u.uid) error('صلاحية المالك أو الإدارة مطلوبة');
    const ownerUid = kind === 'venue' ? v.ownerId : u.uid;
    const records = await tx.get(db.collection('booking_media_reviews').where('venueId','==',venueId));
    const rateRef = db.doc(`booking_media_limits/${u.uid}_${new Date().toISOString().slice(0,10)}`);
    const rate = (await tx.get(rateRef)).data() || {};
    if (records.docs.filter(d=>!['deleted','removed'].includes(d.data().status)).length >= (kind==='banner'?200:LIMITS.files) || (rate.files||0)>=LIMITS.dailyFiles || (rate.bytes||0)+size>LIMITS.dailyBytes) error('تجاوز حصة الوسائط');
    tx.set(rateRef,{files:(rate.files||0)+1,bytes:(rate.bytes||0)+size});
    tx.create(ref(mediaId),{schemaVersion:2,kind,venueId,ownerUid,ownerId:ownerUid,provider,path,type:provider==='r2'?'video/mp4':'image/jpeg',resource_type:'image',public_id:provider==='cloudinary'?`bookings/${venueId}/${ownerUid}/${mediaId}`:null,key:provider==='r2'?`bookings/venues/${venueId}/${ownerUid}/${mediaId}.mp4`:null,status:'uploading',size,createdAt:FieldValue.serverTimestamp(),expiresAt:Date.now()+24*3600000,attempts:0});
  });
  return {mediaId,path};
}
exports.uploadBookingImage = onCall({secrets,timeoutSeconds:300,memory:'512MiB'},async r=>{
  let file; try { file=imageBytes(r.data.base64); } catch (_) { error('صورة أو حجم غير صالح'); }
  const result = await reserve(r,'cloudinary',file.bytes.length);
  const m = (await ref(result.mediaId).get()).data();
  // Fixed identifier, authenticated delivery, no overwrite, no unsigned preset.
  const uploaded = await cloudAction('upload',{public_id:m.public_id,type:'authenticated',overwrite:false},file);
  if (uploaded.public_id!==m.public_id || uploaded.resource_type!=='image' || !['jpg','png'].includes(uploaded.format) || !Number.isSafeInteger(uploaded.bytes) || uploaded.bytes<=0 || uploaded.bytes>LIMITS.image) error('استجابة خدمة الصور غير صالحة');
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), current=(await tx.get(ref(result.mediaId))).data();
    const v=m.kind==='venue'?(await tx.get(db.doc(`booking_venues/${m.venueId}`))).data():null;
    if(current.status!=='uploading' || (m.kind==='venue'?v?.ownerId!==u.uid:u.isAdmin!==true)) error('تغيرت الصلاحيات');
    tx.update(ref(result.mediaId),{status:'pending',format:uploaded.format,version:uploaded.version,type:file.type,size:uploaded.bytes});
  });
  return result;
});
exports.reserveBookingVideo = onCall({secrets:[workerSecret]},async r=>{
  if(r.data.kind==='banner' || !Number.isSafeInteger(r.data.size) || r.data.size<12 || r.data.size>LIMITS.video) error('حجم فيديو غير صالح');
  return reserve(r,'r2',r.data.size);
});
function shared(value) {
  const a=Buffer.from(String(value||'')), b=Buffer.from(workerSecret.value());
  if(!b.length || a.length!==b.length || !timingSafeEqual(a,b)) throw new HttpsError('permission-denied','worker_required');
}
async function bridgeAuth(req) {
  const token=String(req.headers.authorization||'').replace(/^Bearer /,'');
  const auth=await getAuth().verifyIdToken(token,true);
  return {auth:{uid:auth.uid,token:auth}};
}
exports.bookingVideoBridge = onRequest({secrets:[workerSecret]},async (req,res)=>{
  try {
    shared(req.headers['x-booking-worker-secret']);
    if(req.method!=='POST') return res.sendStatus(405);
    const mediaId=validId(req.body.mediaId), mRef=ref(mediaId);
    if(req.body.action==='delete') {
      // Called only by the server deletion queue; recheck all references before R2 mutation.
      const m=(await mRef.get()).data();
      if(!m || !canDeleteKey(m,mediaId) || await referenced(m)) error('referenced_or_invalid');
      return res.json({key:m.key});
    }
    const r=await bridgeAuth(req);
    let result;
    await db.runTransaction(async tx=>{
      const u=await actor(r,tx), m=(await tx.get(mRef)).data();
      if(!m || m.provider!=='r2' || m.ownerUid!==u.uid || m.expiresAt<Date.now()) error('invalid_upload');
      const v=(await tx.get(db.doc(`booking_venues/${m.venueId}`))).data();
      if(!v || v.ownerId!==u.uid) error('ownership_changed');
      if(req.body.action==='claim' && m.status==='uploading' && !m.claimedAt) tx.update(mRef,{claimedAt:Date.now()});
      else if(req.body.action==='finish' && m.status==='uploading' && m.claimedAt && req.body.size===m.size) tx.update(mRef,{status:'pending'});
      else error('invalid_upload_state');
      result={key:m.key,size:m.size,path:m.path};
    });
    res.json(result);
  } catch (_) { res.status(403).json({error:'booking_media_denied'}); }
});
exports.reviewBookingExternalMedia = onCall(async r=>{
  const mRef=ref(r.data.mediaId);
  if(typeof r.data.approved!=='boolean') error('قرار غير صالح');
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), m=(await tx.get(mRef)).data();
    if(!m || m.schemaVersion!==2 || m.status!=='pending' || u.isAdmin!==true || u.uid===m.ownerUid) error('مراجعة إدارية مستقلة مطلوبة');
    const vRef=db.doc(`booking_venues/${m.venueId}`), v=m.kind==='venue'?(await tx.get(vRef)).data():null;
    const owner=(await tx.get(db.doc(`users/${m.ownerUid}`))).data();
    if(r.data.approved && (!owner || owner.isBlocked)) error('المالك غير متاح');
    if(m.kind==='venue' && (!v || v.ownerId!==m.ownerUid || (v.mediaPaths||[]).length>=20 && r.data.approved)) error('تغير المالك أو تجاوز حد الملفات');
    tx.update(mRef,{status:r.data.approved?'approved':'delete_pending',reviewedBy:u.uid,reviewedAt:FieldValue.serverTimestamp()});
    if(m.kind==='venue' && r.data.approved) tx.update(vRef,{mediaPaths:FieldValue.arrayUnion(m.path)});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId:m.venueId,actorUid:u.uid,action:'reviewExternalMedia',mediaId:mRef.id,approved:r.data.approved,createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true};
});
exports.removeBookingExternalMedia = onCall(async r=>{
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), records=await tx.get(db.collection('booking_media_reviews').where('path','==',r.data.path));
    if(records.size!==1) error('ملف غير صالح');
    const doc=records.docs[0], m=doc.data();
    const vRef=db.doc(`booking_venues/${validId(m.venueId)}`), v=(await tx.get(vRef)).data();
    if(m.schemaVersion!==2 || m.kind!=='venue' || m.venueId!==r.data.venueId || !v || v.ownerId!==u.uid && u.isAdmin!==true) error('للمالك أو الإدارة فقط');
    if(m.status==='deleted') return;
    tx.update(vRef,{mediaPaths:FieldValue.arrayRemove(m.path)});
    tx.update(doc.ref,{status:'delete_pending',nextAttemptAt:m.status==='uploading'?m.expiresAt:0,removedBy:u.uid,removedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId:m.venueId,actorUid:u.uid,action:'removeExternalMedia',mediaId:doc.id,createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true,deletionQueued:true};
});
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
async function referenced(m) {
  const [venues,banners,reels,other,home,properties,propertyImages]=await Promise.all([
    db.collection('booking_venues').where('mediaPaths','array-contains',m.path).get(),
    db.collection('booking_banners').where('imageUrl','==',m.path).get(),
    db.collection('reels').get(),db.collection('booking_media_reviews').where('path','==',m.path).get(),
    db.collection('banners').where('imageUrl','==',m.path).get(),
    db.collection('properties').where('imageUrl','==',m.path).get(),
    db.collection('properties').where('images','array-contains',m.path).get()
  ]);
  return !venues.empty || !banners.empty || !home.empty || !properties.empty || !propertyImages.empty || reels.docs.some(d=>JSON.stringify(d.data()).includes(m.path) || m.key && JSON.stringify(d.data()).includes(m.key)) || other.docs.some(d=>!['delete_pending','deleted','removed'].includes(d.data().status));
}
async function clean(doc) {
  const m=doc.data();
  if(await referenced(m)) return;
  if(m.provider==='cloudinary') {
    if(m.public_id!==`bookings/${m.venueId}/${m.ownerUid}/${doc.id}` || m.resource_type!=='image') error('invalid_asset');
    const result=await cloudAction('destroy',{public_id:m.public_id,type:'authenticated',invalidate:true});
    if(!['ok','not found'].includes(result.result)) error('delete_failed');
  } else if(m.provider==='r2') {
    const response=await fetch(`${base(workerBase.value())}/bookings/delete`,{method:'POST',headers:{'content-type':'application/json','x-booking-worker-secret':workerSecret.value()},body:JSON.stringify({mediaId:doc.id}),signal:AbortSignal.timeout(120000)});
    if(!response.ok) error('delete_failed');
  } else error('unknown_provider');
  await doc.ref.update({status:'deleted',deletedAt:FieldValue.serverTimestamp(),lastError:FieldValue.delete()});
}
exports.cleanupBookingExternalMedia = onSchedule({schedule:'every 60 minutes',secrets,timeoutSeconds:540},async()=>{
  // Legacy Firebase rows are deliberately excluded; no migration deletes.
  await cleanupLegacy();
  const docs=await db.collection('booking_media_reviews').where('schemaVersion','==',2).get();
  let processed=0; const deadline=Date.now()+420000;
  for(const doc of docs.docs) {
    let m=doc.data();
    if(['uploading','pending'].includes(m.status) && m.expiresAt<Date.now() && (m.status==='uploading' || m.kind==='banner')) {
      await db.runTransaction(async tx=>{const fresh=(await tx.get(doc.ref)).data(); if(fresh.status===m.status && fresh.expiresAt<Date.now()) tx.update(doc.ref,{status:'delete_pending'});});
      m=(await doc.ref.get()).data();
    }
    if(m.status!=='delete_pending' || (m.nextAttemptAt||0)>Date.now()) continue;
    if(++processed>50 || Date.now()>deadline) break;
    try {await clean(await doc.ref.get());}
    catch (_) { const attempts=(m.attempts||0)+1; await doc.ref.update({attempts,lastError:'provider_delete_failed',nextAttemptAt:Date.now()+Math.min(24*3600000,60000*2**Math.min(attempts,10))}); }
  }
});
exports.saveBookingBanner = onCall(async r=>{
  const bannerId=r.data.bannerId?validId(r.data.bannerId):randomUUID(), bRef=db.doc(`booking_banners/${bannerId}`), d=r.data.banner;
  if(!d || !['chalet','hall','farm','external'].includes(d.type) || typeof d.targetId!=='string' || typeof d.title!=='string' || d.title.length>200 || typeof d.subtitle!=='string' || d.subtitle.length>1000 || typeof d.isActive!=='boolean' || !Number.isSafeInteger(d.order)) error('بنر غير صالح');
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx); if(u.isAdmin!==true) error('للإدارة فقط');
    const old=(await tx.get(bRef)).data();
    const mediaId=r.data.mediaId || old?.mediaId;
    const mRef=mediaId?ref(mediaId):null, m=mRef?(await tx.get(mRef)).data():null;
    const oldRef=old?.mediaId && old.mediaId!==mediaId?ref(old.mediaId):null;
    if(oldRef) await tx.get(oldRef);
    if(d.type==='external') {let target; try {target=new URL(d.targetId);} catch (_) {error('رابط غير صالح');} if(target.protocol!=='https:') error('رابط غير صالح');}
    else {const v=(await tx.get(db.doc(`booking_venues/${validId(d.targetId)}`))).data(); if(!v || v.category!==d.type) error('مكان غير صالح');}
    if(m && m.venueId!== (d.type==='external'?'banners':d.targetId)) error('الصورة مخصصة لوجهة أخرى');
    if(m && m.bannerId && m.bannerId!==bannerId) error('الملف مرتبط ببنر آخر');
    if(m && (m.kind!=='banner' || !['pending','approved'].includes(m.status) || m.expiresAt<Date.now() && m.status==='pending')) error('وسيط بنر غير صالح');
    if(mediaId && !m) error('ملف غير موجود');
    if(!m && !old) error('صورة البنر مطلوبة');
    tx.set(bRef,{title:d.title,subtitle:d.subtitle,type:d.type,targetId:d.targetId,isActive:d.isActive,order:d.order,imageUrl:m?m.path:old.imageUrl,...(mediaId?{mediaId}:{}),createdAt:old?.createdAt||FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    if(m) tx.update(mRef,{status:'approved',reviewedBy:u.uid,reviewedAt:FieldValue.serverTimestamp(),bannerId});
    if(oldRef) tx.update(oldRef,{status:'delete_pending'});
    if(old && !old.mediaId && m) tx.create(db.collection('booking_legacy_media_retained').doc(),{bannerId,imageUrl:old.imageUrl,reason:'replaced_legacy_banner',retainedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId:'banners',actorUid:u.uid,action:'saveBanner',bannerId,createdAt:FieldValue.serverTimestamp()});
  }); return {id:bannerId};
});
exports.deleteBookingBanner = onCall(async r=>{
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx); if(u.isAdmin!==true) error('للإدارة فقط');
    const bRef=db.doc(`booking_banners/${validId(r.data.bannerId)}`), b=(await tx.get(bRef)).data();
    const mRef=b?.mediaId?ref(b.mediaId):null; if(mRef) await tx.get(mRef);
    if(mRef) tx.update(mRef,{status:'delete_pending'});
    if(b && !b.mediaId) tx.create(db.collection('booking_legacy_media_retained').doc(),{bannerId:bRef.id,imageUrl:b.imageUrl,reason:'deleted_legacy_banner',retainedAt:FieldValue.serverTimestamp()});
    tx.delete(bRef);
    tx.create(db.collection('booking_venue_audit').doc(),{venueId:'banners',actorUid:u.uid,action:'deleteBanner',bannerId:bRef.id,legacyFileRetained:!mRef,createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true,deletionQueued:true};
});

async function cleanupLegacy() {
  const jobs=await db.collection('booking_legacy_media_deletions').where('status','==','pending').limit(50).get();
  for(const job of jobs.docs) {
    const d=job.data(); if((d.nextAttemptAt||0)>Date.now()) continue;
    try {
      if(!/^booking_media\/[^/]+\/[^/]+\/[A-Za-z0-9_-]+\.(jpg|png|mp4)$/.test(d.path)) error('invalid_legacy_path');
      const m=(await db.doc(`booking_media_reviews/${d.mediaId}`).get()).data();
      if(!m || m.status!=='removed' || m.path!==d.path || await referenced({...m,path:d.path})) continue;
      await getStorage().bucket().file(d.path).delete({ignoreNotFound:true});
      await job.ref.update({status:'done',completedAt:FieldValue.serverTimestamp()});
    } catch (_) {
      const attempts=(d.attempts||0)+1;
      await job.ref.update({attempts,lastError:'legacy_delete_failed',nextAttemptAt:Date.now()+Math.min(86400000,60000*2**Math.min(attempts,10))});
    }
  }
}
