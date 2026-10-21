const {test}=require('node:test');
const assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185'||process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('Isolated demo emulator required');
require('firebase-admin/app').initializeApp({projectId:'demo-aqar'});
const db=require('firebase-admin/firestore').getFirestore(),f=require('./booking_functions');
test('chat successful-response suppression preserves one message and rate record across concurrent retries and rejects a foreign session',async()=>{
 const owner='chat_recovery_owner',customer='chat_recovery_customer',other='chat_recovery_other',bookingId='chat_recovery_booking';
 const payload=Object.freeze({bookingId,requestId:'stable_message',message:'Synthetic arrival question'});
 const path=`booking_messages/${bookingId}/messages/${customer}_stable_message`,rate=`booking_message_limits/${bookingId}_${customer}`;
 const call=(uid)=>f.sendBookingMessage.run({auth:{uid},data:payload});
 try{
  for(const uid of [owner,customer,other])await db.doc('users/'+uid).set({isBlocked:false});
  await db.doc('bookings/'+bookingId).set({ownerId:owner,customerId:customer,status:'confirmed'});
  const initialBooking=(await db.doc('bookings/'+bookingId).get()).data();
  await call(customer); // Intentionally discard the successful application response.
  const initial=(await db.doc(path).get()).data(),initialRate=(await db.doc(rate).get()).data();
  await Promise.all([call(customer),call(customer)]);
  assert.deepEqual((await db.doc(path).get()).data(),initial);
  assert.deepEqual((await db.doc(rate).get()).data(),initialRate);
  assert.equal((await db.collection(`booking_messages/${bookingId}/messages`).get()).size,1);
  await assert.rejects(call(other));
  await db.doc('users/'+customer).update({isBlocked:true});
  await assert.rejects(call(customer));
  assert.deepEqual((await db.doc('bookings/'+bookingId).get()).data(),initialBooking);
 }finally{
  for(const uid of [owner,customer,other])await db.doc('users/'+uid).delete();
  for(const doc of [path,rate,'bookings/'+bookingId])await db.doc(doc).delete();
 }
});
