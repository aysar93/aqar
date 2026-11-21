'use strict';
require('./loopback-only.cjs');
if(process.argv[2]!=='--seed')throw Error('Explicit local --seed required');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const dep=require('node:module').createRequire(path.resolve(__dirname,'../../functions/package.json'));
Object.assign(process.env,{GCLOUD_PROJECT:'demo-aqar',FIRESTORE_EMULATOR_HOST:'127.0.0.1:8185',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:9099'});
const {initializeApp,deleteApp}=dep('firebase-admin/app'),{getAuth}=dep('firebase-admin/auth'),{getFirestore}=dep('firebase-admin/firestore');
(async()=>{
 const app=initializeApp({projectId:'demo-aqar'}),suffix=crypto.randomUUID().replaceAll('-','');
 try{
  const dir=path.join(__dirname,'.local'),file=path.join(dir,'native-defines.json');
  const old=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{};
  const email=old.BOOKINGS_LOCAL_EMAIL||'native-local-'+suffix+'@test.invalid',password=old.BOOKINGS_LOCAL_PASSWORD||crypto.randomBytes(20).toString('hex');
  const find=async(email,password)=>{try{return await getAuth().getUserByEmail(email);}catch(e){if(e.code!=='auth/user-not-found')throw e;return getAuth().createUser({email,password});}};
  const user=await find(email,password);
  const customerEmail=old.BOOKINGS_LOCAL_CUSTOMER_EMAIL||'native-customer-'+suffix+'@test.invalid';
  const customerPassword=old.BOOKINGS_LOCAL_CUSTOMER_PASSWORD||crypto.randomBytes(20).toString('hex');
  const customer=await find(customerEmail,customerPassword);
  const venue=old.BOOKINGS_LOCAL_VENUE||'native_'+suffix,db=getFirestore();
  await db.doc('users/'+user.uid).set({name:'local synthetic owner',phone:'07700000000',isBlocked:false});
  await db.doc('users/'+customer.uid).set({name:'local synthetic customer',phone:'07700000001',isBlocked:false});
  await db.doc('booking_venues/'+venue).set({ownerId:user.uid,name:'Local synthetic venue',category:'chalet',location:'local',active:true,mediaPaths:[],pricingMode:'fixed',price:100000,deposit:20000,terms:'local synthetic terms',cancellationPolicy:{freeCancellationHours:24,lateRefundPercent:50}});
  fs.mkdirSync(dir,{recursive:true});
  fs.writeFileSync(path.join(dir,'native-defines.json'),JSON.stringify({
   RUN_BOOKINGS_LOCAL_NATIVE:true,BOOKINGS_LOCAL_EMAIL:email,BOOKINGS_LOCAL_PASSWORD:password,BOOKINGS_LOCAL_VENUE:venue,
   BOOKING_CASE:'BINDING',BOOKINGS_LOCAL_OWNER_UID:user.uid,BOOKINGS_LOCAL_CUSTOMER_UID:customer.uid,
   BOOKINGS_LOCAL_CUSTOMER_EMAIL:customerEmail,BOOKINGS_LOCAL_CUSTOMER_PASSWORD:customerPassword,
   BOOKINGS_LOCAL_REQUEST_ID:old.BOOKINGS_LOCAL_REQUEST_ID||'native_'+suffix,
   BOOKINGS_LOCAL_START:Date.now()+48*3600000,
  }),{mode:0o600});
  console.log('Local demo fixture prepared; values omitted. File: tool/booking_network/.local/native-defines.json');
 }finally{await deleteApp(app);}
})().catch(()=>{console.error('LOCAL_FIXTURE_SEED_FAILED');process.exitCode=1;});
