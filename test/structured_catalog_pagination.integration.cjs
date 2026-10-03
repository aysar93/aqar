const {test,after}=require('node:test'),assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185'||process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('DEMO_EMULATOR_ONLY');
const admin=require('../functions/node_modules/firebase-admin');
// Isolated demo namespace: same collection/query shapes, no production access or cross-suite fixtures.
const app=admin.initializeApp({projectId:'demo-aqar-pagination'},'pagination-matrix');const db=app.firestore();
const fixture=Array.from({length:130},(_,i)=>({id:'matrix-'+String(i).padStart(3,'0'),data:{status:i>=125?'pending':'approved',officeId:i<65?'matrix-office-a':'matrix-office-b',propertyType:i<65?'بيت':'أرض',adType:i<65?'للبيع':'للإيجار',isFeatured:i<110,createdAt:admin.firestore.Timestamp.fromMillis(Math.floor(i/3)*1000),price:Math.floor(i/3),views:Math.floor(i/3),title:i===60?'الرمادي الحوز':'عقار'}}));
const seed=(async()=>{const b=db.batch();for(const f of fixture)b.set(db.doc('properties/'+f.id),f.data);await b.commit();})();
const sorts=[['createdAt','desc'],['price','asc'],['price','desc'],['views','desc']];
for(let mask=0;mask<16;mask++)for(const [field,dir] of sorts)test(`matrix=${mask} ${field} ${dir}: >40 matches, three pages, ties, exact coverage`,async()=>{await seed;
let q=db.collection('properties').where('status','==','approved');const predicates=[['isFeatured',true],['adType','للبيع'],['propertyType','بيت'],['officeId','matrix-office-a']].filter((_,bit)=>mask&(1<<bit));for(const [f,v]of predicates)q=q.where(f,'==',v);q=q.orderBy(field,dir);
const expected=fixture.filter(x=>x.data.status==='approved'&&predicates.every(([f,v])=>x.data[f]===v)).sort((a,b)=>{const av=a.data[field],bv=b.data[field];const c=field==='createdAt'?av.toMillis()-bv.toMillis():av-bv;return (c||a.id.localeCompare(b.id))*(dir==='desc'?-1:1);}).map(x=>x.id);assert.ok(expected.length>40);
let cursor,ids=[];for(let page=0;page<8;page++){const snap=await (cursor?q.startAfter(cursor):q).limit(20).get();if(page<3)assert.equal(snap.size,20);ids.push(...snap.docs.map(d=>d.id));if(snap.size<20)break;cursor=snap.docs.at(-1);}
assert.deepEqual(ids,expected);assert.equal(new Set(ids).size,ids.length);
});
for(const [field,dir]of sorts)test(`rental/land/office-b combined ${field} ${dir}`,async()=>{await seed;const q=db.collection('properties').where('status','==','approved').where('adType','==','للإيجار').where('propertyType','==','أرض').where('officeId','==','matrix-office-b').where('isFeatured','==',true).orderBy(field,dir);let cursor,ids=[];for(let n=0;n<4;n++){const s=await(cursor?q.startAfter(cursor):q).limit(20).get();ids.push(...s.docs.map(d=>d.id));if(s.size<20)break;cursor=s.docs.at(-1);}assert.equal(ids.length,45);assert.equal(new Set(ids).size,45);});
after(async()=>{await seed;const b=db.batch();for(const f of fixture)b.delete(db.doc('properties/'+f.id));await b.commit();await app.delete();});
