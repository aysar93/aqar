const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {createHash, randomBytes} = require('node:crypto');
const {overlaps, blocks, money, pricingConfig, quote, cancellationPolicy, refund} = require('./booking_policy');
const db = getFirestore();
const {CONFIG, available, recipient} = require('./payment_accounts');
function policy(fn) { try { return fn(); } catch(e) { fail(e.message); } }
function finance(u) { return u.canReviewBookingPayments === true; }
function nextVersion(b) { return Number.isSafeInteger(b.version) && b.version >= 0 ? b.version + 1 : 1; }
exports.getBookingPaymentAccounts = onCall(async r => { await actor(r); return available((await db.doc(CONFIG).get()).data()); });
exports.setBookingPaymentReviewer = onCall(async r => {
  const uid = id(r.data.userId), ref = db.doc(`users/${uid}`);
  await db.runTransaction(async tx => {
    const u = await actor(r, tx);
    if (u.isAdmin !== true) throw new HttpsError('permission-denied','للإدارة فقط');
    const target = (await tx.get(ref)).data();
    if (!target || typeof r.data.enabled !== 'boolean' || r.data.enabled && target.isBlocked) fail('حساب غير صالح');
    if (uid === u.uid) fail('لا يمكن منح أو تعديل صلاحيتك المالية بنفسك');
    tx.update(ref,{canReviewBookingPayments:r.data.enabled,bookingFinanceGrantedBy:u.uid,bookingFinanceUpdatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('booking_finance_audit').doc(), {actorUid:u.uid,targetUid:uid,before:target.canReviewBookingPayments === true,after:r.data.enabled,createdAt:FieldValue.serverTimestamp()});
  });
  return {ok:true};
});
function fail(message) { throw new HttpsError('failed-precondition', message); }
function text(v, max = 1000) { if (typeof v !== 'string' || !v.trim() || v.length > max) fail('بيانات غير مكتملة'); return v.trim(); }
function id(v) { const s = text(v, 128); if (s.includes('/')) fail('معرف غير صالح'); return s; }
async function actor(request, tx) {
  if (!request.auth || request.auth.token?.firebase?.sign_in_provider === 'anonymous') throw new HttpsError('unauthenticated', 'سجل الدخول');
  const ref = db.doc(`users/${request.auth.uid}`);
  const user = (await (tx ? tx.get(ref) : ref.get())).data();
  if (!user || user.isBlocked) throw new HttpsError('permission-denied', 'الحساب غير متاح');
  return {...user, uid: request.auth.uid};
}
function person(u) { return {name: text(u.name || u.displayName || u.userName, 200), phone: text(u.phone || u.phoneNumber, 50)}; }
exports.setBookingVenueStaff = onCall(async r=>{
  const venueId=id(r.data.venueId), userId=id(r.data.userId), scopes=r.data.scopes;
  if(!Array.isArray(scopes) || scopes.some(s=>!['calendar','bookings','checkin'].includes(s)) || new Set(scopes).size!==scopes.length) fail('صلاحيات غير صالحة');
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), v=(await tx.get(db.doc(`booking_venues/${venueId}`))).data(), target=(await tx.get(db.doc(`users/${userId}`))).data();
    if(!v || v.ownerId!==u.uid || userId===u.uid || !target || target.isBlocked) fail('للمالك وحساب موظف نشط فقط');
    tx.set(db.doc(`booking_venue_staff/${venueId}_${userId}`),{venueId,userId,ownerId:u.uid,scopes,updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId,actorUid:u.uid,action:'staff',after:{userId,scopes},createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true};
});
exports.getBookingStaffRequests = onCall(async r=>{
  const u=await actor(r), venueId=id(r.data.venueId);
  const [v,s]=await Promise.all([db.doc(`booking_venues/${venueId}`).get(),db.doc(`booking_venue_staff/${venueId}_${u.uid}`).get()]);
  if(!v.exists || s.data()?.ownerId!==v.data().ownerId || !s.data()?.scopes?.length) fail('صلاحية موظف مطلوبة');
  if(!s.data().scopes.some(k=>['bookings','checkin'].includes(k))) return {bookings:[]};
  const records=await db.collection('bookings').where('venueId','==',venueId).limit(100).get();
  return {bookings:records.docs.map(d=>({id:d.id,venueName:d.data().venueName || '',customerName:d.data().customerName || '',start:d.data().start,end:d.data().end,status:d.data().status}))};
});
exports.sendBookingMessage = onCall(async r=>{
  const bookingId=id(r.data.bookingId), message=text(r.data.message,2000);
  if(/https?:\/\/|<script|porn|xxx|fuck/i.test(message)) fail('نص الرسالة غير مسموح');
  const ref=db.doc(`booking_messages/${bookingId}/messages/${id(r.auth?.uid)}_${id(r.data.requestId)}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), b=(await tx.get(db.doc(`bookings/${bookingId}`))).data();
    if(!b || ![b.customerId,b.ownerId].includes(u.uid)) fail('لأطراف الحجز فقط');
    const other=(await tx.get(db.doc(`users/${u.uid===b.ownerId?b.customerId:b.ownerId}`))).data();
    const existing=await tx.get(ref), rateRef=db.doc(`booking_message_limits/${bookingId}_${u.uid}`), rate=(await tx.get(rateRef)).data();
    if(!other || other.isBlocked) fail('المحادثة غير متاحة');
    if(existing.exists) return;
    if(rate?.lastSentAt>Date.now()-3000) fail('انتظر قليلًا قبل الإرسال');
    tx.create(ref,{bookingId,senderId:u.uid,message,createdAt:FieldValue.serverTimestamp()});
    tx.set(rateRef,{lastSentAt:Date.now()});
  }); return {ok:true};
});
function interval(d, allowPast = false) {
  if (!Number.isSafeInteger(d.start) || !Number.isSafeInteger(d.end) || (!allowPast && d.start < Date.now()) || d.end <= d.start || d.end-d.start > 31*86400000) fail('موعد غير صالح');
  return {start:d.start,end:d.end};
}
exports.saveBookingOffer = onCall(async r=>{
  const venueId=id(r.data.venueId), percent=r.data.percent, until=r.data.until;
  if(!Number.isInteger(percent) || percent<0 || percent>50 || !Number.isSafeInteger(until) || until<Date.now() || until>Date.now()+366*86400000) fail('عرض غير صالح');
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), ref=db.doc(`booking_venues/${venueId}`), v=(await tx.get(ref)).data();
    if(!v || v.ownerId!==u.uid) fail('للمالك فقط');
    const min=v.pricingMode==='hourly'?v.hourlyPrice:v.pricingMode==='shifts'?Math.min(...v.shifts.map(s=>s.price)):v.price;
    if(Math.floor(min*(100-percent)/100)<v.deposit) fail('السعر بعد الخصم أقل من العربون');
    tx.update(ref,{offer:{percent,until}});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId,actorUid:u.uid,action:'offer',after:{percent,until},createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true};
});
// Availability contains no customer identities, contact details, or receipts.
exports.getBookingAvailability = onCall(async r => {
  await actor(r);
  const venueId=id(r.data.venueId), range=interval(r.data, true);
  const venue=(await db.doc(`booking_venues/${venueId}`).get()).data();
  if (!venue?.active) fail('المكان غير متاح');
  const [bookings,closures]=await Promise.all([
    db.collection('bookings').where('venueId','==',venueId).get(),
    db.collection('booking_closures').where('venueId','==',venueId).get()
  ]);
  const slots=[];
  for(const s of bookings.docs) { const b=s.data(); if(overlaps(range,b) && (blocks(b,Date.now()) || b.status==='requested')) slots.push({start:b.start,end:b.end,state:['confirmed','arrived','completed'].includes(b.status)?'confirmed':'pending',shiftId:b.pricing?.id || null}); }
  for(const s of closures.docs) { const b=s.data(); if(overlaps(range,b) && b.active) slots.push({start:b.start,end:b.end,state:'unavailable',shiftId:b.shiftId || null}); }
  return {slots,timeZone:'Asia/Baghdad'};
});
exports.saveBookingClosure = onCall(async r => {
  const range=interval(r.data), venueId=id(r.data.venueId);
  const ref=db.doc(`booking_closures/${venueId}_${id(r.data.requestId)}`), venueRef=db.doc(`booking_venues/${venueId}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), venue=(await tx.get(venueRef)).data();
    const staff=(await tx.get(db.doc(`booking_venue_staff/${venueId}_${u.uid}`))).data();
    const owner=venue?(await tx.get(db.doc(`users/${venue.ownerId}`))).data():null;
    if(!owner || owner.isBlocked) fail('المكان غير متاح');
    if (!venue || u.uid!==venue.ownerId && !(staff?.ownerId===venue.ownerId && staff.scopes.includes('calendar'))) fail('صلاحية تقويم مطلوبة');
    const existing=await tx.get(ref);
    if(existing.exists) return;
    const booked=await tx.get(db.collection('bookings').where('venueId','==',venueId));
    if(booked.docs.some(s=>blocks(s.data(),Date.now()) && overlaps(range,s.data()))) fail('يوجد حجز قائم');
    tx.create(ref,{...range,venueId,ownerId:venue.ownerId,createdBy:u.uid,active:true,reason:text(r.data.reason,500),createdAt:FieldValue.serverTimestamp()});
    tx.update(venueRef,{bookingRevision:FieldValue.increment(1)});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId,actorUid:u.uid,action:'close',after:range,createdAt:FieldValue.serverTimestamp()});
  }); return {id:ref.id};
});
exports.reopenBookingClosure = onCall(async r=>{
  const ref=db.doc(`booking_closures/${id(r.data.closureId)}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), c=(await tx.get(ref)).data();
    if(!c) fail('الموعد غير موجود');
    const venueRef=db.doc(`booking_venues/${c.venueId}`), v=(await tx.get(venueRef)).data(), staff=(await tx.get(db.doc(`booking_venue_staff/${c.venueId}_${u.uid}`))).data();
    const owner=v?(await tx.get(db.doc(`users/${v.ownerId}`))).data():null;
    if(!owner || owner.isBlocked) fail('المكان غير متاح');
    if(!v || u.uid!==v.ownerId && !(staff?.ownerId===v.ownerId && staff.scopes.includes('calendar'))) fail('صلاحية تقويم مطلوبة');
    if(!c.active) return;
    tx.update(ref,{active:false,reopenedBy:u.uid,reopenedAt:FieldValue.serverTimestamp()});
    tx.update(venueRef,{bookingRevision:FieldValue.increment(1)});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId:c.venueId,actorUid:u.uid,action:'reopen',after:{closureId:ref.id},createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true};
});
exports.requestBookingOwnershipTransfer = onCall(async r => {
  const venueId=id(r.data.venueId), newOwnerId=id(r.data.newOwnerId);
  const ref=db.doc(`booking_ownership_transfers/${venueId}_${id(r.data.requestId)}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), v=(await tx.get(db.doc(`booking_venues/${venueId}`))).data();
    const target=(await tx.get(db.doc(`users/${newOwnerId}`))).data();
    const old=await tx.get(ref);
    if(!v || v.ownerId!==u.uid || newOwnerId===u.uid || !target || target.isBlocked) fail('طلب نقل غير صالح');
    person(target);
    if(old.exists) return;
    tx.create(ref,{venueId,ownerId:u.uid,newOwnerId,status:'pending_acceptance',reason:text(r.data.reason,1000),createdAt:FieldValue.serverTimestamp()});
  }); return {id:ref.id};
});
exports.actOnBookingOwnershipTransfer = onCall(async r => {
  const ref=db.doc(`booking_ownership_transfers/${id(r.data.transferId)}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), t=(await tx.get(ref)).data();
    if(!t) fail('الطلب غير موجود');
    const venueRef=db.doc(`booking_venues/${t.venueId}`), v=(await tx.get(venueRef)).data();
    const target=(await tx.get(db.doc(`users/${t.newOwnerId}`))).data();
    const source=(await tx.get(db.doc(`users/${t.ownerId}`))).data();
    if(!v || v.ownerId!==t.ownerId || !target || target.isBlocked || !source || source.isBlocked) fail('تغيرت صلاحية الأطراف');
    if(r.data.action==='accept' && u.uid===t.newOwnerId && t.status==='pending_acceptance') {
      tx.update(ref,{status:'pending_admin',acceptedAt:FieldValue.serverTimestamp()});
    } else if(r.data.action==='approve' && u.isAdmin===true && ![t.ownerId,t.newOwnerId].includes(u.uid) && t.status==='pending_admin') {
      const bookings=await tx.get(db.collection('bookings').where('venueId','==',t.venueId));
      if(bookings.docs.some(s=>['requested','held','payment_review','cancel_requested','confirmed','arrived'].includes(s.data().status) || s.data().refundStatus==='pending')) fail('سوّ الحجوزات والاستردادات القائمة قبل النقل');
      tx.update(venueRef,{ownerId:t.newOwnerId,ownerName:person(target).name,bookingRevision:FieldValue.increment(1)});
      tx.update(ref,{status:'approved',reviewedBy:u.uid,reviewedAt:FieldValue.serverTimestamp()});
      tx.create(db.collection('booking_venue_audit').doc(),{venueId:t.venueId,actorUid:u.uid,action:'transfer',before:{ownerId:t.ownerId},after:{ownerId:t.newOwnerId},createdAt:FieldValue.serverTimestamp()});
    } else fail('غير مخول لهذا الإجراء');
  }); return {ok:true};
});
exports.reviewCompletedBooking = onCall(async r=>{
  const bookingId=id(r.data.bookingId), ref=db.doc(`booking_reviews/${bookingId}`);
  if(!Number.isInteger(r.data.rating) || r.data.rating<1 || r.data.rating>5) fail('تقييم غير صالح');
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), b=(await tx.get(db.doc(`bookings/${bookingId}`))).data();
    if(!b || b.customerId!==u.uid || b.status!=='completed') fail('التقييم لحجز مكتمل فقط');
    if((await tx.get(ref)).exists) fail('سبق تقييم الحجز');
    tx.create(ref,{bookingId,venueId:b.venueId,rating:r.data.rating,comment:text(r.data.comment,1000),status:'pending',customerId:u.uid,createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true};
});
exports.issueBookingCheckInCode = onCall(async r=>{
  const bookingId=id(r.data.bookingId), token=randomBytes(32).toString('hex');
  const ref=db.doc(`booking_checkin_codes/${bookingId}`);
  const expiresAt=Date.now()+10*60000;
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), b=(await tx.get(db.doc(`bookings/${bookingId}`))).data();
    if(!b || b.customerId!==u.uid || b.status!=='confirmed') fail('لحجز مؤكد فقط');
    tx.set(ref,{hash:createHash('sha256').update(token).digest('hex'),expiresAt,version:b.version});
  }); return {code:`aqar-booking:${bookingId}:${token}`,expiresAt};
});
exports.submitBookingOwnershipProof = onCall(async r=>{
  const u=await actor(r), venueId=id(r.data.venueId), path=text(r.data.path,512);
  if(!path.startsWith(`booking_ownership_documents/${venueId}/${u.uid}/`) || !/\/[A-Za-z0-9_-]+\.(jpg|png|pdf)$/.test(path)) fail('ملف غير صالح');
  const [meta]=await getStorage().bucket().file(path).getMetadata();
  if(!['image/jpeg','image/png','application/pdf'].includes(meta.contentType) || Number(meta.size)<=0 || Number(meta.size)>10*1024*1024) fail('ملف غير صالح');
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), v=(await tx.get(db.doc(`booking_venues/${venueId}`))).data();
    if(!v || v.ownerId!==u.uid || !['pending','rejected'].includes(v.verificationStatus)) fail('طلب غير صالح');
    tx.set(db.doc(`booking_ownership_proofs/${venueId}`),{venueId,ownerId:u.uid,path,status:'pending',updatedAt:FieldValue.serverTimestamp()});
    tx.update(db.doc(`booking_venues/${venueId}`),{verificationStatus:'pending'});
  }); return {ok:true};
});
exports.submitBookingMedia = onCall(async r=>{
  const u=await actor(r), venueId=id(r.data.venueId), path=text(r.data.path,512);
  if(!path.startsWith(`booking_media/${venueId}/${u.uid}/`) || !/\/[A-Za-z0-9_-]+\.(jpg|png|mp4)$/.test(path)) fail('ملف غير صالح');
  const [meta]=await getStorage().bucket().file(path).getMetadata();
  const max=meta.contentType==='video/mp4'?50*1024*1024:10*1024*1024;
  if(!['image/jpeg','image/png','video/mp4'].includes(meta.contentType) || Number(meta.size)<=0 || Number(meta.size)>max) fail('حجم أو نوع ملف غير صالح');
  const filename=path.split('/').pop(), ref=db.doc(`booking_media_reviews/${venueId}_${filename}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), v=(await tx.get(db.doc(`booking_venues/${venueId}`))).data();
    if(!v || v.ownerId!==u.uid) fail('للمالك فقط');
    if((await tx.get(ref)).exists) return;
    tx.create(ref,{venueId,ownerId:u.uid,path,type:meta.contentType,status:'pending',createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true};
});
exports.reviewBookingMedia = onCall(async r=>{
  const ref=db.doc(`booking_media_reviews/${id(r.data.mediaId)}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), m=(await tx.get(ref)).data();
    if(u.isAdmin!==true || !m || m.status!=='pending' || m.ownerId===u.uid) fail('مراجعة إدارية مستقلة مطلوبة');
    const venueRef=db.doc(`booking_venues/${m.venueId}`), v=(await tx.get(venueRef)).data();
    if(!v || v.ownerId!==m.ownerId || (v.mediaPaths || []).length>=20) fail('تغير المالك أو تجاوز حد 20 ملفًا');
    tx.update(ref,{status:r.data.approved===true?'approved':'rejected',reviewedBy:u.uid,reviewedAt:FieldValue.serverTimestamp()});
    if(r.data.approved===true) tx.update(venueRef,{mediaPaths:FieldValue.arrayUnion(m.path)});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId:m.venueId,actorUid:u.uid,action:'reviewMedia',after:{path:m.path,approved:r.data.approved===true},createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true};
});
exports.reviewBookingOwnershipProof = onCall(async r=>{
  const venueId=id(r.data.venueId), ref=db.doc(`booking_ownership_proofs/${venueId}`), venueRef=db.doc(`booking_venues/${venueId}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), proof=(await tx.get(ref)).data(), v=(await tx.get(venueRef)).data();
    if(u.isAdmin!==true || !v || v.ownerId===u.uid || !proof || proof.ownerId!==v.ownerId || proof.status!=='pending') fail('مراجع إداري مستقل مطلوب');
    const status=r.data.approved===true?'verified':'rejected';
    tx.update(ref,{status,reviewedBy:u.uid,reason:text(r.data.reason,1000),reviewedAt:FieldValue.serverTimestamp()});
    tx.update(venueRef,{verificationStatus:status});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId,actorUid:u.uid,action:'verifyOwnership',after:{status},createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true};
});
exports.verifyBookingCheckInCode = onCall(async r=>{
  const parts=text(r.data.code,400).split(':');
  if(parts.length!==3 || parts[0]!=='aqar-booking' || !/^[a-f0-9]{64}$/.test(parts[2])) fail('رمز غير صالح');
  const ref=db.doc(`bookings/${id(parts[1])}`), codeRef=db.doc(`booking_checkin_codes/${ref.id}`);
  await db.runTransaction(async tx=>{
    const u=await actor(r,tx), b=(await tx.get(ref)).data(), code=(await tx.get(codeRef)).data();
    if(!b || b.ownerId!==u.uid || b.status!=='confirmed' || !code || code.version!==b.version || code.expiresAt<Date.now() || code.hash!==createHash('sha256').update(parts[2]).digest('hex') || Date.now()<b.start || Date.now()>=b.end) fail('الرمز منتهي أو غير مخول');
    tx.update(ref,{status:'arrived',arrivedAt:Date.now(),version:nextVersion(b),updatedAt:FieldValue.serverTimestamp()});
    tx.delete(codeRef);
    tx.create(db.collection('booking_action_audit').doc(),{bookingId:ref.id,actorUid:u.uid,action:'qrCheckIn',version:nextVersion(b),before:{status:'confirmed'},after:{status:'arrived'},createdAt:FieldValue.serverTimestamp()});
  }); return {ok:true,bookingId:ref.id};
});
exports.saveBookingVenue = onCall(async r => {
  const u = await actor(r), d = r.data;
  if (u.isAdmin !== true && d.ownerId !== u.uid) throw new HttpsError('permission-denied', 'للمالك أو الإدارة فقط');
  const ownerId = id(d.ownerId), owner = (await db.doc(`users/${ownerId}`).get()).data();
  if (!owner || owner.isBlocked) fail('حساب المالك غير متاح');
  const ownerDetails = person(owner);
  const pricing = policy(()=>pricingConfig(d));
  const cancellation = policy(()=>cancellationPolicy(d.cancellationPolicy));
  const basePrice = pricing.pricingMode==='shifts' ? pricing.shifts[0].price : pricing.pricingMode==='hourly' ? pricing.hourlyPrice : d.price;
  const geo={};
  if(d.latitude != null || d.longitude != null) {
    if(typeof d.latitude!=='number' || !Number.isFinite(d.latitude) || d.latitude < -90 || d.latitude > 90 || typeof d.longitude!=='number' || !Number.isFinite(d.longitude) || d.longitude < -180 || d.longitude > 180) fail('إحداثيات غير صالحة');
    Object.assign(geo,{latitude:d.latitude,longitude:d.longitude});
  }
  if (!money(basePrice, d.deposit) || !['chalet','farm','hall','other'].includes(d.category)) fail('سعر أو نوع غير صالح');
  const ref = d.id ? db.doc(`booking_venues/${id(d.id)}`) : db.collection('booking_venues').doc();
  await db.runTransaction(async tx => {
    const currentActor = await actor(r,tx);
    const previous = (await tx.get(ref)).data();
    if (currentActor.isAdmin !== true && (previous ? previous.ownerId !== currentActor.uid || d.active !== previous.active : d.active !== false)) throw new HttpsError('permission-denied','لا يمكن تفعيل مكان دون الإدارة');
    if(['pending','rejected'].includes(previous?.verificationStatus) && d.active===true) fail('وثّق الملكية قبل التفعيل');
    const commissionBps=currentActor.isAdmin===true && d.commissionBps!=null ? d.commissionBps : previous?.commissionBps || 0;
    if(!Number.isInteger(commissionBps) || commissionBps<0 || commissionBps>10000) fail('عمولة غير صالحة');
    const currentOwner = (await tx.get(db.doc(`users/${ownerId}`))).data();
    if (!currentOwner || currentOwner.isBlocked) fail('حساب المالك غير متاح');
    if (previous && previous.ownerId !== ownerId) fail('استخدم طلب نقل الملكية المعتمد');
    tx.set(ref, {ownerId, ownerName: ownerDetails.name, name: text(d.name,200), location: text(d.location,500), category:d.category,
      ...pricing, ...geo, ...(!previous && currentActor.isAdmin!==true?{verificationStatus:'pending'}:{}), commissionBps, cancellationPolicy:cancellation, price:basePrice, deposit:d.deposit, terms:text(d.terms,5000), active:d.active === true, updatedAt:FieldValue.serverTimestamp()}, {merge:true});
    tx.create(db.collection('booking_venue_audit').doc(),{venueId:ref.id,actorUid:u.uid,before:previous || null,after:{...pricing,cancellationPolicy:cancellation,price:basePrice,deposit:d.deposit,terms:d.terms,active:d.active === true},createdAt:FieldValue.serverTimestamp()});
  });
  return {id:ref.id};
});
exports.requestBooking = onCall(async r => {
  const u = await actor(r), d = r.data, customer = person(u);
  const ref = db.doc(`bookings/${u.uid}_${id(d.requestId)}`), venueRef = db.doc(`booking_venues/${id(d.venueId)}`);
  const start = Number(d.start), end = Number(d.end);
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start <= Date.now() || end <= start || end-start > 31*86400000) fail('موعد غير صالح');
  await db.runTransaction(async tx => {
    const u=await actor(r,tx),customer=person(u);
    const existing = await tx.get(ref); if (existing.exists) return;
    const venue = (await tx.get(venueRef)).data();
    if (!venue?.cancellationPolicy) fail('يجب على الإدارة تهيئة سياسة الإلغاء للمكان');
    if (!venue?.active || venue.ownerId === u.uid || d.acceptedTerms !== venue.terms || d.deposit !== venue.deposit) fail('راجع الأسعار والشروط الحالية');
    const priced = policy(()=>quote(venue,{...d,start,end}));
    if (d.price !== priced.total || d.cancellationPolicy?.freeCancellationHours !== venue.cancellationPolicy?.freeCancellationHours || d.cancellationPolicy?.lateRefundPercent !== venue.cancellationPolicy?.lateRefundPercent) fail('راجع السعر وسياسة الإلغاء');
    const owner = (await tx.get(db.doc(`users/${venue.ownerId}`))).data();
    if (!owner || owner.isBlocked) fail('المالك غير متاح');
    const ownerDetails = person(owner);
    const occupied = await tx.get(db.collection('bookings').where('venueId','==',venueRef.id));
    const closures = await tx.get(db.collection('booking_closures').where('venueId','==',venueRef.id));
    if (closures.docs.some(s=>s.data().active && overlaps({start,end},s.data()))) fail('الموعد غير متاح');
    if (occupied.docs.some(s => blocks(s.data(),Date.now()) && overlaps({start,end},s.data()))) fail('الموعد محجوز');
    tx.create(ref, {venueId:venueRef.id, venueName:venue.name, category:venue.category, location:venue.location,
      ownerId:venue.ownerId, ownerName:ownerDetails.name, ownerPhone:ownerDetails.phone,
      customerId:u.uid, customerName:customer.name, customerPhone:customer.phone,
      start,end,total:priced.total,pricing:priced.pricing,commissionBps:venue.commissionBps || 0,commissionBasis:'deposit',cancellationPolicy:venue.cancellationPolicy || null,deposit:venue.deposit,paid:0,remaining:priced.total,terms:venue.terms,
      notes:typeof d.notes === 'string' ? d.notes.slice(0,1000) : '', status:'requested', version:0,
      createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('booking_action_audit').doc(),{bookingId:ref.id,actorUid:u.uid,action:'request',version:0,before:null,after:{status:'requested',total:priced.total,deposit:venue.deposit},createdAt:FieldValue.serverTimestamp()});
    tx.update(venueRef,{bookingRevision:FieldValue.increment(1)});
  }); return {id:ref.id};
});
exports.actOnBooking = onCall(async r => {
  const u = await actor(r), d = r.data, ref = db.doc(`bookings/${id(d.bookingId)}`);
  let receipt;
  if (d.action === 'submitPayment') {
    const path = text(d.receiptPath,512);
    if (!path.startsWith(`booking_receipts/${ref.id}/${u.uid}/`) || !/\/[0-9]+\.jpg$/.test(path)) fail('إيصال غير صالح');
    const [meta] = await getStorage().bucket().file(path).getMetadata();
    if (meta.contentType !== 'image/jpeg' || !Number.isSafeInteger(Number(meta.size)) || Number(meta.size)<=0 || Number(meta.size)>10*1024*1024) fail('إيصال غير صالح');
    receipt = path;
  }
  await db.runTransaction(async tx => {
    const u = await actor(r, tx); // Revocation/blocking conflicts with the financial transaction.
    const b = (await tx.get(ref)).data(); if (!b) fail('الحجز غير موجود');
    const venueRef = db.doc(`booking_venues/${b.venueId}`);
    const venue = (await tx.get(venueRef)).data(); // Serializes inventory mutations.
    const staff=(await tx.get(db.doc(`booking_venue_staff/${b.venueId}_${u.uid}`))).data();
    const currentOwner=venue?(await tx.get(db.doc(`users/${venue.ownerId}`))).data():null;
    const ownerActive=!!currentOwner && !currentOwner.isBlocked;
    const staffActive=staff?.ownerId===venue?.ownerId && staff?.scopes?.length>0;
    const operates=ownerActive && (u.uid===b.ownerId || staffActive && staff.scopes.includes('bookings'));
    const checksIn=ownerActive && (u.uid===b.ownerId || staffActive && staff.scopes.includes('checkin'));
    const config = (await tx.get(db.doc('settings/bookings'))).data() || {};
    const paymentConfig = d.action === 'submitPayment' ? (await tx.get(db.doc(CONFIG))).data() : null;
    const now = Date.now(), patch = {};
    // Retrying a completed operation is safe only for its original actor/payload.
    if (d.action === 'submitPayment' && b.customerId === u.uid && b.receiptPath === receipt && b.paymentMethod === d.method && b.transactionNumber === d.transactionNumber && b.paymentAccount === d.expectedNumber) return;
    if (d.action === 'approve') {
      if (!operates || b.status !== 'requested' || b.start <= now || !venue?.active) fail('لا يمكن قبول الحجز');
      const occupied = await tx.get(db.collection('bookings').where('venueId','==',b.venueId));
      const closures = await tx.get(db.collection('booking_closures').where('venueId','==',b.venueId));
      if (closures.docs.some(s=>s.data().active && overlaps(b,s.data()))) fail('الموعد غير متاح');
      if (occupied.docs.some(s=>s.id!==ref.id && blocks(s.data(),now) && overlaps(b,s.data()))) fail('الموعد محجوز');
      const minutes = Number.isInteger(config.holdMinutes) && config.holdMinutes>=5 && config.holdMinutes<=10080 ? config.holdMinutes : 120;
      Object.assign(patch,{status:'held',holdUntil:Math.min(now+minutes*60000,b.start)});
    } else if (d.action === 'reject') {
      if (!operates || b.status !== 'requested') fail('لا يمكن الرفض');
      Object.assign(patch,{status:'rejected',reason:text(d.reason)});
    } else if (d.action === 'submitPayment') {
      if (u.uid !== b.customerId || b.status !== 'held' || b.holdUntil<=now || !['qicard','zaincash'].includes(d.method)) fail('انتهت المهلة أو طريقة الدفع غير صالحة');
      const snapshot = recipient(paymentConfig, d.method, d.expectedNumber);
      const transfer = text(d.transactionNumber,200).normalize('NFKC').trim().toLowerCase();
      const transferRef = db.doc(`booking_payment_references/${createHash('sha256').update(`${d.method}:${snapshot.number}:${transfer}`).digest('hex')}`);
      if ((await tx.get(transferRef)).exists) fail('مرجع التحويل مستخدم؛ راجع الإدارة');
      tx.create(transferRef,{bookingId:ref.id,customerId:u.uid,createdAt:FieldValue.serverTimestamp()});
      Object.assign(patch,{status:'payment_review',receiptPath:receipt,paymentMethod:d.method,transactionNumber:text(d.transactionNumber,200),paymentAccount:snapshot.number,paymentAccountSnapshot:snapshot,submittedAt:FieldValue.serverTimestamp()});
    } else if (d.action === 'confirmPayment' || d.action === 'rejectPayment') {
      if (!finance(u) || staffActive || [b.ownerId,b.customerId].includes(u.uid) || !['payment_review','cancel_requested'].includes(b.status)) fail('مراجع مالي مستقل مطلوب');
      Object.assign(patch,d.action==='confirmPayment' ? {status:'confirmed',paid:b.deposit,remaining:b.total-b.deposit} : {status:'payment_rejected',reason:text(d.reason)});
      if (b.status === 'cancel_requested') {
        const refundDue = d.action==='confirmPayment' ? policy(()=>refund({...b,paid:b.deposit},b.cancelledAt,b.cancellationByVenue)) : 0;
        Object.assign(patch,{status:'cancelled',remaining:0,contractRemaining:b.total-b.deposit,refundDue,refundStatus:refundDue>0?'pending':'none',refunded:0});
      }
      patch.reviewedBy = u.uid;
    } else if (d.action === 'cancel') {
      if (!['requested','held','confirmed','payment_review'].includes(b.status) || (u.uid!==b.customerId && u.uid!==b.ownerId && u.isAdmin !== true) || b.start <= now) fail('لا يمكن إلغاء هذا الحجز');
      if (b.status === 'payment_review' && !b.cancellationPolicy) fail('الحجز القديم يحتاج سياسة تسوية معتمدة');
      const refundDue = b.status === 'confirmed' ? policy(()=>refund(b,now,u.uid===b.ownerId || u.isAdmin)) : 0;
      Object.assign(patch,{status:b.status==='payment_review'?'cancel_requested':'cancelled',remaining:b.status==='payment_review'?b.remaining:0,contractRemaining:b.remaining,cancellationByVenue:u.uid===b.ownerId || u.isAdmin,reason:text(d.reason),cancellationReason:text(d.reason),cancelledBy:u.uid,cancelledAt:now,refundDue,refundStatus:refundDue>0?'pending':'none',refunded:0});
    } else if (d.action === 'settleRefund') {
      if (!finance(u) || staffActive || [b.ownerId,b.customerId].includes(u.uid) || b.status !== 'cancelled' || b.refundStatus !== 'pending') fail('تسوية مالية مستقلة مطلوبة');
      Object.assign(patch,{refundStatus:'settled',refunded:b.refundDue,refundReference:text(d.refundReference,200),refundSettledBy:u.uid,refundSettledAt:now});
    } else if (d.action === 'settleOwner') {
      if (!finance(u) || staffActive || [b.ownerId,b.customerId].includes(u.uid) || b.status!=='completed' || b.ownerSettlementStatus==='settled' || b.refundStatus==='pending') fail('تسوية مستقلة لحجز مكتمل فقط');
      const collected=Math.max(0,(b.paid || 0)-(b.refunded || 0));
      const commission=Number(BigInt(collected)*BigInt(b.commissionBps || 0)/10000n);
      Object.assign(patch,{ownerSettlementStatus:'settled',ownerSettled:collected-commission,platformCommission:commission,ownerSettlementReference:text(d.settlementReference,200),ownerSettledBy:u.uid,ownerSettledAt:now});
    } else if (d.action === 'arrive') {
      if (!checksIn || b.status !== 'confirmed' || now < b.start || now >= b.end) fail('لا يمكن تسجيل الوصول');
      Object.assign(patch,{status:'arrived',arrivedAt:now});
    } else if (d.action === 'complete') {
      if (!checksIn || !['confirmed','arrived'].includes(b.status) || now < b.end) fail('لم ينته الحجز');
      Object.assign(patch,{status:'completed',completedAt:now});
    } else if (d.action === 'expire') {
      if (u.isAdmin !== true || b.status!=='held' || b.holdUntil>now) fail('لم تنته المهلة');
      patch.status='expired';
    } else fail('إجراء غير صالح');
    const version = nextVersion(b);
    if(['confirmPayment','settleRefund','settleOwner'].includes(d.action)) tx.create(db.doc(`booking_ledger/${ref.id}_${version}`),{
      bookingId:ref.id,ownerId:b.ownerId,actorUid:u.uid,action:d.action,currency:'IQD',version,
      depositCollected:d.action==='confirmPayment'?b.deposit:0,refundPaid:d.action==='settleRefund'?b.refundDue:0,
      ownerPaid:patch.ownerSettled || 0,platformCommission:patch.platformCommission || 0,
      reference:d.action==='settleRefund'?patch.refundReference:d.action==='settleOwner'?patch.ownerSettlementReference:b.transactionNumber,
      createdAt:FieldValue.serverTimestamp()
    });
    tx.update(ref,{...patch,version,updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('booking_action_audit').doc(), {bookingId:ref.id,actorUid:u.uid,action:d.action,version,before:{status:b.status,paid:b.paid || 0,refundStatus:b.refundStatus || 'none'},after:patch,createdAt:FieldValue.serverTimestamp()});
    tx.update(venueRef,{bookingRevision:FieldValue.increment(1)});
  }); return {ok:true};
});
exports.reportBooking = onCall(async r => {
  const u=await actor(r), ref=db.doc(`bookings/${id(r.data.bookingId)}`), b=(await ref.get()).data();
  if (!b || ![b.customerId,b.ownerId].includes(u.uid)) throw new HttpsError('permission-denied','الحجز خاص');
  await db.doc(`booking_reports/${ref.id}_${u.uid}`).set({bookingId:ref.id,userId:u.uid,userName:person(u).name,venueName:b.venueName,
    reason:text(r.data.reason),status:'open',createdAt:FieldValue.serverTimestamp()}); return {ok:true};
});
exports.bookingNotifications = onDocumentWritten({document:'bookings/{bookingId}',retry:true}, async event => {
  const b=event.data.after.data(), before=event.data.before.data();
  if (!b || before?.status===b.status && before?.refundStatus===b.refundStatus) return;
  const admins=await db.collection('users').where('isAdmin','==',true).get();
  const reviewers=await db.collection('users').where('canReviewBookingPayments','==',true).get();
  const recipients=new Set([b.customerId,b.ownerId,...reviewers.docs.filter(s=>!s.data().isBlocked).map(s=>s.id),...admins.docs.filter(s=>!s.data().isBlocked).map(s=>s.id)]);
  for (const userId of recipients) {
    const recipientUser=(await db.doc(`users/${userId}`).get()).data();
    if(!recipientUser || recipientUser.isBlocked) continue;
    const ref=db.doc(`notifications/booking_${event.params.bookingId}_${b.version}_${userId}`);
    try { await ref.create({notificationId:ref.id,type:'booking',bookingId:event.params.bookingId,target:'user',userId,
      title:'تحديث الحجز',message:`${b.customerName} — ${b.venueName}: ${b.refundStatus==='settled' ? 'تمت تسوية الاسترداد' : ({requested:'طلب جديد',held:'حجز مؤقت',cancel_requested:'إلغاء بانتظار مراجعة الإيصال',payment_review:'مراجعة العربون',confirmed:'حجز مؤكد',rejected:'طلب مرفوض',cancelled:'حجز ملغي',expired:'انتهت مهلة الدفع',payment_rejected:'إيصال مرفوض'}[b.status] || b.status)}`,deliveryType:'external',readBy:[],createdAt:FieldValue.serverTimestamp()}); }
    catch(e) { if(e.code!==6) throw e; }
  }
});
exports.expireBookingHolds = onSchedule('every 5 minutes', async () => {
  const due=await db.collection('bookings').where('status','==','held').where('holdUntil','<=',Date.now()).limit(200).get();
  for (const s of due.docs) await db.runTransaction(async tx=> {
    const b=(await tx.get(s.ref)).data();
    if(b.status==='held' && b.holdUntil<=Date.now()) {
      tx.update(s.ref,{status:'expired',version:nextVersion(b),updatedAt:FieldValue.serverTimestamp()});
      tx.create(db.collection('booking_action_audit').doc(),{bookingId:s.id,actorUid:'system',action:'expire',version:nextVersion(b),before:{status:b.status},after:{status:'expired'},createdAt:FieldValue.serverTimestamp()});
    }
  });
});
