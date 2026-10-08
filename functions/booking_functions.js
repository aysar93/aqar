const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {overlaps, blocks, money} = require('./booking_policy');
const db = getFirestore();
function fail(message) { throw new HttpsError('failed-precondition', message); }
function text(v, max = 1000) { if (typeof v !== 'string' || !v.trim() || v.length > max) fail('بيانات غير مكتملة'); return v.trim(); }
function id(v) { const s = text(v, 128); if (s.includes('/')) fail('معرف غير صالح'); return s; }
async function actor(request) {
  if (!request.auth || request.auth.token?.firebase?.sign_in_provider === 'anonymous') throw new HttpsError('unauthenticated', 'سجل الدخول');
  const user = (await db.doc(`users/${request.auth.uid}`).get()).data();
  if (!user || user.isBlocked) throw new HttpsError('permission-denied', 'الحساب غير متاح');
  return {...user, uid: request.auth.uid};
}
function person(u) { return {name: text(u.name || u.displayName || u.userName, 200), phone: text(u.phone || u.phoneNumber, 50)}; }
exports.saveBookingVenue = onCall(async r => {
  const u = await actor(r), d = r.data;
  if (!u.isAdmin) throw new HttpsError('permission-denied', 'للإدارة فقط');
  const ownerId = id(d.ownerId), owner = (await db.doc(`users/${ownerId}`).get()).data();
  if (!owner || owner.isBlocked) fail('حساب المالك غير متاح');
  const ownerDetails = person(owner);
  if (!money(d.price, d.deposit) || !['chalet','farm','hall','other'].includes(d.category)) fail('سعر أو نوع غير صالح');
  const ref = d.id ? db.doc(`booking_venues/${id(d.id)}`) : db.collection('booking_venues').doc();
  await db.runTransaction(async tx => {
    const previous = (await tx.get(ref)).data();
    if (previous && previous.ownerId !== ownerId) fail('لا يمكن نقل ملكية مكان مستخدم للحجوزات');
    tx.set(ref, {ownerId, ownerName: ownerDetails.name, name: text(d.name,200), location: text(d.location,500), category:d.category,
      price:d.price, deposit:d.deposit, terms:text(d.terms,5000), active:d.active === true, updatedAt:FieldValue.serverTimestamp()}, {merge:true});
  });
  return {id:ref.id};
});
exports.requestBooking = onCall(async r => {
  const u = await actor(r), d = r.data, customer = person(u);
  const ref = db.doc(`bookings/${u.uid}_${id(d.requestId)}`), venueRef = db.doc(`booking_venues/${id(d.venueId)}`);
  const start = Number(d.start), end = Number(d.end);
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start <= Date.now() || end <= start || end-start > 31*86400000) fail('موعد غير صالح');
  await db.runTransaction(async tx => {
    const existing = await tx.get(ref); if (existing.exists) return;
    const venue = (await tx.get(venueRef)).data();
    if (!venue?.active || venue.ownerId === u.uid || d.acceptedTerms !== venue.terms || d.price !== venue.price || d.deposit !== venue.deposit) fail('راجع الأسعار والشروط الحالية');
    const owner = (await tx.get(db.doc(`users/${venue.ownerId}`))).data();
    if (!owner || owner.isBlocked) fail('المالك غير متاح');
    const ownerDetails = person(owner);
    const occupied = await tx.get(db.collection('bookings').where('venueId','==',venueRef.id));
    if (occupied.docs.some(s => blocks(s.data(),Date.now()) && overlaps({start,end},s.data()))) fail('الموعد محجوز');
    tx.create(ref, {venueId:venueRef.id, venueName:venue.name, category:venue.category, location:venue.location,
      ownerId:venue.ownerId, ownerName:ownerDetails.name, ownerPhone:ownerDetails.phone,
      customerId:u.uid, customerName:customer.name, customerPhone:customer.phone,
      start,end,total:venue.price,deposit:venue.deposit,paid:0,remaining:venue.price,terms:venue.terms,
      notes:typeof d.notes === 'string' ? d.notes.slice(0,1000) : '', status:'requested', version:0,
      createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
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
    if (meta.contentType !== 'image/jpeg' || Number(meta.size)>10*1024*1024) fail('إيصال غير صالح');
    receipt = path;
  }
  await db.runTransaction(async tx => {
    const b = (await tx.get(ref)).data(); if (!b) fail('الحجز غير موجود');
    const venueRef = db.doc(`booking_venues/${b.venueId}`);
    const venue = (await tx.get(venueRef)).data(); // Serializes inventory mutations.
    const config = (await tx.get(db.doc('settings/bookings'))).data() || {};
    const now = Date.now(), patch = {};
    if (d.action === 'approve') {
      if (u.uid !== b.ownerId || b.status !== 'requested' || b.start <= now || !venue?.active) fail('لا يمكن قبول الحجز');
      const occupied = await tx.get(db.collection('bookings').where('venueId','==',b.venueId));
      if (occupied.docs.some(s=>s.id!==ref.id && blocks(s.data(),now) && overlaps(b,s.data()))) fail('الموعد محجوز');
      const minutes = Number.isInteger(config.holdMinutes) && config.holdMinutes>=5 && config.holdMinutes<=10080 ? config.holdMinutes : 120;
      Object.assign(patch,{status:'held',holdUntil:Math.min(now+minutes*60000,b.start)});
    } else if (d.action === 'reject') {
      if (u.uid !== b.ownerId || b.status !== 'requested') fail('لا يمكن الرفض');
      Object.assign(patch,{status:'rejected',reason:text(d.reason)});
    } else if (d.action === 'submitPayment') {
      if (u.uid !== b.customerId || b.status !== 'held' || b.holdUntil<=now || !['qicard','zaincash'].includes(d.method)) fail('انتهت المهلة أو طريقة الدفع غير صالحة');
      if (!config[d.method]?.enabled || !config[d.method]?.account) fail('طريقة الدفع غير مهيأة');
      Object.assign(patch,{status:'payment_review',receiptPath:receipt,paymentMethod:d.method,transactionNumber:text(d.transactionNumber,200),paymentAccount:config[d.method].account,submittedAt:FieldValue.serverTimestamp()});
    } else if (d.action === 'confirmPayment' || d.action === 'rejectPayment') {
      if (!u.isAdmin || b.status !== 'payment_review') fail('مراجعة الإدارة مطلوبة');
      Object.assign(patch,d.action==='confirmPayment' ? {status:'confirmed',paid:b.deposit,remaining:b.total-b.deposit} : {status:'payment_rejected',reason:text(d.reason)});
      patch.reviewedBy = u.uid;
    } else if (d.action === 'cancel') {
      if (!['requested','held'].includes(b.status) || (u.uid!==b.customerId && u.uid!==b.ownerId && !u.isAdmin)) fail('الحجز المدفوع يحتاج معالجة إدارية');
      Object.assign(patch,{status:'cancelled',reason:text(d.reason)});
    } else if (d.action === 'expire') {
      if (!u.isAdmin || b.status!=='held' || b.holdUntil>now) fail('لم تنته المهلة');
      patch.status='expired';
    } else fail('إجراء غير صالح');
    tx.update(ref,{...patch,version:b.version+1,updatedAt:FieldValue.serverTimestamp()});
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
  if (!b || before?.status===b.status) return;
  const admins=await db.collection('users').where('isAdmin','==',true).get();
  const recipients=new Set([b.customerId,b.ownerId,...admins.docs.filter(s=>!s.data().isBlocked).map(s=>s.id)]);
  for (const userId of recipients) {
    const ref=db.doc(`notifications/booking_${event.params.bookingId}_${b.version}_${userId}`);
    try { await ref.create({notificationId:ref.id,type:'booking',bookingId:event.params.bookingId,target:'user',userId,
      title:'تحديث الحجز',message:`${b.customerName} — ${b.venueName}: ${{requested:'طلب جديد',held:'حجز مؤقت',payment_review:'مراجعة العربون',confirmed:'حجز مؤكد',rejected:'طلب مرفوض',cancelled:'حجز ملغي',expired:'انتهت مهلة الدفع',payment_rejected:'إيصال مرفوض'}[b.status] || b.status}`,deliveryType:'external',readBy:[],createdAt:FieldValue.serverTimestamp()}); }
    catch(e) { if(e.code!==6) throw e; }
  }
});
exports.expireBookingHolds = onSchedule('every 5 minutes', async () => {
  const due=await db.collection('bookings').where('status','==','held').where('holdUntil','<=',Date.now()).limit(200).get();
  for (const s of due.docs) await db.runTransaction(async tx=> {
    const b=(await tx.get(s.ref)).data();
    if(b.status==='held' && b.holdUntil<=Date.now()) tx.update(s.ref,{status:'expired',version:b.version+1,updatedAt:FieldValue.serverTimestamp()});
  });
});
