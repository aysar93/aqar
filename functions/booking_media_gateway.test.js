const test=require('node:test'), assert=require('node:assert/strict');
const {canRead,canUpload}=require('./booking_media_gateway')._policy;
const c=()=>({m:{kind:'venue',type:'video/mp4',status:'approved',ownerUid:'owner',path:'booking_media_v3/v/owner/id.mp4',expiresAt:Date.now()+60000},owner:{isBlocked:false},venue:{ownerId:'owner',active:true,mediaPaths:['booking_media_v3/v/owner/id.mp4']}});
test('approved published media permits public and owner access',()=>{assert(canRead(c(),null));assert(canRead(c(),{uid:'owner'}));});
test('pending and uploading media never permit public access',()=>{for(const status of ['pending','uploading','delete_pending','deleted']) {const x=c();x.m.status=status;assert(!canRead(x,null));} const x=c();x.m.status='pending';assert(canRead(x,{uid:'owner'}));assert(canRead(x,{uid:'admin',isAdmin:true}));});
test('blocking, inactive or unverified venue, removed reference and ownership change revoke public access',()=>{for(const mutate of [x=>x.owner.isBlocked=true,x=>x.owner=null,x=>x.venue.active=false,x=>x.venue.verificationStatus='pending',x=>x.venue.verificationStatus='rejected',x=>x.venue.mediaPaths=[],x=>x.venue.ownerId='other',x=>x.venue=null]){const x=c();mutate(x);assert(!canRead(x,null));}});
test('old owner and unrelated user cannot preview after transfer',()=>{const x=c();x.m.status='pending';x.venue.ownerId='new';assert(!canRead(x,{uid:'owner'}));assert(!canRead(x,{uid:'new'}));assert(!canRead(x,{uid:'customer'}));});
test('video upload requires live ownership, reservation and expiry',()=>{const x=c();x.m.status='uploading';assert(canUpload(x,{uid:'owner'}));assert(!canUpload(x,{uid:'other'}));for(const mutate of [x=>x.m.expiresAt=0,x=>x.venue.ownerId='other',x=>x.m.status='approved',x=>x.m.type='image/jpeg',x=>x.m.kind='banner']){const y=c();y.m.status='uploading';mutate(y);assert(!canUpload(y,{uid:'owner'}));}});
test('share page gatewayImageUrl converts only canonical venue image mediaPaths and rejects external https, proofs, receipts and videos',()=>{
  const V3_IMAGE_PATH=/^booking_media_v3\/([A-Za-z0-9_-]{1,128})\/([A-Za-z0-9_-]{1,128})\/([A-Za-z0-9_-]{1,128})\.(jpg|png)$/;
  const gatewayImageUrl=(rawPath,venueId,ownerId,projectId)=>{
    if(typeof rawPath!=='string') return null;
    const m=V3_IMAGE_PATH.exec(rawPath.trim());
    if(!m) return null;
    const [,pathVenueId,pathOwnerId,mediaId]=m;
    if(pathVenueId!==venueId || pathOwnerId!==ownerId) return null;
    return `https://us-central1-${encodeURIComponent(projectId)}.cloudfunctions.net/bookingMediaContent?mediaId=${encodeURIComponent(mediaId)}`;
  };
  assert.equal(gatewayImageUrl('booking_media_v3/v1/u1/m123.jpg','v1','u1','aqar-bookings-test-20261009'),'https://us-central1-aqar-bookings-test-20261009.cloudfunctions.net/bookingMediaContent?mediaId=m123');
  assert.equal(gatewayImageUrl('https://images.unsplash.com/photo-123.jpg','v1','u1','aqar-bookings-test-20261009'),null);
  assert.equal(gatewayImageUrl('https://evil.example/steal.jpg','v1','u1','aqar-bookings-test-20261009'),null);
  assert.equal(gatewayImageUrl('booking_ownership_documents/v1/u1/doc.jpg','v1','u1','aqar-bookings-test-20261009'),null);
  assert.equal(gatewayImageUrl('booking_receipts/b1/u1/123.jpg','v1','u1','aqar-bookings-test-20261009'),null);
  assert.equal(gatewayImageUrl('booking_media_v3/v1/u1/vid1.mp4','v1','u1','aqar-bookings-test-20261009'),null);
  assert.equal(gatewayImageUrl('booking_media_v3/other_venue/u1/m123.jpg','v1','u1','aqar-bookings-test-20261009'),null);
  assert.equal(gatewayImageUrl('booking_media_v3/v1/other_owner/m123.jpg','v1','u1','aqar-bookings-test-20261009'),null);
});
