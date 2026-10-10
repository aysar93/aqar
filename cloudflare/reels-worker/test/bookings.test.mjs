import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validatedVideoStream,bookingRoute} from '../src/bookings.js';
async function readVideo(request,size) {return new Uint8Array(await new Response(validatedVideoStream(request,size)).arrayBuffer());}
const mp4=new Uint8Array([0,0,0,12,102,116,121,112,109,112,52,50]);
function request(bytes, headers={}) {return new Request('https://worker.test/bookings/upload',{method:'POST',headers:{'content-type':'video/mp4',...headers},body:bytes});}
test('actual body size, MIME, empty and MP4 header are checked',async()=>{
  assert.deepEqual(await readVideo(request(mp4),12),mp4);
  await assert.rejects(readVideo(request(mp4),11));
  await assert.rejects(readVideo(request(mp4),13),/size_mismatch/);
  await assert.rejects(readVideo(request(mp4,{'content-length':'13'}),12),/size_mismatch/);
  await assert.rejects(readVideo(request(mp4,{'content-type':'image/png'}),12),/mp4_required/);
  await assert.rejects(readVideo(request(new Uint8Array(12)),12),/invalid_mp4/);
  await assert.rejects(readVideo(request(new Uint8Array(20)),12),/video_too_large/);
});
test('booking routes fail closed without private bucket and server settings',async()=>{
  await assert.rejects(bookingRoute(request(mp4),{REELS_BUCKET:{}},{},{}),/booking_configuration_required/);
});
test('upload uses server-owned key, exact bytes and finalizes after put',async t=>{
  const actions=[],puts=[];
  const original=globalThis.FixedLengthStream;
  globalThis.FixedLengthStream=class extends TransformStream {constructor(size) {let count=0; super({transform(chunk,controller){count+=chunk.byteLength;if(count>size)throw Error('length');controller.enqueue(chunk);},flush(){if(count!==size)throw Error('length');}});}};
  t.after(()=>{if(original) globalThis.FixedLengthStream=original;else delete globalThis.FixedLengthStream;});
  t.mock.method(globalThis,'fetch',async(url,options)=>{
    const body=JSON.parse(options.body); actions.push(body.action);
    assert.equal(options.headers['authorization'],'Bearer firebase-token');
    return Response.json({key:'bookings/venues/v/u/media-id.mp4',size:12,path:'https://worker.test/bookings/media/media-id.mp4'});
  });
  const env={BOOKINGS_BUCKET:{put:async(key,stream,options)=>puts.push([key,new Uint8Array(await new Response(stream).arrayBuffer()),options])},BOOKING_WORKER_SECRET:'test-only',BOOKING_VIDEO_BRIDGE_URL:'https://bridge.test'};
  const req=new Request('https://worker.test/bookings/upload?mediaId=media-id',{method:'POST',headers:{'content-type':'video/mp4',authorization:'Bearer firebase-token'},body:mp4});
  assert.equal((await bookingRoute(req,env,{},{})).status,201);
  assert.deepEqual(actions,['claim','finish']); assert.equal(puts[0][0],'bookings/venues/v/u/media-id.mp4');
  assert.deepEqual(puts[0][1],mp4);
});
test('unauthorized deletion never contacts backend or bucket',async()=>{
  const env={BOOKINGS_BUCKET:{delete:()=>assert.fail('delete')},BOOKING_WORKER_SECRET:'secret',BOOKING_VIDEO_BRIDGE_URL:'https://bridge.test'};
  const req=new Request('https://worker.test/bookings/delete',{method:'POST',body:'{}'});
  await assert.rejects(bookingRoute(req,env,{},{}),/server_required/);
});
test('private playback denies pending guests and serves approved ranged bytes',async()=>{
  let status='pending',active=true;
  const fields={provider:{stringValue:'r2'},status:{stringValue:status},venueId:{stringValue:'v'},ownerUid:{stringValue:'u'},key:{stringValue:'bookings/venues/v/u/media-id.mp4'}};
  const helpers={googleAccessToken:async()=>'',firestoreGet:async path=>({fields:path.startsWith('booking_media_reviews')?{...fields,status:{stringValue:status}}:{active:{booleanValue:active},ownerId:{stringValue:'u'}}})};
  const env={BOOKING_WORKER_SECRET:'secret',BOOKING_VIDEO_BRIDGE_URL:'https://bridge.test',BOOKINGS_BUCKET:{get:async()=>({size:12,httpEtag:'etag',body:mp4,range:{offset:0,length:12}})}};
  const req=new Request('https://worker.test/bookings/media/media-id.mp4',{headers:{range:'bytes=0-11'}});
  await assert.rejects(bookingRoute(req,env,{},helpers),/media_unavailable/);
  status='approved'; const response=await bookingRoute(req,env,{},helpers);
  assert.equal(response.status,206); assert.equal(response.headers.get('content-range'),'bytes 0-11/12');
  active=false; await assert.rejects(bookingRoute(req,env,{},helpers),/media_unavailable/);
});
