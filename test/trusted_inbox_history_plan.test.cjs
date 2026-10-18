const {test}=require('node:test'),assert=require('node:assert/strict');
const {planHistory,checksum}=require('../tools/trusted_inbox_history_plan.cjs');
const row=(id='old')=>({name:'projects/demo-aqar/databases/(default)/documents/notifications/'+id,updateTime:'2026-10-01T00:00:00Z',fields:{userId:{stringValue:'owner'},title:{stringValue:'old title'},message:{stringValue:'old message'},createdAt:{timestampValue:'2026-09-01T00:00:00Z'},isRead:{booleanValue:true},readBy:{arrayValue:{values:[]}},customLegacy:{mapValue:{fields:{kept:{bytesValue:'AA=='}}}}}});
test('history plan preserves every original field, ID and read meaning without deleting or trusting a client verified flag',()=>{
 const d=row(),other=row('unknown');other.fields.verified={booleanValue:true};const saved=JSON.stringify([d,other]);
 const result=planHistory([d,other],[{id:'old',uid:'owner',checksum:checksum(d),updateTime:d.updateTime,sourceVerified:true,auditReference:'independent-server-audit'}]);
 assert.equal(result.archive.length,2);assert.deepEqual(result.archive[0].document,d);assert.equal(JSON.stringify([d,other]),saved);assert.equal(result.history.length,1);assert.deepEqual(result.history[0].fields.readBy.arrayValue.values,[{stringValue:'owner'}]);assert.equal(result.review[0].id,'unknown');assert.deepEqual(result.deleteOperations,[]);
});
test('history plan refuses wrong ownership, stale evidence and non-unique exports',()=>{
 const d=row();for(const change of [{uid:'other'},{checksum:'stale'},{updateTime:'stale'}]){const p={id:'old',uid:'owner',checksum:checksum(d),updateTime:d.updateTime,sourceVerified:true,auditReference:'audit',...change};assert.equal(planHistory([d],[p]).history.length,0);}
 assert.throws(()=>planHistory([d,d]),/NON_UNIQUE/);
});
test('large shared read state stays lossless in archive and remains writable in owner projection; duplicate proofs fail closed',()=>{
 const d=row();d.fields.isRead.booleanValue=false;d.fields.readBy.arrayValue.values=Array.from({length:150},(_,i)=>({stringValue:'other-'+i})).concat([{stringValue:'owner'}]);
 const p={id:'old',uid:'owner',checksum:checksum(d),updateTime:d.updateTime,sourceVerified:true,auditReference:'audit'};
 const result=planHistory([d],[p]);assert.equal(result.archive[0].document.fields.readBy.arrayValue.values.length,151);assert.deepEqual(result.history[0].fields.readBy.arrayValue.values,[{stringValue:'owner'}]);assert.equal(result.history[0].fields.isRead.booleanValue,true);assert.throws(()=>planHistory([d],[p,p]),/NON_UNIQUE_PROOF/);
});
