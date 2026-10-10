const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,collection,getDocs,query,where,orderBy}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{host:'127.0.0.1',port:8185,rules:readFileSync('firestore.rules','utf8')}});await env.withSecurityRulesDisabled(async c=>{for(const [id,data] of Object.entries({admin:{isAdmin:true,isBlocked:false},user:{isAdmin:false,isBlocked:false},blocked:{isAdmin:true,isBlocked:true}}))await setDoc(doc(c.firestore(),'users',id),data);});});
after(async()=>env.cleanup());
test('booking banner mutations are server-only even for administrators',async()=>{
 const banner={title:'Offer',subtitle:'Details',imageUrl:'https://image.test/bookingImage?mediaId=id',type:'farm',targetId:'farm',isActive:true,order:2,mediaId:'id'};
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'booking_banners/server'),banner));
 for(const uid of ['admin','user','blocked',null]) {
  const db=uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(db,'booking_banners/forged'),banner));
  await assertFails(updateDoc(doc(db,'booking_banners/server'),{imageUrl:'https://evil.test'}));
  await assertFails(deleteDoc(doc(db,'booking_banners/server')));
  await assertFails(setDoc(doc(db,'booking_media_reviews/forged'),{status:'approved'}));
  await assertFails(setDoc(doc(db,'booking_media_limits/forged'),{files:0}));
  await assertFails(setDoc(doc(db,'booking_legacy_media_deletions/forged'),{path:'reels/file.mp4'}));
 }
 const guest=env.unauthenticatedContext().firestore(),admin=env.authenticatedContext('admin').firestore();
 await assertSucceeds(getDoc(doc(guest,'booking_banners/server')));
 // Original home banner CRUD remains authorized and independent.
 await assertSucceeds(setDoc(doc(admin,'banners/server'),{...banner,title:'Home'}));
 await assertSucceeds(updateDoc(doc(admin,'banners/server'),{isActive:false}));
 await assertSucceeds(deleteDoc(doc(admin,'banners/server')));
});
test('blocked administrator cannot unblock self, grant roles, or mutate administrative collections',async()=>{
 const blocked=env.authenticatedContext('blocked').firestore();
 await assertFails(updateDoc(doc(blocked,'users/blocked'),{isBlocked:false}));
 await assertFails(updateDoc(doc(blocked,'users/user'),{isAdmin:true}));
 for(const path of ['settings/bookings','banners/escalation','booking_reports/escalation'])
   await assertFails(setDoc(doc(blocked,path),{isActive:true,status:'resolved'}));
 const admin=env.authenticatedContext('admin').firestore();
 await assertSucceeds(updateDoc(doc(admin,'users/blocked'),{isBlocked:false}));
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/blocked'),{isBlocked:true}));
});
