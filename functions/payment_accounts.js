const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {createHash} = require('node:crypto');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const METHODS = ['qicard', 'zaincash'];
const CONFIG = 'payment_configuration/shared';
const PUBLIC = 'payment_accounts/shared';
function validNumber(method, number) {
  return METHODS.includes(method) && typeof number === 'string' && (method === 'qicard' ? /^[0-9]{10,16}$/ : /^07[0-9]{9}$/).test(number);
}
function normalize(input) {
  if (!input || typeof input !== 'object' || Object.keys(input).some(k => !METHODS.includes(k))) throw new HttpsError('invalid-argument', 'حسابات غير صالحة');
  return Object.fromEntries(METHODS.map(method => {
    const c = input[method];
    if (!c || typeof c.enabled !== 'boolean' || typeof c.number !== 'string' || Object.keys(c).some(k => !['number','enabled'].includes(k))) throw new HttpsError('invalid-argument', 'حساب غير صالح');
    const number = c.number.trim();
    if (number && !validNumber(method, number) || c.enabled && !number) throw new HttpsError('invalid-argument', 'رقم حساب غير صالح');
    return [method, {number, enabled:c.enabled}];
  }));
}
function available(config) {
  return Object.fromEntries(METHODS.filter(m => config?.methods?.[m]?.enabled === true && validNumber(m, config.methods[m].number)).map(m => [m, {number:config.methods[m].number, account:config.methods[m].number, enabled:true}]));
}
function recipient(config, method, expectedNumber) {
  const account = available(config)[method];
  if (!account) throw new HttpsError('failed-precondition', 'طريقة الدفع غير متاحة');
  if (expectedNumber !== account.number) throw new HttpsError('failed-precondition', 'تغير حساب التحويل؛ راجع الحساب الحالي قبل الدفع');
  return {method, number:account.number, revision:config.revision};
}
async function actor(r, tx) {
  if (!r.auth || r.auth.token?.firebase?.sign_in_provider === 'anonymous') throw new HttpsError('unauthenticated', 'سجل الدخول');
  const ref = getFirestore().doc(`users/${r.auth.uid}`);
  const u = (await (tx ? tx.get(ref) : ref.get())).data();
  if (!u || u.isBlocked) throw new HttpsError('permission-denied', 'الحساب غير متاح');
  return u;
}
function manager(r, u) {
  if (u.isAdmin !== true || r.auth.token?.canManagePaymentAccounts !== true) throw new HttpsError('permission-denied', 'مدير مخوّل مطلوب');
}
exports.getPaymentAccountSettings = onCall(async r => {
  manager(r, await actor(r));
  return (await getFirestore().doc(CONFIG).get()).data() || {revision:0, methods:{qicard:{number:'',enabled:false},zaincash:{number:'',enabled:false}}};
});
exports.savePaymentAccountSettings = onCall(async r => {
  const methods = normalize(r.data?.methods), db = getFirestore();
  await db.runTransaction(async tx => {
    manager(r, await actor(r, tx));
    const ref = db.doc(CONFIG), before = (await tx.get(ref)).data() || {revision:0};
    if (r.data.revision !== before.revision) throw new HttpsError('aborted', 'تغيرت الإعدادات؛ أعد فتح الصفحة');
    const after = {methods, revision:before.revision+1};
    tx.set(ref, after);
    tx.set(db.doc(PUBLIC), {methods:available(after), revision:after.revision});
    tx.create(db.collection('payment_account_audit').doc(), {actorUid:r.auth.uid, before, after, createdAt:FieldValue.serverTimestamp()});
  });
  return {ok:true};
});
function identifier(v) {
  if (typeof v !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(v)) throw new HttpsError('invalid-argument', 'معرف غير صالح');
  return v;
}
function optionalText(v, max) {
  if (v == null) return '';
  if (typeof v !== 'string' || v.length > max) throw new HttpsError('invalid-argument', 'بيانات غير صالحة');
  return v.trim();
}
function packageSnapshot(pkg) {
  if (!Number.isSafeInteger(pkg.durationDays) || pkg.durationDays < 1 || pkg.durationDays > 3660) throw new HttpsError('failed-precondition','مدة الباقة غير صالحة');
  for (const k of ['maxProperties','maxFeaturedProperties']) if (pkg[k] != null && (!Number.isSafeInteger(pkg[k]) || pkg[k]<0)) throw new HttpsError('failed-precondition','حدود الباقة غير صالحة');
  return {packageName:pkg.name || '',durationDays:pkg.durationDays,price:pkg.price,currency:pkg.currency || 'IQD',maxProperties:pkg.maxProperties || 0,maxFeaturedProperties:pkg.maxFeaturedProperties || 0,canFeatureProperties:pkg.featuredPropertiesEnabled === true,canAppearInFeaturedOffices:pkg.featuredOfficeEnabled === true,canUseAdvancedStatistics:pkg.statisticsEnabled !== false};
}
exports.createSubscriptionPayment = onCall(async r => {
  const d = r.data || {}, db = getFirestore();
  await actor(r);
  const collection = d.legacy === true ? 'subscriptions' : 'office_subscriptions';
  const subRef = db.doc(`${collection}/${identifier(d.subscriptionId)}`);
  const ref = db.doc(`subscription_payments/${d.legacy === true ? 'legacy_' : ''}${r.auth?.uid}_${identifier(d.subscriptionId)}`);
  await db.runTransaction(async tx => {
    await actor(r, tx);
    const existing = await tx.get(ref);
    const sub = (await tx.get(subRef)).data();
    if (!sub || (sub.ownerId || sub.ownerUid) !== r.auth.uid) throw new HttpsError('permission-denied', 'الاشتراك خاص');
    if (existing.exists) {
      const p = existing.data();
      if (p.ownerUid !== r.auth.uid || p.subscriptionId !== subRef.id || p.officeId !== sub.officeId || (p.subscriptionCollection || 'office_subscriptions') !== collection) throw new HttpsError('failed-precondition', 'طلب دفع متعارض يحتاج مراجعة');
      return;
    }
    const office = (await tx.get(db.doc(`offices/${identifier(sub.officeId)}`))).data();
    const pkg = (await tx.get(db.doc(`subscription_packages/${identifier(sub.packageId)}`))).data();
    const config = (await tx.get(db.doc(CONFIG))).data();
    const snapshot = recipient(config, d.paymentMethod, d.expectedNumber);
    if (office?.ownerId !== r.auth.uid || !['pending','pending_payment'].includes(sub.status) || pkg?.isActive !== true || !Number.isSafeInteger(pkg.price) || pkg.price <= 0 || (pkg.currency || 'IQD') !== 'IQD') throw new HttpsError('failed-precondition', 'طلب اشتراك غير صالح');
    const receiptPath = optionalText(d.receiptPath,512), transactionId = optionalText(d.transactionId, 200);
    if (!receiptPath.startsWith(`subscription_receipts/${subRef.id}/${r.auth.uid}/`) || !/\/[0-9]+\.jpg$/.test(receiptPath) || !transactionId) throw new HttpsError('invalid-argument', 'الإيصال ورقم التحويل مطلوبان');
    const [meta]=await getStorage().bucket().file(receiptPath).getMetadata();
    if(meta.contentType !== 'image/jpeg' || !Number.isSafeInteger(Number(meta.size)) || Number(meta.size)<=0 || Number(meta.size)>10*1024*1024) throw new HttpsError('invalid-argument','إيصال غير صالح');
    tx.create(ref, {officeId:sub.officeId,ownerUid:r.auth.uid,subscriptionId:subRef.id,subscriptionCollection:collection,packageId:sub.packageId,packageName:pkg.name || '',amount:pkg.price,currency:pkg.currency || 'IQD',status:'pending',paymentMethod:d.paymentMethod,transactionId,receiptPath,receiptUrl:'',notes:optionalText(d.notes,1000),paymentAccount:snapshot.number,paymentAccountSnapshot:snapshot,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    tx.update(subRef, {...(collection === 'office_subscriptions' ? packageSnapshot(pkg) : {}),paymentId:ref.id,paymentStatus:'pending',paymentMethod:d.paymentMethod,paymentReference:transactionId,updatedAt:FieldValue.serverTimestamp()});
  });
  return {id:ref.id};
});

exports.reviewOfficeSubscription = onCall(async r => {
  const db=getFirestore(), subRef=db.doc(`office_subscriptions/${identifier(r.data?.subscriptionId)}`);
  if (!['approve','reject'].includes(r.data?.action)) throw new HttpsError('invalid-argument','إجراء غير صالح');
  await db.runTransaction(async tx => {
    const u=await actor(r,tx);
    if(u.isAdmin !== true) throw new HttpsError('permission-denied','للإدارة فقط');
    const sub=(await tx.get(subRef)).data();
    if(!sub || sub.status !== 'pending') throw new HttpsError('failed-precondition','الطلب ليس قيد المراجعة');
    const officeRef=db.doc(`offices/${identifier(sub.officeId)}`),office=(await tx.get(officeRef)).data();
    if(!office || [sub.ownerId,office.ownerId].includes(r.auth.uid)) throw new HttpsError('permission-denied','مراجع مستقل مطلوب');
    if(office.ownerId !== sub.ownerId) throw new HttpsError('failed-precondition','تغير مالك المكتب؛ يلزم تسوية مستقلة');
    const payments=await tx.get(db.collection('subscription_payments').where('subscriptionId','==',subRef.id));
    const matches=payments.docs.filter(s=>s.data().officeId===sub.officeId && (s.data().subscriptionCollection || 'office_subscriptions')==='office_subscriptions');
    if(matches.length !== 1 || matches[0].data().status !== 'pending' || matches[0].data().ownerUid !== sub.ownerId) throw new HttpsError('failed-precondition','طلب دفع واحد قيد المراجعة مطلوب');
    const payment=matches[0],p=payment.data();
    const active=await tx.get(db.collection('office_subscriptions').where('officeId','==',sub.officeId).where('status','==','active'));
    const now=Date.now();
    const current=active.docs.filter(s=>s.data().endDate?.toMillis()>now);
    if(current.length>1 && r.data.action==='approve') throw new HttpsError('failed-precondition','اشتراكات فعالة متعارضة تحتاج تسوية');
    let patch={status:'cancelled',paymentStatus:'rejected',updatedAt:FieldValue.serverTimestamp()};
    if(r.data.action==='approve') {
      // New requests carry a server-normalized contract; old pending requests
      // must match the package before any entitlements can be activated.
      let contract=sub;
      if(!p.paymentAccountSnapshot) {
        const pkg=(await tx.get(db.doc(`subscription_packages/${identifier(sub.packageId)}`))).data();
        if(!pkg || pkg.price !== p.amount) throw new HttpsError('failed-precondition','راجع عقد الدفع القديم');
        contract=packageSnapshot(pkg);
        if(['durationDays','price','currency','maxProperties','maxFeaturedProperties','canFeatureProperties','canAppearInFeaturedOffices','canUseAdvancedStatistics'].some(k=>sub[k] !== contract[k])) throw new HttpsError('failed-precondition','عقد قديم تغيرت شروطه؛ يلزم توثيق التسوية قبل الاعتماد');
      }
      if(!Number.isSafeInteger(contract.durationDays) || contract.durationDays<1 || contract.durationDays>3660 || contract.price !== p.amount) throw new HttpsError('failed-precondition','عقد الاشتراك غير صالح');
      const previous=current[0]?.data(),base=Math.max(now,previous?.endDate?.toMillis() || now);
      let limit=contract.maxFeaturedProperties || 0;
      if(previous?.canFeatureProperties === true && contract.canFeatureProperties === true) limit=limit<=0 || previous.maxFeaturedProperties<=0 ? 0 : limit+Math.max(0,previous.maxFeaturedProperties-(previous.featuredPropertiesUsed || 0));
      patch={...packageSnapshot({name:contract.packageName,durationDays:contract.durationDays,price:contract.price,currency:contract.currency,maxProperties:contract.maxProperties,maxFeaturedProperties:contract.maxFeaturedProperties,featuredPropertiesEnabled:contract.canFeatureProperties,featuredOfficeEnabled:contract.canAppearInFeaturedOffices,statisticsEnabled:contract.canUseAdvancedStatistics}),status:'active',paymentStatus:'paid',startDate:Timestamp.fromMillis(now),endDate:Timestamp.fromMillis(base+contract.durationDays*86400000),maxFeaturedProperties:limit,featuredPropertiesUsed:0,updatedAt:FieldValue.serverTimestamp()};
      for(const old of current) tx.update(old.ref,{status:'expired',replacedBy:subRef.id,updatedAt:FieldValue.serverTimestamp()});
      tx.update(officeRef,{subscriptionId:subRef.id,subscriptionStatus:'active',subscriptionStartDate:patch.startDate,subscriptionEndDate:patch.endDate,updatedAt:FieldValue.serverTimestamp()});
    }
    tx.update(subRef,patch);
    tx.update(payment.ref,{status:r.data.action==='approve'?'approved':'rejected',approvedBy:r.auth.uid,...(r.data.action==='approve'?{approvedAt:FieldValue.serverTimestamp()}:{}),updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('subscription_review_audit').doc(),{subscriptionId:subRef.id,paymentId:payment.id,actorUid:r.auth.uid,action:r.data.action,before:sub,after:patch,createdAt:FieldValue.serverTimestamp()});
  });
  return {ok:true};
});
exports.CONFIG = CONFIG;
// Trigger delivery is at least once. Stable event keys preserve each transition once.
exports.auditSubscriptionPayment = onDocumentWritten({document:'subscription_payments/{paymentId}',retry:true}, async event => {
  const before = event.data.before.data() || null, after = event.data.after.data() || null;
  const key = createHash('sha256').update(event.id).digest('hex');
  try {
    await getFirestore().doc(`subscription_payment_audit/${key}`).create({paymentId:event.params.paymentId,eventId:event.id,before,after,actorUid:after?.approvedBy || null,createdAt:FieldValue.serverTimestamp()});
  } catch(e) { if (e.code !== 6) throw e; }
});
exports.available = available;
exports.recipient = recipient;
exports.normalize = normalize;
exports.validNumber = validNumber;
