'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDocs,collection,query,where,orderBy,Timestamp}=require('firebase/firestore');
if(process.env.GCLOUD_PROJECT!=='demo-aqar'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8186')throw Error('LOCAL_DEMO_ONLY');
let env;
after(async()=>{if(env)await env.cleanup();});
async function setup(body){if(env)await env.cleanup();env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{rules:"rules_version = '2'; service cloud.firestore {match /databases/{database}/documents {"+body+'}}'}});await env.clearFirestore();}
const item=extra=>({userId:'owner',title:'synthetic inbox item',message:'local only',createdAt:Timestamp.now(),...extra});
test('trust flag cannot transparently filter the legacy recipient-only inbox query',async()=>{
 await setup("match /notifications/{id} {allow read: if request.auth != null && resource.data.userId == request.auth.uid && resource.data.verified == true; allow write: if false;}");
 await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'notifications/trusted'),item({verified:true}));await setDoc(doc(c.firestore(),'notifications/unverified'),item({verified:false}));});
 const db=env.authenticatedContext('owner').firestore();
 // This is the legacy screen's actual query shape, including its ordering.
 await assertFails(getDocs(query(collection(db,'notifications'),where('userId','==','owner'),orderBy('createdAt','desc'))));
 const modern=await assertSucceeds(getDocs(query(collection(db,'notifications'),where('userId','==','owner'),where('verified','==',true),orderBy('createdAt','desc'))));
 assert.equal(modern.size,1);assert.equal(modern.docs[0].id,'trusted');
});
test('server-only existing inbox preserves legacy reads but cannot redirect old writes into an intake collection',async()=>{
 await setup("match /notifications/{id} {allow read: if request.auth != null && resource.data.userId == request.auth.uid; allow write: if false;} match /notification_requests/{id} {allow create: if request.auth != null; allow read, update, delete: if false;}");
 await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'notifications/history'),item({}));});
 const owner=env.authenticatedContext('owner').firestore(),sender=env.authenticatedContext('sender').firestore();
 const oldRead=await assertSucceeds(getDocs(query(collection(owner,'notifications'),where('userId','==','owner'),orderBy('createdAt','desc'))));assert.equal(oldRead.size,1);
 await assertFails(setDoc(doc(sender,'notifications/old-client-write'),item({type:'comment',propertyId:'p'})));
 await assertSucceeds(setDoc(doc(sender,'notification_requests/new-client-write'),item({type:'comment',propertyId:'p'})));
 assert.equal((await getDocs(query(collection(owner,'notifications'),where('userId','==','owner')))).size,1);
});
