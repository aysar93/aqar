const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,collection,getDocs,query,where,orderBy}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{host:'127.0.0.1',port:8185,rules:readFileSync('firestore.rules','utf8')}});await env.withSecurityRulesDisabled(async c=>{for(const [id,data] of Object.entries({admin:{isAdmin:true,isBlocked:false},user:{isAdmin:false,isBlocked:false},blocked:{isAdmin:true,isBlocked:true}}))await setDoc(doc(c.firestore(),'users',id),data);});});
after(async()=>env.cleanup());
test('booking banner CRUD, ordering, activation and links stay independent of home banners',async()=>{
 const admin=env.authenticatedContext('admin').firestore(),user=env.authenticatedContext('user').firestore(),guest=env.unauthenticatedContext().firestore(),blocked=env.authenticatedContext('blocked').firestore();
 const banner={title:'Offer',subtitle:'Details',imageUrl:'https://example.com/banner.jpg',type:'external',targetId:'https://example.com/booking',isActive:true,order:2};
 await assertSucceeds(setDoc(doc(admin,'banners/same'),{...banner,title:'Home'}));
 await assertSucceeds(setDoc(doc(admin,'booking_banners/same'),banner));
 await assertSucceeds(setDoc(doc(admin,'booking_banners/first'),{...banner,order:1}));
 for(const db of [user,guest,blocked]) {await assertFails(setDoc(doc(db,'booking_banners/forged'),banner));await assertFails(updateDoc(doc(db,'booking_banners/same'),{isActive:false}));await assertFails(deleteDoc(doc(db,'booking_banners/same')));}
 await assertSucceeds(getDoc(doc(guest,'booking_banners/same')));
 const active=()=>getDocs(query(collection(guest,'booking_banners'),where('isActive','==',true),orderBy('order')));
 assert.deepEqual((await active()).docs.map(d=>d.id),['first','same']);
 await assertSucceeds(updateDoc(doc(admin,'booking_banners/same'),{targetId:'https://wa.me/9647000000000',order:0,isActive:false}));
 assert.deepEqual((await active()).docs.map(d=>d.id),['first']);
 await assertSucceeds(updateDoc(doc(admin,'booking_banners/same'),{isActive:true}));
 assert.deepEqual((await active()).docs.map(d=>d.id),['same','first']);
 assert.equal((await getDoc(doc(guest,'booking_banners/same'))).data().targetId,'https://wa.me/9647000000000');
 await assertSucceeds(deleteDoc(doc(admin,'booking_banners/same')));
 assert.equal((await getDoc(doc(guest,'banners/same'))).data().title,'Home');
});
