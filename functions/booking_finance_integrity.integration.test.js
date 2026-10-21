const {test}=require('node:test');
const assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185'||process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('Isolated demo emulators required');
require('firebase-admin/app').initializeApp({projectId:'demo-aqar'});
const db=require('firebase-admin/firestore').getFirestore();
const f=require('./booking_functions');
const call=(bookingId,action)=>f.actOnBooking.run({auth:{uid:'integrity_reviewer'},data:{bookingId,action,settlementReference:'SYNTHETIC-NO-TRANSFER',refundReference:'SYNTHETIC-NO-TRANSFER'}});
async function fixture(id,patch={}) {
  await db.doc('users/integrity_reviewer').set({isBlocked:false,canReviewBookingPayments:true});
  await db.doc('users/integrity_owner').set({isBlocked:false});
  await db.doc('booking_venues/integrity_venue').set({ownerId:'integrity_owner',active:true});
  const b={venueId:'integrity_venue',ownerId:'integrity_owner',customerId:'integrity_customer',status:'completed',version:0,paid:1001,commissionBps:333,commissionBasis:'deposit',...patch};
  await db.doc('bookings/'+id).set(b);return b;
}
async function unchanged(id,b,action) {
  await assert.rejects(call(id,action),e=>e.code==='failed-precondition');
  assert.deepEqual((await db.doc('bookings/'+id).get()).data(),b);
  for(const col of ['booking_ledger','booking_action_audit'])assert.equal((await db.collection(col).where('bookingId','==',id).get()).size,0);
}
test('unsafe historical financial actions leave booking, audit and ledger unchanged',async()=>{
  let n=0;
  for(const patch of [{paid:null},{paid:'1001'},{commissionBps:null},{commissionBasis:null},{refunded:1002},{refundStatus:'settled'}]) {
    const id='integrity_bad_owner_'+n++;await unchanged(id,await fixture(id,patch),'settleOwner');
  }
  for(const patch of [{refundDue:null},{refundDue:'1001'},{refundDue:1002},{refunded:null}]) {
    const id='integrity_bad_refund_'+n++;
    await unchanged(id,await fixture(id,{status:'cancelled',refundStatus:'pending',refundDue:1001,refunded:0,...patch}),'settleRefund');
  }
  const id='integrity_bad_deposit';
  await unchanged(id,await fixture(id,{status:'payment_review',total:100000,deposit:'1001'}),'confirmPayment');
});
test('simultaneous valid owner settlements produce exactly one ledger entry',async()=>{
  const id='integrity_valid_owner';await fixture(id);
  const results=await Promise.allSettled([call(id,'settleOwner'),call(id,'settleOwner')]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const b=(await db.doc('bookings/'+id).get()).data();
  assert.equal(b.ownerSettled,968);assert.equal(b.platformCommission,33);assert.equal(b.version,1);
  assert.equal((await db.collection('booking_ledger').where('bookingId','==',id).get()).size,1);
  assert.equal((await db.collection('booking_action_audit').where('bookingId','==',id).get()).size,1);
});

test('revoked or blocked reviewer cannot settle using a previously authorized identity',async()=>{
  for(const patch of [{canReviewBookingPayments:false},{isBlocked:true}]) {
    const id='integrity_revoked_'+Object.keys(patch)[0];
    const b=await fixture(id);
    await db.doc('users/integrity_reviewer').update(patch);
    await assert.rejects(call(id,'settleOwner'));
    assert.deepEqual((await db.doc('bookings/'+id).get()).data(),b);
    for(const col of ['booking_ledger','booking_action_audit'])
      assert.equal((await db.collection(col).where('bookingId','==',id).get()).size,0);
  }
});
