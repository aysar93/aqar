const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {overlaps, blocks, money, pricingConfig, quote, cancellationPolicy, refund} = require('./booking_policy');
const db = getFirestore();
const {CONFIG, available, recipient} = require('./payment_accounts');
function policy(fn) { try { return fn(); } catch(e) { fail(e.message); } }
function finance(u) { return u.canReviewBookingPayments === true; }
exports.getBookingPaymentAccounts = onCall(async r => { await actor(r); return available((await db.doc(CONFIG).get()).data()); });
exports.setBookingPaymentReviewer = onCall(async r => {
  const u = await actor(r);
  if (!u.isAdmin) throw new HttpsError('permission-denied','للإدارة فقط');
  const uid = id(r.data.userId), ref = db.doc(`users/${uid}`);
  if (!(await ref.get()).exists || typeof r.data.enabled !== 'boolean') fail('حساب غير صالح');
  await ref.update({canReviewBookingPayments:r.data.enabled,bookingFinanceGrantedBy:u.uid,bookingFinanceUpdatedAt:FieldValue.serverTimestamp()});
  return {ok:true};
});
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
  const pricing = policy(()=>pricingConfig(d));
  const cancellation = policy(()=>cancellationPolicy(d.cancellationPolicy));
  const basePrice = pricing.pricingMode==='shifts' ? pricing.shifts[0].price : pricing.pricingMode==='hourly' ? pricing.hourlyPrice : d.price;
  if (!money(basePrice, d.deposit) || !['chalet','farm','hall','other'].includes(d.category)) fail('سعر أو نوع غير صالح');
  const ref = d.id ? db.doc(`booking_venues/${id(d.id)}`) : db.collection('booking_venues').doc();
  await db.runTransaction(async tx => {
    const previous = (await tx.get(ref)).data();
    if (previous && previous.ownerId !== ownerId) fail('لا يمكن نقل ملكية مكان مستخدم للحجوزات');
    tx.set(ref, {ownerId, ownerName: ownerDetails.name, name: text(d.name,200), location: text(d.location,500), category:d.category,
      ...pricing, cancellationPolicy:cancellation, price:basePrice, deposit:d.deposit, terms:text(d.terms,5000), active:d.active === true, updatedAt:FieldValue.serverTimestamp()}, {merge:true});
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
    if (!venue?.cancellationPolicy) fail('يجب على الإدارة تهيئة سياسة الإلغاء للمكان');
    if (!venue?.active || venue.ownerId === u.uid || d.acceptedTerms !== venue.terms || d.deposit !== venue.deposit) fail('راجع الأسعار والشروط الحالية');
    const priced = policy(()=>quote(venue,{...d,start,end}));
    if (d.price !== priced.total || d.cancellationPolicy?.freeCancellationHours !== venue.cancellationPolicy?.freeCancellationHours || d.cancellationPolicy?.lateRefundPercent !== venue.cancellationPolicy?.lateRefundPercent) fail('راجع السعر وسياسة الإلغاء');
    const owner = (await tx.get(db.doc(`users/${venue.ownerId}`))).data();
    if (!owner || owner.isBlocked) fail('المالك غير متاح');
    const ownerDetails = person(owner);
    const occupied = await tx.get(db.collection('bookings').where('venueId','==',venueRef.id));
    if (occupied.docs.some(s => blocks(s.data(),Date.now()) && overlaps({start,end},s.data()))) fail('الموعد محجوز');
    tx.create(ref, {venueId:venueRef.id, venueName:venue.name, category:venue.category, location:venue.location,
      ownerId:venue.ownerId, ownerName:ownerDetails.name, ownerPhone:ownerDetails.phone,
      customerId:u.uid, customerName:customer.name, customerPhone:customer.phone,
      start,end,total:priced.total,pricing:priced.pricing,cancellationPolicy:venue.cancellationPolicy || null,deposit:venue.deposit,paid:0,remaining:priced.total,terms:venue.terms,
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
    const paymentConfig = d.action === 'submitPayment' ? (await tx.get(db.doc(CONFIG))).data() : null;
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
      const snapshot = recipient(paymentConfig, d.method, d.expectedNumber);
      Object.assign(patch,{status:'payment_review',receiptPath:receipt,paymentMethod:d.method,transactionNumber:text(d.transactionNumber,200),paymentAccount:snapshot.number,paymentAccountSnapshot:snapshot,submittedAt:FieldValue.serverTimestamp()});
    } else if (d.action === 'confirmPayment' || d.action === 'rejectPayment') {
      if (!finance(u) || [b.ownerId,b.customerId].includes(u.uid) || !['payment_review','cancel_requested'].includes(b.status)) fail('مراجع مالي مستقل مطلوب');
      Object.assign(patch,d.action==='confirmPayment' ? {status:'confirmed',paid:b.deposit,remaining:b.total-b.deposit} : {status:'payment_rejected',reason:text(d.reason)});
      if (b.status === 'cancel_requested') {
        const refundDue = d.action==='confirmPayment' ? policy(()=>refund({...b,paid:b.deposit},b.cancelledAt,b.cancellationByVenue)) : 0;
        Object.assign(patch,{status:'cancelled',remaining:0,contractRemaining:b.total-b.deposit,refundDue,refundStatus:refundDue>0?'pending':'none',refunded:0});
      }
      patch.reviewedBy = u.uid;
    } else if (d.action === 'cancel') {
      if (!['requested','held','confirmed','payment_review'].includes(b.status) || (u.uid!==b.customerId && u.uid!==b.ownerId && !u.isAdmin) || b.start <= now) fail('لا يمكن إلغاء هذا الحجز');
      if (b.status === 'payment_review' && !b.cancellationPolicy) fail('الحجز القديم يحتاج سياسة تسوية معتمدة');
      const refundDue = b.status === 'confirmed' ? policy(()=>refund(b,now,u.uid===b.ownerId || u.isAdmin)) : 0;
      Object.assign(patch,{status:b.status==='payment_review'?'cancel_requested':'cancelled',remaining:b.status==='payment_review'?b.remaining:0,contractRemaining:b.remaining,cancellationByVenue:u.uid===b.ownerId || u.isAdmin,reason:text(d.reason),cancellationReason:text(d.reason),cancelledBy:u.uid,cancelledAt:now,refundDue,refundStatus:refundDue>0?'pending':'none',refunded:0});
    } else if (d.action === 'settleRefund') {
      if (!finance(u) || [b.ownerId,b.customerId].includes(u.uid) || b.status !== 'cancelled' || b.refundStatus !== 'pending') fail('تسوية مالية مستقلة مطلوبة');
      Object.assign(patch,{refundStatus:'settled',refunded:b.refundDue,refundReference:text(d.refundReference,200),refundSettledBy:u.uid,refundSettledAt:now});
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
  if (!b || before?.status===b.status && before?.refundStatus===b.refundStatus) return;
  const admins=await db.collection('users').where('isAdmin','==',true).get();
  const reviewers=await db.collection('users').where('canReviewBookingPayments','==',true).get();
  const recipients=new Set([b.customerId,b.ownerId,...reviewers.docs.filter(s=>!s.data().isBlocked).map(s=>s.id),...admins.docs.filter(s=>!s.data().isBlocked).map(s=>s.id)]);
  for (const userId of recipients) {
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
    if(b.status==='held' && b.holdUntil<=Date.now()) tx.update(s.ref,{status:'expired',version:b.version+1,updatedAt:FieldValue.serverTimestamp()});
  });
});
