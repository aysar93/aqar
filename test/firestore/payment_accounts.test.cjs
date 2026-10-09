const {test,before,after}=require('node:test');
const {readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,getDocs,collection}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{host:'127.0.0.1',port:8185,rules:readFileSync('firestore.rules','utf8')}});});
after(async()=>env.cleanup());
test('payment settings privacy and server-only mutations; snapshots remain immutable',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  for(const [path,data] of Object.entries({'users/admin':{isAdmin:true,isBlocked:false},'users/user':{isAdmin:false,isBlocked:false},'users/blocked':{isAdmin:true,isBlocked:true},'payment_accounts/shared':{methods:{}},'payment_account_audit/a':{actorUid:'admin'},'subscription_payments/p':{ownerUid:'user',status:'pending',paymentAccountSnapshot:{number:'7066135323'}}})) await setDoc(doc(c.firestore(),path),data);
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
 await assertSucceeds(updateDoc(doc(admin,'subscription_payments/p'),{status:'approved'}));
 await assertSucceeds(getDoc(doc(user,'subscription_payments/p')));
});
