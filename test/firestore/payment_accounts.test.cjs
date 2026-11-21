const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,getDocs,collection,serverTimestamp,deleteDoc}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{host:'127.0.0.1',port:8185,rules:readFileSync('firestore.rules','utf8')}});});
after(async()=>env.cleanup());
test('payment settings privacy and server-only mutations; snapshots remain immutable',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  for(const [path,data] of Object.entries({'users/admin':{isAdmin:true,isBlocked:false},'users/user':{isAdmin:false,isBlocked:false},'users/blocked':{isAdmin:true,isBlocked:true},'offices/o':{ownerId:'user'},'payment_accounts/shared':{methods:{}},'payment_account_audit/a':{actorUid:'admin'},'subscription_payments/p':{officeId:'o',ownerUid:'user',status:'pending',paymentAccountSnapshot:{number:'7066135323'}}})) await setDoc(doc(c.firestore(),path),data);
 });
 const user=env.authenticatedContext('user').firestore(),admin=env.authenticatedContext('admin',{canManagePaymentAccounts:true}).firestore(),anon=env.unauthenticatedContext().firestore(),blocked=env.authenticatedContext('blocked',{canManagePaymentAccounts:true}).firestore();
 await assertSucceeds(getDoc(doc(user,'payment_accounts/shared')));
 for(const db of [user,admin,anon,blocked]) {
  await assertFails(setDoc(doc(db,'payment_configuration/shared'),{methods:{}}));
  await assertFails(setDoc(doc(db,'payment_accounts/shared'),{methods:{}}));
  await assertFails(setDoc(doc(db,'payment_account_audit/a'),{actorUid:'fake'}));
  await assertFails(setDoc(doc(db,'subscription_payments/new'),{ownerUid:'user',officeId:'o',subscriptionId:'s'}));
 }
 await assertFails(getDoc(doc(anon,'payment_accounts/shared')));
 await assertFails(getDoc(doc(blocked,'payment_accounts/shared')));
 await assertFails(getDocs(collection(user,'payment_accounts')));
 await assertFails(getDoc(doc(user,'payment_configuration/shared')));
 await assertFails(getDoc(doc(admin,'payment_configuration/shared')));
 await assertFails(getDoc(doc(user,'payment_account_audit/a')));
 await assertSucceeds(getDoc(doc(admin,'payment_account_audit/a')));
 await assertFails(updateDoc(doc(user,'users/user'),{canManagePaymentAccounts:true}));
 await assertFails(updateDoc(doc(admin,'subscription_payments/p'),{paymentAccountSnapshot:{number:'1111111111'}}));
 await assertFails(updateDoc(doc(admin,'subscription_payments/p'),{status:'approved'}));
 await assertFails(updateDoc(doc(blocked,'subscription_payments/p'),{status:'approved',approvedBy:'blocked',approvedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(doc(admin,'subscription_payments/p'),{status:'approved',approvedBy:'admin',approvedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(admin,'subscription_payments/p'),{status:'rejected',approvedBy:'admin',updatedAt:serverTimestamp()}));
 await assertFails(deleteDoc(doc(admin,'subscription_payments/p')));
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'office_subscriptions/contract'),{ownerId:'user',status:'active'}));
 await assertFails(deleteDoc(doc(admin,'office_subscriptions/contract')));
 await assertSucceeds(getDoc(doc(user,'subscription_payments/p')));
});

test('legacy payment without account snapshot can still be reviewed; booking notifications and audits cannot be forged',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  for(const [path,data] of Object.entries({'subscription_payments/old':{ownerUid:'user',officeId:'o',status:'pending',paymentAccount:'historical'},'notifications/booking_old':{type:'booking',userId:'user',bookingId:'old',readBy:[]},'booking_action_audit/a':{actorUid:'admin'},'booking_finance_audit/a':{actorUid:'admin'},'users/ownerAdmin':{isAdmin:true,isBlocked:false},'subscription_payments/self':{ownerUid:'ownerAdmin',officeId:'o',status:'pending'}})) await setDoc(doc(c.firestore(),path),data);
 });
 const user=env.authenticatedContext('user').firestore(),admin=env.authenticatedContext('admin').firestore(),self=env.authenticatedContext('ownerAdmin').firestore();
 await assertSucceeds(updateDoc(doc(admin,'subscription_payments/old'),{status:'rejected',approvedBy:'admin',updatedAt:serverTimestamp()}));
 assert.equal((await getDoc(doc(user,'subscription_payments/old'))).data().paymentAccount,'historical');
 await assertFails(updateDoc(doc(self,'subscription_payments/self'),{status:'approved',approvedBy:'ownerAdmin',approvedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertFails(setDoc(doc(user,'notifications/fake'),{type:'booking',userId:'admin',bookingId:'old'}));
 await assertFails(setDoc(doc(user,'notifications/booking_fake'),{type:'other',userId:'admin'}));
 await assertSucceeds(setDoc(doc(user,'notifications/ordinary'),{type:'other',userId:'user'}));
 await assertFails(updateDoc(doc(user,'notifications/ordinary'),{type:'booking',bookingId:'old'}));
 await assertFails(updateDoc(doc(user,'notifications/booking_old'),{type:'other',bookingId:'fake'}));
 await assertSucceeds(updateDoc(doc(user,'notifications/booking_old'),{readBy:['user']}));
 for(const name of ['booking_action_audit','booking_finance_audit']) {
  await assertSucceeds(getDoc(doc(admin,`${name}/a`)));
  await assertFails(getDoc(doc(user,`${name}/a`)));
  await assertFails(setDoc(doc(admin,`${name}/a`),{actorUid:'fake'}));
 }
});
