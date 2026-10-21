const {test}=require('node:test');
const assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185'||process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('Isolated demo emulator required');
require('firebase-admin/app').initializeApp({projectId:'demo-aqar'});
const db=require('firebase-admin/firestore').getFirestore();
const f=require('./booking_functions');
const call=(id,action='settleOwner',uid='preview_reviewer')=>f.getBookingFinancePreview.run({auth:{uid},data:{bookingId:id,action}});
async function fixture(id,patch={}){
 await db.doc('users/preview_reviewer').set({isBlocked:false,canReviewBookingPayments:true});
 await db.doc('booking_venues/preview_venue').set({ownerId:'preview_owner',active:true});
 const b={venueId:'preview_venue',ownerId:'preview_owner',customerId:'preview_customer',ownerName:'SYNTHETIC OWNER',status:'completed',version:3,paid:1001,commissionBps:333,commissionBasis:'deposit',...patch};
 await db.doc('bookings/'+id).set(b);return b;
}
async function unchanged(id,b){
 assert.deepEqual((await db.doc('bookings/'+id).get()).data(),b);
 for(const c of ['booking_ledger','booking_action_audit'])assert.equal((await db.collection(c).where('bookingId','==',id).get()).size,0);
}
test('preview reuses integer settlement policy and writes nothing',async()=>{
 const id='preview_valid_owner',b=await fixture(id);
 const p=await call(id);assert.equal(p.amount,968);assert.equal(p.version,3);assert.equal(p.beneficiary.id,b.ownerId);assert.equal(p.reason,'completed_booking');await unchanged(id,b);
});
test('refund preview uses known booking beneficiary and no invented profile name',async()=>{
 const id='preview_valid_refund',b=await fixture(id,{status:'cancelled',refundStatus:'pending',refundDue:501,refunded:0});
 const p=await call(id,'settleRefund');assert.equal(p.amount,501);assert.equal(p.beneficiary.id,b.customerId);assert.equal(p.beneficiary.name,null);await unchanged(id,b);
});
test('legacy unknown money and invalid state fail closed without writes',async()=>{
 let n=0;for(const patch of [{paid:null},{paid:'1001'},{commissionBps:null},{commissionBasis:null},{status:'confirmed'},{ownerSettlementStatus:'settled'},{refundStatus:'pending'}]){
 const id='preview_bad_'+n++,b=await fixture(id,patch);await assert.rejects(call(id));await unchanged(id,b);
 }
});
test('current finance permission, independence and active staff are checked on every read',async()=>{
 const id='preview_permissions',b=await fixture(id);
 for(const patch of [{canReviewBookingPayments:false,isAdmin:true},{canReviewBookingPayments:true,isBlocked:true}]){
 await db.doc('users/preview_reviewer').set(patch);await assert.rejects(call(id));
 }
 await fixture(id);await db.doc('users/preview_owner').set({canReviewBookingPayments:true,isBlocked:false});await assert.rejects(call(id,'settleOwner','preview_owner'));
 await db.doc('booking_venue_staff/preview_venue_preview_reviewer').set({ownerId:'preview_owner',scopes:['bookings']});await assert.rejects(call(id));await db.doc('booking_venue_staff/preview_venue_preview_reviewer').delete();await unchanged(id,b);
});
