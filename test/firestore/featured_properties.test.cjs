const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc, getDoc, writeBatch, runTransaction, Timestamp} = require('firebase/firestore');
let env;
const initial = {officeId:'office',ownerId:'owner',status:'active',canFeatureProperties:true,
  startDate:Timestamp.fromMillis(Date.now()-60000),endDate:Timestamp.fromMillis(Date.now()+3600000),
  featuredPropertiesUsed:0,maxFeaturedProperties:1};
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-aqar',firestore:{rules:readFileSync(require('node:path').resolve(__dirname,'../../firestore.rules'),'utf8')}});});
after(async()=>env.cleanup());
async function seed(subscription={},property={},office={}) {
  await env.withSecurityRulesDisabled(async c=>{
    const db=c.firestore();
    await Promise.all([
      setDoc(doc(db,'users/owner'),{isAdmin:false,isBlocked:false}),
      setDoc(doc(db,'users/other'),{isAdmin:false,isBlocked:false}),
      setDoc(doc(db,'users/admin'),{isAdmin:true,isBlocked:false}),
      setDoc(doc(db,'offices/office'),{ownerId:'owner',status:'active',...office}),
      setDoc(doc(db,'office_subscriptions/sub'),{...initial,...subscription}),
      ...['p','q'].map(id=>setDoc(doc(db,`properties/${id}`),{officeId:'office',userId:'owner',publisherUid:'owner',status:'approved',isFeatured:false,...property})),
    ]);
  });
}
beforeEach(async()=>{await env.clearFirestore();await seed();});
const dbFor=(uid='owner')=>env.authenticatedContext(uid).firestore();
function feature(db,id='p',used=1) {
  const b=writeBatch(db);
  b.update(doc(db,`properties/${id}`),{isFeatured:true,featuredSubscriptionId:'sub'});
  b.update(doc(db,'office_subscriptions/sub'),{featuredPropertiesUsed:used,lastFeaturedPropertyId:id});
  return b.commit();
}
test('active owner consumes one attempt atomically; cancellation never refunds',async()=>{
  const db=dbFor();await assertSucceeds(feature(db));
  await assertSucceeds(updateDoc(doc(db,'properties/p'),{isFeatured:false}));
  assert.equal((await getDoc(doc(db,'office_subscriptions/sub'))).data().featuredPropertiesUsed,1);
  await assertFails(feature(db,'p',2));
});
test('direct property changes, counter-only writes and forged association fail',async()=>{
  const db=dbFor();await assertFails(updateDoc(doc(db,'properties/p'),{isFeatured:true}));
  await assertFails(updateDoc(doc(db,'office_subscriptions/sub'),{featuredPropertiesUsed:1,lastFeaturedPropertyId:'p'}));
  const b=writeBatch(db);b.update(doc(db,'properties/p'),{isFeatured:true,featuredSubscriptionId:'sub'});
  b.update(doc(db,'office_subscriptions/sub'),{featuredPropertiesUsed:1,lastFeaturedPropertyId:'q'});
  await assertFails(b.commit());
});
test('two properties cannot consume only one attempt',async()=>{
  const db=dbFor(),b=writeBatch(db);
  for(const id of ['p','q'])b.update(doc(db,`properties/${id}`),{isFeatured:true,featuredSubscriptionId:'sub'});
  b.update(doc(db,'office_subscriptions/sub'),{featuredPropertiesUsed:1,lastFeaturedPropertyId:'p'});
  await assertFails(b.commit());
});
for(const [name,patch] of Object.entries({expired:{endDate:Timestamp.fromMillis(1)},future:{startDate:Timestamp.fromMillis(Date.now()+7200000)},pending:{status:'pending'},disabled:{canFeatureProperties:false},exhausted:{featuredPropertiesUsed:1},foreign:{officeId:'foreign'},foreignOwner:{ownerId:'other'}})){
  test(`rejects ${name} subscription`,async()=>{await seed(patch);await assertFails(feature(dbFor()));});
}
test('no subscription, foreign caller, blocked caller and unpublished property fail',async()=>{
  await assertFails(feature(dbFor('other')));
  await seed({}, {status:'pending'});await assertFails(feature(dbFor()));
  await seed();await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/owner'),{isBlocked:true}));
  await assertFails(feature(dbFor()));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/owner'),{isBlocked:false}));
  await env.withSecurityRulesDisabled(async c=>{const {deleteDoc}=require('firebase/firestore');await deleteDoc(doc(c.firestore(),'office_subscriptions/sub'));});
  await assertFails(feature(dbFor()));
});
test('repeated request cannot consume another attempt or refund quota',async()=>{
  const db=dbFor();await assertSucceeds(feature(db));await assertFails(feature(db,'p',2));
  await assertFails(updateDoc(doc(db,'office_subscriptions/sub'),{featuredPropertiesUsed:0}));
});
test('inactive office fails and existing featured property can be cancelled',async()=>{
  await seed({}, {}, {status:'inactive'});await assertFails(feature(dbFor()));
  await seed({}, {isFeatured:true});await assertSucceeds(updateDoc(doc(dbFor(),'properties/p'),{isFeatured:false}));
});
test('legacy missing usage starts at one and unlimited quota works',async()=>{
  await seed({maxFeaturedProperties:0});
  await env.withSecurityRulesDisabled(async c=>{const {deleteField}=require('firebase/firestore');await updateDoc(doc(c.firestore(),'office_subscriptions/sub'),{featuredPropertiesUsed:deleteField()});});
  const db=dbFor();await assertSucceeds(feature(db));await assertSucceeds(feature(db,'q',2));
});
test('create bypass denied; ordinary edits and admin feature remain allowed',async()=>{
  const db=dbFor();await assertFails(setDoc(doc(db,'properties/new'),{userId:'owner',publisherUid:'owner',status:'pending',isFeatured:true}));
  await assertSucceeds(updateDoc(doc(db,'properties/p'),{availabilityStatus:'sold',updatedAt:Timestamp.now()}));
  await assertSucceeds(updateDoc(doc(dbFor('admin'),'properties/p'),{isFeatured:true}));
});
test('concurrent transactions on last attempt allow exactly one property',async()=>{
  async function attempt(id){const db=dbFor();return runTransaction(db,async tx=>{
    const s=doc(db,'office_subscriptions/sub');const snap=await tx.get(s);
    const used=snap.data().featuredPropertiesUsed;if(used>=1)throw Error('quota exhausted');
    tx.update(doc(db,`properties/${id}`),{isFeatured:true,featuredSubscriptionId:'sub'});
    tx.update(s,{featuredPropertiesUsed:used+1,lastFeaturedPropertyId:id});
  });}
  const result=await Promise.allSettled([attempt('p'),attempt('q')]);
  assert.equal(result.filter(x=>x.status==='fulfilled').length,1);
  assert.equal((await getDoc(doc(dbFor(),'office_subscriptions/sub'))).data().featuredPropertiesUsed,1);
});
