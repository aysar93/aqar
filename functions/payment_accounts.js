const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
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
exports.createSubscriptionPayment = onCall(async r => {
  const d = r.data || {}, db = getFirestore();
  const collection = d.legacy === true ? 'subscriptions' : 'office_subscriptions';
  const subRef = db.doc(`${collection}/${identifier(d.subscriptionId)}`);
  const ref = db.doc(`subscription_payments/${r.auth?.uid}_${identifier(d.subscriptionId)}`);
  await db.runTransaction(async tx => {
    await actor(r, tx);
    const existing = await tx.get(ref);
    const sub = (await tx.get(subRef)).data();
    if (!sub || (sub.ownerId || sub.ownerUid) !== r.auth.uid) throw new HttpsError('permission-denied', 'الاشتراك خاص');
    if (existing.exists) return;
    const office = (await tx.get(db.doc(`offices/${identifier(sub.officeId)}`))).data();
    const pkg = (await tx.get(db.doc(`subscription_packages/${identifier(sub.packageId)}`))).data();
    const config = (await tx.get(db.doc(CONFIG))).data();
    const snapshot = recipient(config, d.paymentMethod, d.expectedNumber);
    if (office?.ownerId !== r.auth.uid || !['pending','pending_payment'].includes(sub.status) || pkg?.isActive !== true || !Number.isFinite(pkg.price) || pkg.price < 0) throw new HttpsError('failed-precondition', 'طلب اشتراك غير صالح');
    const receiptUrl = optionalText(d.receiptUrl, 2048), transactionId = optionalText(d.transactionId, 200);
    if (!/^https:\/\/res\.cloudinary\.com\//.test(receiptUrl) || !transactionId) throw new HttpsError('invalid-argument', 'الإيصال ورقم التحويل مطلوبان');
    tx.create(ref, {officeId:sub.officeId,ownerUid:r.auth.uid,subscriptionId:subRef.id,packageId:sub.packageId,packageName:pkg.name || '',amount:pkg.price,currency:pkg.currency || 'IQD',status:'pending',paymentMethod:d.paymentMethod,transactionId,receiptUrl,notes:optionalText(d.notes,1000),paymentAccount:snapshot.number,paymentAccountSnapshot:snapshot,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    tx.update(subRef, {paymentId:ref.id,paymentStatus:'pending',paymentMethod:d.paymentMethod,paymentReference:transactionId,updatedAt:FieldValue.serverTimestamp()});
  });
  return {id:ref.id};
});
exports.CONFIG = CONFIG;
exports.available = available;
exports.recipient = recipient;
exports.normalize = normalize;
exports.validNumber = validNumber;
