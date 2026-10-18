'use strict';
const {test,before,after,beforeEach}=require('node:test'),assert=require('node:assert/strict'),fs=require('fs'),path=require('path');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc,Timestamp,arrayUnion}=require('firebase/firestore');
if(!['127.0.0.1:8185','localhost:8185','127.0.0.1:8186'].includes(process.env.FIRESTORE_EMULATOR_HOST)||process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('DEMO_EMULATOR_ONLY');
let env;
async function applyRules(rules){await env.cleanup();env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{rules}});}
const compat=fs.readFileSync(path.resolve('docs/fcm-ingress-remediation-2026-10-18/firestore.compat-update-only.rules'),'utf8'),strict=fs.readFileSync(path.resolve('docs/fcm-ingress-remediation-2026-10-18/firestore.strict-source-candidate.rules'),'utf8');
const db=uid=>env.authenticatedContext(uid).firestore();
const item=(extra={})=>({userId:'owner',type:'general',title:'saved title',message:'saved body',createdAt:Timestamp.now(),readBy:[],...extra});
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{rules:compat}});});
after(async()=>env.cleanup());
beforeEach(async()=>{
 await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{const d=c.firestore();for(const u of ['owner','sender','admin','other'])await setDoc(doc(d,'users/'+u),{isAdmin:u==='admin',isBlocked:false});
 await setDoc(doc(d,'settings/app_settings'),{adminUid:'admin'});await setDoc(doc(d,'notifications/saved'),item());
 await setDoc(doc(d,'notifications/chat_sender_admin'),item({userId:'admin',type:'chat_message',chatId:'sender',unreadCount:1}));
 await setDoc(doc(d,'properties/p'),{publisherUid:'owner'});await setDoc(doc(d,'properties/p/comments/c'),{userId:'sender'});
 });
});
test('compat: recipient read contracts remain available; payload and recipient are immutable',async()=>{
 const ref=doc(db('owner'),'notifications/saved');await assertSucceeds(getDoc(ref));await assertSucceeds(updateDoc(ref,{readBy:arrayUnion('owner'),isRead:true,unreadCount:0}));
 for(const change of [{userId:'other'},{message:'forged'},{type:'property',propertyId:'arbitrary'},{bridgeEventKey:'forged'},{readBy:['owner','other']},{unreadCount:50}])await assertFails(updateDoc(ref,change));
 await assertFails(getDoc(doc(db('other'),'notifications/saved')));
});
test('compat: old collapsed chat update stays inside sender-to-admin pair without source IDs',async()=>{
 const ref=doc(db('sender'),'notifications/chat_sender_admin');await assertSucceeds(updateDoc(ref,{title:'new chat',message:'old client',unreadCount:2,readBy:[],updatedAt:Timestamp.now()}));
 await assertFails(updateDoc(ref,{userId:'other'}));await assertFails(updateDoc(ref,{chatId:'other'}));
 await assertFails(updateDoc(doc(db('other'),'notifications/chat_sender_admin'),{message:'outsider',unreadCount:3}));
 let saved;await env.withSecurityRulesDisabled(async c=>{saved=await getDoc(doc(c.firestore(),'notifications/chat_sender_admin'));});assert.equal(saved.data().userId,'admin');
});
test('compat: malicious state types and forged read identities are rejected',async()=>{
 for(const change of [{readBy:'owner'},{isRead:'yes'},{updatedAt:'wrong'},{unreadCount:-1},{readBy:['other']}])await assertFails(updateDoc(doc(db('owner'),'notifications/saved'),change));
});
test('strict: verified source writes remain recipient-visible; fabricated and server-reserved fields are rejected',async()=>{
 await applyRules(strict);try{
 const payload=item({type:'comment',propertyId:'p',commentId:'c'});await assertSucceeds(setDoc(doc(db('sender'),'notifications/verified'),payload));
 await assertSucceeds(getDoc(doc(db('owner'),'notifications/verified')));await assertFails(getDoc(doc(db('other'),'notifications/verified')));
 await assertFails(setDoc(doc(db('other'),'notifications/forged'),payload));await assertFails(setDoc(doc(db('sender'),'notifications/redirect'),{...payload,userId:'other'}));
 await assertFails(setDoc(doc(db('sender'),'notifications/reserved'),{...payload,bridgeEventKey:'forged'}));
 await assertFails(setDoc(doc(db('sender'),'notifications/large'),{...payload,message:'x'.repeat(2001)}));
 await assertSucceeds(updateDoc(doc(db('owner'),'notifications/verified'),{isRead:true,readBy:['owner']}));
 }finally{await applyRules(compat);}
});
test('strict compatibility boundary: legacy comment without source ID is rejected, not silently treated as authorized',async()=>{
 const old=item({type:'comment',propertyId:'p'});
 await assertSucceeds(setDoc(doc(db('sender'),'notifications/legacy-under-compat'),old));
 await applyRules(strict);try{await assertFails(setDoc(doc(db('sender'),'notifications/legacy-under-strict'),old));}finally{await applyRules(compat);}
});
test('strict migration identity cannot be downgraded through a valid chat source update',async()=>{
 await env.withSecurityRulesDisabled(async c=>{for(const id of ['m1','m2'])await setDoc(doc(c.firestore(),'chats/sender/messages/'+id),{senderId:'sender'});});
 await applyRules(strict);try{
  const ref=doc(db('sender'),'notifications/strict-chat');
  await assertSucceeds(setDoc(ref,item({userId:'admin',type:'chat_message',chatId:'sender',messageId:'m1',unreadCount:1,pushTransport:'fcm_v1',createdBy:'sender'})));
  await assertFails(updateDoc(ref,{messageId:'m2',pushTransport:'legacy'}));
  await assertSucceeds(updateDoc(ref,{messageId:'m2'}));
 }finally{await applyRules(compat);}
});
