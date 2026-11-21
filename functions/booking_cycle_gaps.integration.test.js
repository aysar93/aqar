const {test}=require('node:test');
const assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185'||process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:9198'||process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('Isolated demo emulators required');
require('firebase-admin/app').initializeApp({projectId:'demo-aqar',storageBucket:'demo-aqar.appspot.com'});
const db=require('firebase-admin/firestore').getFirestore();
const f=require('./booking_functions');
const p=require('./booking_policy');
const call=(name,uid,data)=>f[name].run({auth:{uid},data});
const cp={freeCancellationHours:24,lateRefundPercent:15};
async function fixture(id,status='confirmed'){
 for(const [uid,flags]of Object.entries({cg_customer:{canReviewBookingPayments:true},cg_owner:{canReviewBookingPayments:true},cg_admin:{isAdmin:true},cg_finance:{canReviewBookingPayments:true},cg_staff:{canReviewBookingPayments:true},cg_other:{}}))await db.doc('users/'+uid).set({name:'Synthetic UAT',phone:'07000000000',isBlocked:false,...flags});
 await db.doc('booking_venues/cg_venue').set({ownerId:'cg_owner',active:true,name:'Synthetic',location:'Anbar',category:'farm',price:100000,deposit:20000,terms:'terms',cancellationPolicy:cp});
 await db.doc('booking_venue_staff/cg_venue_cg_staff').set({ownerId:'cg_owner',scopes:['bookings']});
 await db.doc('bookings/'+id).set({venueId:'cg_venue',customerId:'cg_customer',ownerId:'cg_owner',status,total:100000,deposit:20000,paid:status==='confirmed'?20000:0,remaining:status==='confirmed'?80000:100000,start:Date.now()+48*3600000,end:Date.now()+49*3600000,cancellationPolicy:cp,version:0});
}
test('cancellation awaiting receipt review then financial rejection releases slot without fictitious refund or ledger',async()=>{
 const id='cg_rejected_review';await fixture(id,'payment_review');
 await call('actOnBooking','cg_customer',{bookingId:id,action:'cancel',reason:'synthetic'});
 const pending=(await db.doc('bookings/'+id).get()).data();assert.equal(pending.status,'cancel_requested');assert.equal(pending.cancellationByVenue,false);
 await call('actOnBooking','cg_finance',{bookingId:id,action:'rejectPayment',reason:'synthetic transfer not received'});
 const b=(await db.doc('bookings/'+id).get()).data();assert.equal(b.status,'cancelled');assert.equal(b.refundDue,0);assert.equal(b.refundStatus,'none');assert.equal(b.paid,0);assert.equal(b.remaining,0);assert.equal(b.version,2);
 assert.equal(p.blocks(b,Date.now()),false);assert.equal((await db.collection('booking_ledger').where('bookingId','==',id).get()).size,0);
 await assert.rejects(call('actOnBooking','cg_finance',{bookingId:id,action:'settleRefund',refundReference:'synthetic'}));
});
test('late customer cancellation uses stored policy despite venue changes and rejects involved reviewers',async()=>{
 const id='cg_late_cancel';await fixture(id);await db.doc('bookings/'+id).update({start:Date.now()+3600000});
 await db.doc('booking_venues/cg_venue').update({price:900000,deposit:100000,cancellationPolicy:{freeCancellationHours:0,lateRefundPercent:100}});
 await call('actOnBooking','cg_customer',{bookingId:id,action:'cancel',reason:'synthetic'});
 let b=(await db.doc('bookings/'+id).get()).data();assert.equal(b.cancellationByVenue,false);assert.equal(b.refundDue,3000);assert.equal(b.total,100000);assert.equal(b.deposit,20000);assert.deepEqual(b.cancellationPolicy,cp);
 for(const uid of ['cg_customer','cg_owner','cg_staff','cg_admin','cg_other'])await assert.rejects(call('actOnBooking',uid,{bookingId:id,action:'settleRefund',refundReference:'synthetic'}));
 await call('actOnBooking','cg_finance',{bookingId:id,action:'settleRefund',refundReference:'NO-REAL-TRANSFER'});
 b=(await db.doc('bookings/'+id).get()).data();assert.equal(b.refunded,3000);assert.equal(b.refundSettledBy,'cg_finance');assert.equal((await db.collection('booking_ledger').where('bookingId','==',id).get()).size,1);
});
test('request retry after committed server success returns same booking and one request audit',async()=>{
 await fixture('cg_setup');const start=Date.now()+7*86400000;
 const data={venueId:'cg_venue',requestId:'lost_response',start,end:start+3600000,price:100000,deposit:20000,acceptedTerms:'terms',cancellationPolicy:cp};
 const first=await call('requestBooking','cg_customer',data);const again=await call('requestBooking','cg_customer',data);assert.equal(first.id,again.id);
 assert.equal((await db.collection('booking_action_audit').where('bookingId','==',first.id).get()).size,1);
 assert.equal((await db.collection('bookings').where('customerId','==','cg_customer').get()).docs.filter(x=>x.id===first.id).length,1);
});
test('owner and admin cancellation retain full refund responsibility without an isAdmin field for owner',async()=>{
 for(const uid of ['cg_owner','cg_admin']){
  const id='cg_venue_cancel_'+uid;await fixture(id);await db.doc('bookings/'+id).update({start:Date.now()+3600000});
  await call('actOnBooking',uid,{bookingId:id,action:'cancel',reason:'synthetic'});
  const b=(await db.doc('bookings/'+id).get()).data();assert.equal(b.cancellationByVenue,true);assert.equal(b.refundDue,20000);assert.equal(b.status,'cancelled');
 }
});
test('cutoff exact millisecond and integer rounding remain deterministic with unpaid and owner cancellation',()=>{
 const b={paid:1001,start:48*3600000,cancellationPolicy:cp};const boundary=24*3600000;
 assert.equal(p.refund(b,boundary,false),1001);assert.equal(p.refund(b,boundary+1,false),150);assert.equal(p.refund(b,boundary+1,true),1001);assert.equal(p.refund({...b,paid:0},boundary+1,false),0);
});
