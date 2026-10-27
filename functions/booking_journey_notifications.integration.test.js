const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
if(process.env.GCLOUD_PROJECT!=='demo-aqar'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185'||process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:9198')throw Error('LOCAL_DEMO_ONLY');
require('../tool/booking_network/loopback-only.cjs');
require('firebase-admin/app').initializeApp({projectId:'demo-aqar',storageBucket:'demo-aqar.appspot.com'});
const db=require('firebase-admin/firestore').getFirestore(),bucket=require('firebase-admin/storage').getStorage().bucket(),f=require('./booking_functions');
const call=(name,uid,data)=>f[name].run({auth:{uid},data});
test('new coverage: every journey state joins calendar and retry-safe booking notification payload',async()=>{
 const prefix='journey_link',owner=prefix+'_owner',customer=prefix+'_customer',finance=prefix+'_finance',admin=prefix+'_admin',blocked=prefix+'_blocked',venue=prefix+'_venue',id=customer+'_one_intent';
 const events=[],paths=['payment_configuration/shared','booking_venues/'+venue,...[owner,customer,finance,admin,blocked].map(u=>'users/'+u)],at=new Date().toISOString();
 const cp={freeCancellationHours:24,lateRefundPercent:20},start=Date.now()+3*86400000,end=start+3600000;
 let receipt,seeded=false;
 try{
  assert.equal((await db.collection('users').limit(1).get()).size,0,'Fresh isolated emulator required');
  for(const p of paths)assert.equal((await db.doc(p).get()).exists,false,'Fixture path already exists');
  seeded=true;
  for(const uid of [owner,customer,finance,admin,blocked])await db.doc('users/'+uid).set({name:uid,phone:'00000000000',isAdmin:uid===admin,canReviewBookingPayments:uid===finance||uid===blocked,isBlocked:uid===blocked});
  // Local fake recipient only, never a provider transaction or cloud setting.
  await db.doc('payment_configuration/shared').set({revision:1,methods:{qicard:{enabled:true,number:'0000000000'},zaincash:{enabled:false,number:''}}});
  await db.doc('booking_venues/'+venue).set({ownerId:owner,active:true,name:'SYNTHETIC LOCAL JOURNEY',location:'LOCAL',category:'chalet',price:250000,deposit:50000,terms:'LOCAL ONLY',cancellationPolicy:cp});
  let before=await db.doc('bookings/'+id).get();
  async function checkpoint(expected,state){
   const after=await db.doc('bookings/'+id).get(),b=after.data();assert.equal(b.status,expected);
   const event={params:{bookingId:id},data:{before,after}};
   await f.bookingNotifications.run(event);await f.bookingNotifications.run(event);
   const notes=(await db.collection('notifications').where('bookingId','==',id).get()).docs.filter(d=>d.id.startsWith('booking_'+id+'_'+b.version+'_'));
   assert.equal(notes.length,4);assert.deepEqual(notes.map(d=>d.data().userId).sort(),[owner,customer,finance,admin].sort());
   for(const d of notes){const n=d.data();assert.equal(n.type,'booking');assert.equal(n.bookingId,id);assert.equal(n.deliveryType,'external');assert(n.message.includes(b.customerName));assert(n.message.includes(b.venueName));assert(n.message.includes(state));}
   const availability=await call('getBookingAvailability',customer,{venueId:venue,start:start-1,end:end+1});
   assert.equal(availability.slots.length,1);
   if(availability.slots.length){assert.equal(availability.slots[0].state,expected==='confirmed'?'confirmed':'pending');assert(!JSON.stringify(availability).includes(customer));}
   assert.equal(b.customerName,customer);assert.equal(b.ownerName,owner);assert.equal(b.total,250000);assert.equal(b.deposit,50000);
   events.push({atUtc:new Date().toISOString(),status:b.status,version:b.version,notifications:notes.length,availability:availability.slots,paid:b.paid,remaining:b.remaining});before=after;
  }
  await call('requestBooking',customer,{venueId:venue,requestId:'one_intent',start,end,price:250000,deposit:50000,acceptedTerms:'LOCAL ONLY',cancellationPolicy:cp});
  await checkpoint('requested','طلب جديد');
  await call('actOnBooking',owner,{bookingId:id,action:'approve'});await checkpoint('held','حجز مؤقت');
  receipt=`booking_receipts/${id}/${customer}/123.jpg`;await bucket.file(receipt).save(await require('sharp')({create:{width:32,height:32,channels:3,background:'blue'}}).jpeg().toBuffer(),{resumable:false,metadata:{contentType:'image/jpeg'}});
  await call('actOnBooking',customer,{bookingId:id,action:'submitPayment',receiptPath:receipt,method:'qicard',expectedNumber:'0000000000',transactionNumber:'LOCAL-NO-TRANSFER'});await checkpoint('payment_review','مراجعة العربون');
  await call('actOnBooking',finance,{bookingId:id,action:'confirmPayment'});await checkpoint('confirmed','حجز مؤكد');
  const b=before.data();assert.equal(b.paid,50000);assert.equal(b.remaining,200000);
  assert.equal((await db.collection('booking_ledger').where('bookingId','==',id).get()).size,1);
  assert.equal((await db.collection('notifications').where('bookingId','==',id).get()).size,16);
  if(process.env.JOURNEY_EVIDENCE)fs.writeFileSync(process.env.JOURNEY_EVIDENCE,JSON.stringify({startedAt:at,completedAt:new Date().toISOString(),project:'demo-aqar',result:'PASS_LOCAL_ORIGINAL_BACKEND_JOURNEY_NOTIFICATION_CALENDAR_JOIN',events,ledger:1,notifications:16,realPushDelivered:false,externalWrites:0,limits:['Original callable handlers with synthetic auth context; not native sign-in or UI E2E','Firestore trigger invoked twice per version; FCM not called','No cloud or device acceptance']},null,2));
 }finally{
  if(seeded){
   if(receipt)await bucket.file(receipt).delete({ignoreNotFound:true});
   await db.doc('bookings/'+id).delete();
   for(const col of ['booking_action_audit','booking_ledger','booking_payment_references','notifications'])for(const d of (await db.collection(col).where('bookingId','==',id).get()).docs)await d.ref.delete();
   for(const p of paths)await db.doc(p).delete();
   assert.equal((await db.collection('users').get()).size,0);
  }
 }
});
