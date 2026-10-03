const test = require('node:test');
const assert = require('node:assert/strict');
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185') throw new Error('Isolated emulator required');
const {initializeApp,deleteApp} = require('firebase-admin/app');
const {getFirestore,Timestamp} = require('firebase-admin/firestore');
const app = initializeApp({projectId:'demo-aqar'});
const db = getFirestore();
const {applyOfficeEvent,deltas,contribution,timestampFromIso} = require('./office_counters');
let serial=0;
const before=(data)=>({exists:!!data,data:()=>data});
const event=(old,next,revision=Timestamp.fromMillis(1900000000000))=>({id:`test-${serial++}`,time:revision.toDate().toISOString(), data:{before:before(old),after:{...before(next),updateTime:revision}}});
async function office(id='office') {
  const zero={propertiesCount:0,followersCount:0,reviewsCount:0,ratingSum:0};
  await db.doc(`offices/${id}`).set({...zero,rating:0,officeCounterTotals:zero,officeCounterVersion:1,officeCounterBaselineAt:Timestamp.fromMillis(1800000000000)});
  return db.doc(`offices/${id}`);
}
test('view, irrelevant profile edit and owner reply cause zero I/O',async()=>{
  for(const [kind,source,change] of [['properties',{officeId:'x',status:'approved'},{views:20}],['followers',{officeId:'x',isActive:true},{userName:'changed'}],['reviews',{officeId:'x',status:'published',rating:4},{ownerReply:'reply'}]]) {
    const result=await applyOfficeEvent(kind,event(source,{...source,...change}),{runTransaction:()=>{throw Error('unexpected I/O');}});
    assert.equal(result.outcome,'irrelevant');
  }
});
test('property create approve reject pending restore remove association delete',async()=>{
  const ref=await office(); const published={officeId:'office',status:'approved'}; const pending={...published,status:'pending'};
  await applyOfficeEvent('properties',event(null,pending)); assert.equal((await ref.get()).data().propertiesCount,0);
  await applyOfficeEvent('properties',event(pending,published)); assert.equal((await ref.get()).data().propertiesCount,1);
  await applyOfficeEvent('properties',event(published,{...published,status:'rejected'})); assert.equal((await ref.get()).data().propertiesCount,0);
  await applyOfficeEvent('properties',event(null,published)); await applyOfficeEvent('properties',event(published,{...published,officeId:''})); assert.equal((await ref.get()).data().propertiesCount,0);
  await applyOfficeEvent('properties',event(null,published)); await applyOfficeEvent('properties',event(published,null)); assert.equal((await ref.get()).data().propertiesCount,0);
});
test('transfer is atomic, duplicate concurrent delivery does not double count',async()=>{
  const a=await office('a'),b=await office('b'); const created=event(null,{officeId:'a',status:'approved'});
  await Promise.all([applyOfficeEvent('properties',created),applyOfficeEvent('properties',created)]);
  assert.equal((await a.get()).data().propertiesCount,1);
  const transfer=event({officeId:'a',status:'approved'},{officeId:'b',status:'approved'});
  await Promise.all([applyOfficeEvent('properties',transfer),applyOfficeEvent('properties',transfer)]);
  assert.equal((await a.get()).data().propertiesCount,0);assert.equal((await b.get()).data().propertiesCount,1);
});
test('followers support follow/unfollow/deletion, legacy default, out-of-order delivery',async()=>{
  const ref=await office(); const active={officeId:'office',isActive:true};
  const follow=event(null,active),unfollow=event(active,{...active,isActive:false});
  await applyOfficeEvent('followers',unfollow);await applyOfficeEvent('followers',follow);
  assert.equal((await ref.get()).data().followersCount,0);
  await applyOfficeEvent('followers',event(null,{officeId:'office'})); assert.equal((await ref.get()).data().followersCount,1);
  await applyOfficeEvent('followers',event({officeId:'office'},null));assert.equal((await ref.get()).data().followersCount,0);
});
test('ratings maintain sum and count incrementally, hide restore edit transfer',async()=>{
  const a=await office('r-a'),b=await office('r-b');const r={officeId:'r-a',rating:3};
  const e=event(null,r); await applyOfficeEvent('reviews',e);await applyOfficeEvent('reviews',e);
  await applyOfficeEvent('reviews',event(null,{...r,rating:5}));assert.equal((await a.get()).data().rating,4);
  await applyOfficeEvent('reviews',event(r,{...r,rating:1}));assert.equal((await a.get()).data().rating,3);
  await applyOfficeEvent('reviews',event({...r,rating:1},{...r,rating:1,status:'hidden'}));assert.equal((await a.get()).data().rating,5);
  await applyOfficeEvent('reviews',event({...r,rating:5},{officeId:'r-b',rating:5}));assert.equal((await a.get()).data().reviewsCount,0);assert.equal((await b.get()).data().rating,5);
});
test('backfill cutoff covers earlier events; nanosecond precision retained',async()=>{
  const ref=await office(); const cutoff=timestampFromIso('2026-10-03T12:05:10.123456789Z');
  await ref.update({officeCounterBaselineAt:cutoff,propertiesCount:3,officeCounterTotals:{propertiesCount:3,followersCount:0,reviewsCount:0,ratingSum:0}});
  assert.equal(cutoff.nanoseconds,123456789);
  const e=event(null,{officeId:'office',status:'approved'},cutoff);
  assert.equal((await applyOfficeEvent('properties',e)).outcome,'covered-or-deleted');
  assert.equal((await ref.get()).data().propertiesCount,3);
});
test('deleted office never recreated; inactive office maintenance stays accurate',async()=>{
  await db.doc('offices/absent').delete();await applyOfficeEvent('properties',event(null,{officeId:'absent',status:'approved'}));assert.equal((await db.doc('offices/absent').get()).exists,false);
  const ref=await office();await ref.update({status:'inactive',isBlocked:true});await applyOfficeEvent('properties',event(null,{officeId:'office',status:'approved'}));assert.equal((await ref.get()).data().propertiesCount,1);
});
test('legacy summary writes cannot corrupt canonical totals used by transition',async()=>{
  const ref=await office();await ref.update({followersCount:99});await applyOfficeEvent('followers',event(null,{officeId:'office',isActive:true}));assert.equal((await ref.get()).data().followersCount,1);
});
test('events delivered during backfill are represented exactly once after snapshot cutoff',async()=>{
  const ref=await office('backfill');const revision=Timestamp.fromMillis(1900000000000);const later=new Timestamp(revision.seconds+1,0);
  const included=event(null,{officeId:'backfill',isActive:true},revision),queued=event(null,{officeId:'backfill',isActive:true},later);
  await ref.update({officeCounterBaselineAt:revision,followersCount:1,officeCounterTotals:{propertiesCount:0,followersCount:1,reviewsCount:0,ratingSum:0}});
  await Promise.all([applyOfficeEvent('followers',included),applyOfficeEvent('followers',queued),applyOfficeEvent('followers',queued)]);
  assert.equal((await ref.get()).data().followersCount,2);
});
test('invalid association excluded and rating normalization matches client',()=>{
  assert.equal(contribution('followers',{officeId:'x/y',isActive:true}),null);assert.equal(contribution('reviews',{officeId:'x',rating:'9'}).rating,5);assert.equal(contribution('reviews',{officeId:'x',rating:null}).rating,1);assert.deepEqual(deltas('properties',{officeId:'x',status:'approved'},{officeId:'x',status:'approved',views:20}),[]);
});
test.after(()=>deleteApp(app));
