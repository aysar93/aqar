const {test}=require('node:test');
const assert=require('node:assert/strict');
const {cleanupUnreferencedMedia:cleanup}=require('./media_cleanup_policy');
function fixture(){
 let calls=0,revision=1,refs=[],pending=0,deleted=[];
 const d={allReferenceWritersCovered:true,withExclusiveBarrier:async(p,f)=>f({held:true,references:async()=>({complete:true,references:refs,pendingUploads:pending,revision})}),metadata:async()=>({generation:'7',sha256:'hash'}),backupAndVerify:async()=>({encrypted:true,verified:true,sha256:'hash',id:'encrypted-recovery'}),deleteGeneration:async(...v)=>deleted.push(v)};
 return {d,c:{path:'uploads/public/property/owner/operation.jpg',generation:'7'},deleted,setRefs:v=>refs=v,setPending:v=>pending=v,bump:()=>revision++};
}
test('unknown legacy writers retain bytes without IO',async()=>{const x=fixture();x.d.allReferenceWritersCovered=false;assert.equal((await cleanup(x.c,x.d)).reason,'writer_coverage_unproven');assert.equal(x.deleted.length,0)});
test('shared references and in-flight upload prohibit deletion',async()=>{for(const pending of [false,true]){const x=fixture();pending?x.setPending(1):x.setRefs(['other-document']);assert.equal((await cleanup(x.c,x.d)).deleted,false);assert.equal(x.deleted.length,0)}});
test('reference edit during encrypted backup blocks cleanup',async()=>{const x=fixture();const original=x.d.backupAndVerify;x.d.backupAndVerify=async()=>{x.bump();return original()};assert.equal((await cleanup(x.c,x.d)).reason,'reference_race');assert.equal(x.deleted.length,0)});
test('generation replacement and unverified recovery fail closed',async()=>{const x=fixture();x.c.generation='6';assert.equal((await cleanup(x.c,x.d)).reason,'generation_changed');x.c.generation='7';x.d.backupAndVerify=async()=>({encrypted:false,verified:true,sha256:'hash'});assert.equal((await cleanup(x.c,x.d)).reason,'recovery_not_verified');assert.equal(x.deleted.length,0)});
test('migrated originals are never cleanup candidates',async()=>{const x=fixture();x.c.path='staging/private/cloudinary-hwxcrlcj/image/original.jpg';assert.equal((await cleanup(x.c,x.d)).deleted,false);assert.equal(x.deleted.length,0)});
test('fully frozen unreferenced synthetic fixture uses exact generation',async()=>{const x=fixture();assert.equal((await cleanup(x.c,x.d)).deleted,true);assert.deepEqual(x.deleted,[[x.c.path,'7']])});
