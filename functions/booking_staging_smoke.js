const assert=require('node:assert/strict');
const project='aqar-bookings-test-20261009';
if(process.env.BOOKINGS_STAGING_PROJECT!==project || process.env.BOOKINGS_STAGING_CONFIRM!=='synthetic-test-data-only') throw Error('Explicit isolated staging project and synthetic-data confirmation required');
for(const key of ['BOOKINGS_STAGING_API_KEY','BOOKINGS_STAGING_CUSTOMER_EMAIL','BOOKINGS_STAGING_CUSTOMER_PASSWORD','BOOKINGS_STAGING_OWNER_EMAIL','BOOKINGS_STAGING_OWNER_PASSWORD','BOOKINGS_STAGING_VENUE_ID']) if(!process.env[key]) throw Error(`Missing ${key}`);
async function login(role){
 const response=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(process.env.BOOKINGS_STAGING_API_KEY)}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:process.env[`BOOKINGS_STAGING_${role}_EMAIL`],password:process.env[`BOOKINGS_STAGING_${role}_PASSWORD`],returnSecureToken:true})});
 const data=await response.json();if(!response.ok)throw Error('Staging test login failed');return data.idToken;
}
async function call(name,token,data){
 const response=await fetch(`https://us-central1-${project}.cloudfunctions.net/${name}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`},body:JSON.stringify({data})});
 const body=await response.json();if(!response.ok)throw Error(`${name}: ${body.error?.message || response.status}`);return body.result;
}
(async()=>{
 const customer=await login('CUSTOMER'),owner=await login('OWNER');
 const venueId=process.env.BOOKINGS_STAGING_VENUE_ID;
 // Fixed-price synthetic venue only; supply its published contract exactly.
 const contract=JSON.parse(process.env.BOOKINGS_STAGING_CONTRACT || '{}');
 assert.equal(contract.synthetic,true);
 const start=Date.now()+3*86400000,end=start+3600000;
 let booking;
 try {
   const free=await call('findAvailableBookingVenues',customer,{venueIds:[venueId],start,end});assert(free.venueIds.includes(venueId));
   booking=await call('requestBooking',customer,{venueId,requestId:`staging_${Date.now()}`,start,end,price:contract.price,deposit:contract.deposit,acceptedTerms:contract.terms,cancellationPolicy:contract.cancellationPolicy});
   await call('actOnBooking',owner,{bookingId:booking.id,action:'approve'});
   const occupied=await call('findAvailableBookingVenues',customer,{venueIds:[venueId],start,end});assert(!occupied.venueIds.includes(venueId));
   const ticket=await call('openBookingSupportTicket',customer,{bookingId:booking.id,requestId:`staging_${Date.now()}`,subject:'اختبار staging',message:'تذكرة اختبار اصطناعية، لا دفعات فعلية'});assert(ticket.id);
   console.log('PASS: cloud Auth, callable request, owner approval, availability exclusion and support. FCM/device delivery and media acceptance remain separate checks.');
 } finally {
   if(booking) await call('actOnBooking',customer,{bookingId:booking.id,action:'cancel',reason:'تنظيف اختبار staging الاصطناعي'});
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
