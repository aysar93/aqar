const {test}=require('node:test');
const assert=require('node:assert/strict');
const {LIMITS,validId,imageBytes,canRead,canDeleteKey}=require('./booking_media_policy');
test('identifiers, image signatures and actual bytes are bounded',()=>{
  for(const value of ['../reels','x/y','',null,'a'.repeat(129)]) assert.throws(()=>validId(value));
  assert.equal(validId('venue-123'),'venue-123');
  for(const value of ['',Buffer.from('not an image').toString('base64'),'data:image/jpeg;base64,/9j/']) assert.throws(()=>imageBytes(value));
  assert.equal(imageBytes(Buffer.from([255,216,255,0]).toString('base64')).type,'image/jpeg');
  assert.throws(()=>imageBytes(Buffer.alloc(LIMITS.image+1).toString('base64')));
});
test('pending, inactive, blocked, transferred and removed media are gated',()=>{
  const m={kind:'venue',status:'pending',ownerUid:'owner'},v={active:true,ownerId:'owner'};
  assert.equal(canRead(m,v,null,null),false);
  assert.equal(canRead(m,v,{},'owner'),true);
  assert.equal(canRead(m,v,{isBlocked:true,isAdmin:true},'admin'),false);
  m.status='approved'; assert.equal(canRead(m,v,null,null),true);
  assert.equal(canRead(m,{...v,active:false},null,null),false);
  assert.equal(canRead(m,{...v,ownerId:'new'},null,null),false);
  m.status='delete_pending'; assert.equal(canRead(m,v,{isAdmin:true},'admin'),false);
});
test('R2 deletion is restricted to canonical booking key and terminal state',()=>{
  const m={provider:'r2',venueId:'v',ownerUid:'u',key:'bookings/venues/v/u/id.mp4',status:'delete_pending'};
  assert.equal(canDeleteKey(m,'id'),true);
  for(const key of ['reels/original/id.mp4','bookings/venues/v/other/id.mp4','bookings/venues/v/u/else.mp4']) assert.equal(canDeleteKey({...m,key},'id'),false);
  assert.equal(canDeleteKey({...m,status:'approved'},'id'),false);
});
