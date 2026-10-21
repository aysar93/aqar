const {test}=require('node:test');
const assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185'||process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('Local demo emulator required');
require('firebase-admin/app').initializeApp({projectId:'demo-aqar'});
const db=require('firebase-admin/firestore').getFirestore(),f=require('./booking_functions');
test('request committed before a lost response can be retried concurrently without duplicate intent',async()=>{
 const customer='checkout_lost_customer',owner='checkout_lost_owner',venue='checkout_lost_venue',id=customer+'_stable_intent';
 try {
  for(const uid of [customer,owner])await db.doc('users/'+uid).set({name:'Synthetic',phone:'00000000000',isBlocked:false});
  const cancellationPolicy={freeCancellationHours:24,lateRefundPercent:25};
  await db.doc('booking_venues/'+venue).set({name:'Synthetic',location:'Anbar',category:'chalet',ownerId:owner,active:true,price:250000,deposit:50000,terms:'Synthetic terms',cancellationPolicy});
  const start=Date.now()+2*86400000;
  const data=Object.freeze({venueId:venue,requestId:'stable_intent',start,end:start+3600000,price:250000,deposit:50000,acceptedTerms:'Synthetic terms',cancellationPolicy,notes:'one intent'});
  async function transport(deliver){const result=await f.requestBooking.run({auth:{uid:customer},data});if(!deliver)throw Error('SIMULATED_RESPONSE_LOSS_AFTER_COMMIT');return result;}
  await assert.rejects(transport(false),/SIMULATED_RESPONSE_LOSS_AFTER_COMMIT/);
  const before=(await db.doc('bookings/'+id).get()).data();assert(before);
  const replies=await Promise.all([transport(true),transport(true)]);assert.deepEqual(replies,[{id},{id}]);
  assert.deepEqual((await db.doc('bookings/'+id).get()).data(),before);
  assert.equal((await db.collection('bookings').where('venueId','==',venue).get()).size,1);
  assert.equal((await db.collection('booking_action_audit').where('bookingId','==',id).get()).size,1);
  assert.equal((await db.doc('booking_venues/'+venue).get()).data().bookingRevision,1);
  assert.equal((await db.collection('booking_ledger').where('bookingId','==',id).get()).size,0);
 } finally {
  for(const col of ['booking_action_audit','booking_ledger'])for(const doc of (await db.collection(col).where('bookingId','==',id).get()).docs)await doc.ref.delete();
  for(const path of ['bookings/'+id,'booking_venues/'+venue,'users/'+customer,'users/'+owner])await db.doc(path).delete();
 }
});
