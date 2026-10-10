// Booking-only lifecycle. Provider identifiers and secrets never come from clients.
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');

const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {randomUUID} = require('node:crypto');
const sharp = require('sharp');
const {LIMITS, validId, imageBytes} = require('./booking_media_policy');
const db = getFirestore();
const ref = id => db.doc(`booking_media_reviews/${validId(id)}`);
const error = message => { throw new HttpsError('failed-precondition', message); };
async function actor(r, tx) {
  if (!r.auth || r.auth.token?.firebase?.sign_in_provider === 'anonymous') throw new HttpsError('unauthenticated','سجل الدخول');
  const u = (await tx.get(db.doc(`users/${r.auth.uid}`))).data();
  if (!u || u.isBlocked) throw new HttpsError('permission-denied','الحساب غير متاح');
  return {...u, uid:r.auth.uid};
}
async function reserve(r, type, size) {
  const kind = r.data.kind === 'banner' ? 'banner' : 'venue';
  const venueId = kind === 'venue' || r.data.venueId ? validId(r.data.venueId) : 'banners';
  const mediaId = randomUUID();
  const extension = type === 'video/mp4' ? 'mp4' : type === 'image/png' ? 'png' : 'jpg';
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
    const path = `booking_media_v3/${venueId}/${ownerUid}/${mediaId}.${extension}`;
    tx.create(ref(mediaId),{schemaVersion:3,kind,venueId,ownerUid,ownerId:ownerUid,provider:'firebase',path,type,status:'uploading',size,createdAt:FieldValue.serverTimestamp(),expiresAt:Date.now()+24*3600000,attempts:0});
  });
  return {mediaId,path:(await ref(mediaId).get()).data().path};
}
exports.uploadBookingImage = onCall({timeoutSeconds:300,memory:'512MiB'},async r=>{
  await actor(r,{get:reference=>reference.get()});
  let file;
  try {
    const source=imageBytes(r.data.base64);
    // Decode and re-encode, matching the validation Cloudinary previously supplied.
    // Pixel bound also prevents compressed decompression bombs; strip metadata.
    const bytes=await sharp(source.bytes,{limitInputPixels:40000000,failOn:'warning'})
      .rotate().resize({width:2560,height:2560,fit:'inside',withoutEnlargement:true})
      .jpeg({quality:80}).toBuffer();
    if(!bytes.length || bytes.length>LIMITS.image) throw Error('image_limit');
    file={bytes,type:'image/jpeg'};
  } catch (_) { error('صورة أو حجم غير صالح'); }
  const result = await reserve(r,file.type,file.bytes.length);
  // No download tokens or public ACLs. Client uploads to this image namespace are denied.
  await getStorage().bucket().file(result.path).save(file.bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:file.type,cacheControl:'private, no-store'}});
  await finish(r,result.mediaId);
  return result;
});
exports.reserveBookingVideo = onCall(async r=>{
  if(r.data.kind==='banner' || !Number.isSafeInteger(r.data.size) || r.data.size<12 || r.data.size>LIMITS.video) error('حجم فيديو غير صالح');
  return reserve(r,'video/mp4',r.data.size);
});
async function finish(r,mediaId) {
  const mRef=ref(mediaId), m=(await mRef.get()).data();
  if(!m || m.provider!=='firebase' || m.status!=='uploading' || m.expiresAt<Date.now() || m.ownerUid!==r.auth?.uid || !canonical(m,mediaId)) error('ملف غير صالح');
  const file=getStorage().bucket().file(m.path), [meta]=await file.getMetadata();
  if(Number(meta.size)!==m.size || meta.contentType!==m.type) error('حجم أو نوع غير صالح');
  const [head]=await file.download({start:0,end:11});
  if(m.type==='video/mp4' && (head.length<12 || head.toString('ascii',4,8)!=='ftyp')) error('فيديو MP4 غير صالح');
  // Remove any Firebase download token introduced by a client SDK upload.
  await file.setMetadata({cacheControl:'private, no-store',metadata:{firebaseStorageDownloadTokens:null}});
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), current=(await tx.get(mRef)).data();
    const v=m.kind==='venue'?(await tx.get(db.doc(`booking_venues/${m.venueId}`))).data():null;
    if(current.status!=='uploading' || current.expiresAt<Date.now() || (m.kind==='venue'?v?.ownerId!==u.uid:u.isAdmin!==true)) error('تغيرت الصلاحيات');
    tx.update(mRef,{status:'pending',generation:String(meta.generation)});
  });
}
exports.finishBookingVideo = onCall(async r=>{await finish(r,validId(r.data.mediaId));return {ok:true};});
function canonical(m,id) {
  const extension={'image/jpeg':'jpg','image/png':'png','video/mp4':'mp4'}[m.type];
  return extension && m.path===`booking_media_v3/${validId(m.venueId)}/${validId(m.ownerUid)}/${validId(id)}.${extension}`;
}
exports.reviewBookingExternalMedia = onCall(async r=>{
  const mRef=ref(r.data.mediaId);
  if(typeof r.data.approved!=='boolean') error('قرار غير صالح');
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), m=(await tx.get(mRef)).data();
    if(!m || ![2,3].includes(m.schemaVersion) || m.status!=='pending' || u.isAdmin!==true || u.uid===m.ownerUid) error('مراجعة إدارية مستقلة مطلوبة');
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
    if(![2,3].includes(m.schemaVersion) || m.kind!=='venue' || m.venueId!==r.data.venueId || !v || v.ownerId!==u.uid && u.isAdmin!==true) error('للمالك أو الإدارة فقط');
    if(m.status==='deleted') return;
    tx.update(vRef,{mediaPaths:FieldValue.arrayRemove(m.path)});
    tx.update(doc.ref,{status:'delete_pending',nextAttemptAt:m.status==='uploading'?m.expiresAt:0,removedBy:u.uid,removedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId:m.venueId,actorUid:u.uid,action:'removeExternalMedia',mediaId:doc.id,createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true,deletionQueued:true};
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
  if(m.provider!=='firebase' || m.schemaVersion!==3 || !canonical(m,doc.id)) error('legacy_asset_retained');
  const file=getStorage().bucket().file(m.path);
  // Generation protects against deleting a replaced object, including abandoned uploads.
  const [exists]=await file.exists();
  if(exists) {const [meta]=await file.getMetadata(); await file.delete({ifGenerationMatch:m.generation || meta.generation,ignoreNotFound:true});}
  await doc.ref.update({status:'deleted',deletedAt:FieldValue.serverTimestamp(),lastError:FieldValue.delete()});
}
exports.cleanupBookingExternalMedia = onSchedule({schedule:'every 60 minutes',timeoutSeconds:540},async()=>{
  // External v2 assets are retained. Firebase v3 reservations cover every upload, including orphans.
  await cleanupLegacy();
  const docs=await db.collection('booking_media_reviews').where('schemaVersion','==',3).get();
  let processed=0; const deadline=Date.now()+420000;
  for(const doc of docs.docs) {
    let m=doc.data();
    if(['uploading','pending'].includes(m.status) && m.expiresAt<Date.now()) {
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
