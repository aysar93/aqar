// Local only: exercises real Firestore cursor/aggregation protocol. Never runs against production.
const {test,after}=require('node:test'),assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185'||process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('DEMO_EMULATOR_ONLY');
const sdkRequire=require('node:module').createRequire(require.resolve('../functions/node_modules/firebase-admin'));
const {initializeApp,deleteApp}=sdkRequire('firebase-admin/app');
const {getFirestore,Timestamp,FieldPath}=sdkRequire('firebase-admin/firestore');
const app=initializeApp({projectId:'demo-aqar'},'closure-queries');const db=getFirestore(app);
const ids=[];
const seed=(async()=>{const batch=db.batch();
 for(let i=0;i<65;i++){
  const ref=db.doc(`properties/closure-${String(i).padStart(3,'0')}`);ids.push(ref);
  batch.set(ref,{officeId:i<60?'closure-office-a':'closure-office-b',status:i===59?'pending':i===58?'active':'approved',isFeatured:i%2===0,createdAt:Timestamp.fromMillis(Math.floor(i/2)*1000),price:Math.floor(i/2)});
 }
 for(let i=0;i<45;i++){const ref=db.doc(`office_reviews/closure-${String(i).padStart(3,'0')}`);ids.push(ref);
  batch.set(ref,{officeId:'closure-office-a',createdAt:Timestamp.fromMillis(Math.floor(i/2)*1000),...(i===0?{}:{status:i>24?'hidden':'published'})});
 }
 for(let i=0;i<45;i++){const ref=db.doc(`office_followers/closure-${String(i).padStart(3,'0')}`);ids.push(ref);
  batch.set(ref,{officeId:'closure-office-a',userId:`closure-follower-${i}`,createdAt:Timestamp.fromMillis(Math.floor(i/2)*1000),...(i===0?{}:{isActive:i<25})});}
 for(const [path,data] of [['offices/closure-office-a',{ownerId:'closure-owner',status:'active'}],['users/closure-owner',{isAdmin:false,isBlocked:false}]]){const ref=db.doc(path);ids.push(ref);batch.set(ref,data);}
 await batch.commit();})();
async function walk(q){let cursor;const pages=[];for(let i=0;i<5;i++){
 const snap=await (cursor?q.startAfter(cursor):q).limit(20).get();pages.push(snap.docs);if(snap.size<20)break;cursor=snap.docs.at(-1);
 }return pages;}
async function verify(q,expected){const pages=await walk(q),all=await q.get();
 assert.equal(pages[0].length,20);assert.equal(pages[1].length,20);
 const names=pages.flat().map(d=>d.id);assert.deepEqual(names,all.docs.map(d=>d.id));assert.equal(new Set(names).size,expected);return pages;}
test('real office approved cursor, correct order, no duplicates or missing',async()=>{await seed;await verify(db.collection('properties').where('officeId','==','closure-office-a').where('status','==','approved').orderBy('createdAt','desc'),58);});
test('owner all/status cursor and scalar counts match whole-office truth',async()=>{await seed;const base=db.collection('properties').where('officeId','==','closure-office-a');
 await verify(base.orderBy('createdAt','desc'),60);
 const published=base.where('status','in',['approved','active']);await verify(published.orderBy('createdAt','desc'),59);
 const counts=await Promise.all([base.count().get(),published.count().get(),base.where('status','==','pending').count().get(),base.where('isFeatured','==',true).count().get()]);
 assert.deepEqual(counts.map(s=>s.data().count),[60,59,1,30]);});
test('real review cursor includes legacy missing status and pages past hidden reviews',async()=>{await seed;const pages=await verify(db.collection('office_reviews').where('officeId','==','closure-office-a').orderBy('createdAt','desc'),45);
 assert.ok(pages.flat().some(d=>d.data().status===undefined));assert.ok(pages[1].some(d=>d.data().status==='published'));});
test('real price cursor ascending/descending including ties',async()=>{await seed;for(const dir of ['asc','desc'])await verify(db.collection('properties').where('officeId','==','closure-office-a').where('status','==','approved').orderBy('price',dir),58);});
test('real follower cursor retains missing isActive and traverses inactive first page',async()=>{await seed;const pages=await verify(db.collection('office_followers').where('officeId','==','closure-office-a').orderBy('createdAt','desc'),45);
 assert.ok(pages[0].every(d=>d.data().isActive===false));assert.ok(pages[1].some(d=>d.data().isActive===true));assert.ok(pages.flat().some(d=>d.data().isActive===undefined));});
test('owner follower query works; unrelated users cannot enumerate followers',async()=>{await seed;
 const token=uid=>[Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({sub:uid,user_id:uid,aud:'demo-aqar',iss:'https://securetoken.google.com/demo-aqar',iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'password'}})).toString('base64url'),''].join('.');
 const request=uid=>fetch('http://127.0.0.1:8185/v1/projects/demo-aqar/databases/(default)/documents:runQuery',{method:'POST',headers:{authorization:`Bearer ${token(uid)}`,'content-type':'application/json'},body:JSON.stringify({structuredQuery:{from:[{collectionId:'office_followers'}],where:{fieldFilter:{field:{fieldPath:'officeId'},op:'EQUAL',value:{stringValue:'closure-office-a'}}},orderBy:[{field:{fieldPath:'createdAt'},direction:'DESCENDING'}],limit:20}})});
 assert.equal((await request('closure-owner')).status,200);// Public follower enumeration is deliberately denied.
 assert.equal((await request('closure-outsider')).status,403);
});
after(async()=>{await seed;const batch=db.batch();for(const ref of ids)batch.delete(ref);await batch.commit();await deleteApp(app);});
