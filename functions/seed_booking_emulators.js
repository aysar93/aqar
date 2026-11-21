// Explicitly refuse every remote or real-project environment.
if(process.env.GCLOUD_PROJECT!=='demo-aqar' || process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185' || process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099') throw Error('Local demo-aqar emulators required');
const {initializeApp}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getFirestore}=require('firebase-admin/firestore');
initializeApp({projectId:'demo-aqar'});
(async()=>{
  for(const role of ['customer','owner','admin','reviewer']) {
    try {await getAuth().createUser({uid:`test_${role}`,email:`${role}@test.invalid`,password:'AqarTest123!',displayName:`اختبار ${role}`});}
    catch(e) {if(e.code!=='auth/uid-already-exists' && e.code!=='auth/email-already-exists') throw e;}
    await getAuth().setCustomUserClaims(`test_${role}`,{canManagePaymentAccounts:role==='admin'});
    await getFirestore().doc(`users/test_${role}`).set({name:`اختبار ${role}`,phone:'07700000000',isBlocked:false,isAdmin:role==='admin',canReviewBookingPayments:role==='reviewer'});
  }
  await getFirestore().doc('payment_configuration/shared').set({revision:1,methods:{qicard:{enabled:true,number:'0000000000'},zaincash:{enabled:true,number:'07000000000'}}});
  await getFirestore().doc('payment_accounts/shared').set({revision:1,methods:{qicard:{enabled:true,number:'0000000000'},zaincash:{enabled:true,number:'07000000000'}}});
  await getFirestore().doc('settings/bookings').set({holdMinutes:120});
  for(const [id,category,name] of [['chalet','chalet','شاليه اختبار — ليس للإيجار'],['hall','hall','قاعة اختبار — ليست للإيجار'],['farm','farm','مزرعة اختبار — ليست للإيجار']]) {
    await getFirestore().doc(`booking_venues/test_${id}`).set({ownerId:'test_owner',ownerName:'اختبار المالك',name,category,location:'الأنبار — بيانات اصطناعية',capacity:8,bedrooms:2,complexName:'مجمع اختبار',unitName:id,amenities:['pool','parking'],active:true,latitude:33.35,longitude:43.3,pricingMode:'shifts',shifts:[{id:'morning',name:'صباحي',checkInMinute:480,checkOutMinute:960,price:100000},{id:'night',name:'مسائي',checkInMinute:1080,checkOutMinute:360,price:150000}],price:100000,deposit:20000,terms:'بيانات تجربة فقط. لا تحوّل أموالًا.',cancellationPolicy:{freeCancellationHours:24,lateRefundPercent:50}});
  }
  console.log('Seeded isolated customer/owner/admin/reviewer and 3 sample venues. No real payments.');
})().catch(e=>{console.error(e);process.exitCode=1;});
