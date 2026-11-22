const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
if(process.env.GCLOUD_PROJECT!=='demo-aqar' || process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099' || process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185') throw Error('Isolated local emulators required');
const seed=spawnSync(process.execPath,['functions/seed_booking_emulators.js'],{stdio:'inherit',env:process.env});
if(seed.status!==0) process.exit(seed.status || 1);
async function login(role) {
  const response=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`${role}@test.invalid`,password:'AqarTest123!',returnSecureToken:true})});
  const data=await response.json();assert.equal(response.ok,true,JSON.stringify(data));return data.idToken;
}
async function call(name,token,data) {
  const response=await fetch(`http://127.0.0.1:5001/demo-aqar/us-central1/${name}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`},body:JSON.stringify({data})});
  const result=await response.json();assert.equal(response.ok,true,JSON.stringify(result));return result.result;
}
(async()=>{
  const customer=await login('customer'),owner=await login('owner');
  const date=new Date(Date.now()+86400000*3);date.setUTCHours(5,0,0,0);
  const data={venueId:'test_chalet',requestId:`smoke_${Date.now()}`,start:date.getTime(),end:date.getTime()+8*3600000,shiftId:'morning',price:100000,deposit:20000,acceptedTerms:'بيانات تجربة فقط. لا تحوّل أموالًا.',cancellationPolicy:{freeCancellationHours:24,lateRefundPercent:50}};
  const booking=await call('requestBooking',customer,data);
  await call('actOnBooking',owner,{bookingId:booking.id,action:'approve'});
  const availability=await call('getBookingAvailability',customer,{venueId:'test_chalet',start:data.start-1,end:data.end+1});
  assert.equal(availability.slots[0].state,'pending');
  await call('actOnBooking',customer,{bookingId:booking.id,action:'cancel',reason:'local smoke test'});
  console.log('HTTP callable smoke passed: emulator Auth login -> request -> owner approval -> private availability -> cancellation.');
})().catch(e=>{console.error(e);process.exitCode=1;});
