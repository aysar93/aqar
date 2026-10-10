import {test} from 'node:test';
import assert from 'node:assert/strict';
import {bookingRoute} from '../src/bookings.js';
const mp4=new Uint8Array([0,0,0,12,102,116,121,112,105,115,111,109]);
test('private playback denies pending guests and serves approved ranged bytes',async()=>{
  let status='pending',active=true;
  const fields={provider:{stringValue:'r2'},status:{stringValue:status},venueId:{stringValue:'v'},ownerUid:{stringValue:'u'},key:{stringValue:'bookings/venues/v/u/media-id.mp4'}};
  const helpers={googleAccessToken:async()=>'',firestoreGet:async path=>({fields:path.startsWith('booking_media_reviews')?{...fields,status:{stringValue:status}}:{active:{booleanValue:active},ownerId:{stringValue:'u'}}})};
  const env={BOOKINGS_BUCKET:{get:async()=>({size:12,httpEtag:'etag',body:mp4,range:{offset:0,length:12}})}};
  const req=new Request('https://worker.test/bookings/media/media-id.mp4',{headers:{range:'bytes=0-11'}});
  await assert.rejects(bookingRoute(req,env,{},helpers),/media_unavailable/);
  status='approved'; const response=await bookingRoute(req,env,{},helpers);
  assert.equal(response.status,206); assert.equal(response.headers.get('content-range'),'bytes 0-11/12');
  active=false; await assert.rejects(bookingRoute(req,env,{},helpers),/media_unavailable/);
});

 test('retired booking writes return 410 without affecting reels health', async () => {
  const {default:worker}=await import('../src/index.js');
  for(const path of ['upload','delete']) {
    const response=await worker.fetch(new Request(`https://worker.test/bookings/${path}`,{method:'POST'}),{});
    assert.equal(response.status,410);
  }
  const health=await worker.fetch(new Request('https://worker.test/health'),{});
  assert.equal(health.status,200);
});

test('bookingRoute itself cannot upload or delete even with former secrets',async t=>{
  t.mock.method(globalThis,'fetch',async()=>assert.fail('external bridge retired'));
  const env={BOOKINGS_BUCKET:{put:()=>assert.fail('put'),delete:()=>assert.fail('delete')},BOOKING_WORKER_SECRET:'former-secret'};
  for(const path of ['upload','delete']) await assert.rejects(bookingRoute(new Request(`https://worker.test/bookings/${path}`,{method:'POST',body:'{}'}),env,{},{}),/booking_uploads_retired/);
});
