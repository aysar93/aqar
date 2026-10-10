// Private booking bucket: never use REELS_BUCKET or R2_PUBLIC_BASE_URL here.
const MAX = 50 * 1024 * 1024;
const idPattern = /^[A-Za-z0-9_-]{1,128}$/;
function denied(status, message) { const e=new Error(message); e.status=status; throw e; }
export function validatedVideoStream(request, expectedSize) {
  if (!Number.isSafeInteger(expectedSize) || expectedSize < 12 || expectedSize > MAX) denied(413,'video_too_large');
  if (request.headers.get('content-type') !== 'video/mp4') denied(415,'mp4_required');
  const declared=request.headers.get('content-length');
  if(declared && Number(declared)!==expectedSize) denied(400,'size_mismatch');
  if(!request.body) denied(400,'empty_video');
  const reader=request.body.getReader();
  const prefix=new Uint8Array(12); let prefixSize=0,size=0,checked=false;
  const deadline=Date.now()+5*60*1000;
  return new ReadableStream({
    async pull(controller) {
      try {
        const remaining=deadline-Date.now(); if(remaining<=0) denied(408,'upload_timeout');
        let timer;
        const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>{const e=new Error('upload_timeout');e.status=408;reject(e);},remaining);});
        let chunk; try {chunk=await Promise.race([reader.read(),timeout]);} finally {clearTimeout(timer);}
        const {value,done}=chunk;
        if(done) {
          if(size!==expectedSize || !checked) denied(400,'size_mismatch');
          reader.releaseLock(); controller.close(); return;
        }
        size+=value.byteLength;
        if(size>MAX || size>expectedSize) denied(413,'video_too_large');
        if(!checked) {
          const count=Math.min(12-prefixSize,value.byteLength);
          prefix.set(value.subarray(0,count),prefixSize); prefixSize+=count;
          if(prefixSize>=8) {
            if(String.fromCharCode(...prefix.subarray(4,8))!=='ftyp') denied(415,'invalid_mp4');
            checked=true;
          }
        }
        controller.enqueue(value);
      } catch(error) {await reader.cancel().catch(()=>{}); controller.error(error);}
    },
    cancel(reason) {return reader.cancel(reason);}
  });
}

async function bridge(env, mediaId, action, request, size) {
  const url=new URL(env.BOOKING_VIDEO_BRIDGE_URL);
  if(url.protocol!=='https:') denied(503,'booking_configuration_required');
  const response=await fetch(url,{method:'POST',headers:{'content-type':'application/json','authorization':request.headers.get('authorization')||'','x-booking-worker-secret':env.BOOKING_WORKER_SECRET},body:JSON.stringify({mediaId,action,size}),signal:AbortSignal.timeout(60000)});
  if(!response.ok) denied(403,'booking_media_denied');
  return response.json();
}
function equal(a,b) {
  if(typeof a!=='string' || typeof b!=='string' || !b.length) return false;
  let diff=a.length^b.length;
  for(let i=0;i<b.length;i++) diff|=(a.charCodeAt(i)||0)^b.charCodeAt(i);
  return diff===0;
}
export async function bookingRoute(request, env, headers, helpers) {
  const url=new URL(request.url);
  if(!env.BOOKINGS_BUCKET || !env.BOOKING_WORKER_SECRET || !env.BOOKING_VIDEO_BRIDGE_URL) denied(503,'booking_configuration_required');
  if(url.pathname==='/bookings/upload' && request.method==='POST') {
    const mediaId=url.searchParams.get('mediaId'); if(!idPattern.test(mediaId||'')) denied(400,'invalid_media');
    // Firebase Admin verifies project, expiry, revocation, nonanonymous user,
    // current ownership and atomic quota/reservation in the booking bridge.
    const grant=await bridge(env,mediaId,'claim',request);
    const keyPattern=new RegExp(`^bookings/venues/[A-Za-z0-9_-]{1,128}/[A-Za-z0-9_-]{1,128}/${mediaId}\\.mp4$`);
    if(!keyPattern.test(grant.key)) denied(403,'invalid_key');
    const bounded=validatedVideoStream(request,grant.size);
    // FixedLengthStream gives R2 a known length while the transform enforces
    // actual bytes and MP4 header. A stream error aborts the atomic object put.
    const fixed=new FixedLengthStream(grant.size);
    await env.BOOKINGS_BUCKET.put(grant.key,bounded.pipeThrough(fixed),{httpMetadata:{contentType:'video/mp4'}});
    // Keep the reservation if finalization fails: the server queue will retry
    // deletion after expiry. Never blindly delete after an ambiguous commit.
    await bridge(env,mediaId,'finish',request,grant.size);
    return new Response(JSON.stringify({mediaId,path:grant.path}),{status:201,headers:{...headers,'content-type':'application/json'}});
  }
  if(url.pathname==='/bookings/delete' && request.method==='POST') {
    if(!equal(request.headers.get('x-booking-worker-secret'),env.BOOKING_WORKER_SECRET)) denied(403,'server_required');
    const body=await request.json(), mediaId=body.mediaId;
    if(!idPattern.test(mediaId||'')) denied(400,'invalid_media');
    const grant=await bridge(env,mediaId,'delete',request);
    if(!grant.key?.startsWith('bookings/venues/') || !grant.key.endsWith(`/${mediaId}.mp4`)) denied(403,'invalid_key');
    await env.BOOKINGS_BUCKET.delete(grant.key);
    return new Response(JSON.stringify({ok:true}),{headers:{...headers,'content-type':'application/json'}});
  }
  const match=url.pathname.match(/^\/bookings\/media\/([A-Za-z0-9_-]{1,128})\.mp4$/);
  if(match && ['GET','HEAD'].includes(request.method)) {
    const token=await helpers.googleAccessToken(env);
    const record=await helpers.firestoreGet(`booking_media_reviews/${match[1]}`,env,token);
    const f=record?.fields;
    if(!f || f.provider?.stringValue!=='r2' || !['pending','approved'].includes(f.status?.stringValue)) denied(404,'media_unavailable');
    const venueId=f.venueId?.stringValue, owner=f.ownerUid?.stringValue;
    if(!idPattern.test(venueId||'') || !idPattern.test(owner||'')) denied(403,'invalid_key');
    const key=`bookings/venues/${venueId}/${owner}/${match[1]}.mp4`;
    if(f.key?.stringValue!==key) denied(403,'invalid_key');
    const venue=await helpers.firestoreGet(`booking_venues/${venueId}`,env,token);
    const v=venue?.fields;
    const ownerRecord=await helpers.firestoreGet(`users/${owner}`,env,token);
    let allowed=ownerRecord && ownerRecord.fields.isBlocked?.booleanValue!==true && f.status.stringValue==='approved' && v?.active?.booleanValue===true && v.ownerId?.stringValue===owner;
    if(!allowed && request.headers.has('authorization')) {
      const auth=await helpers.authenticatedUser(request,env);
      const user=await helpers.firestoreGet(`users/${auth.uid}`,env,token);
      allowed=user && user.fields.isBlocked?.booleanValue!==true && (user.fields.isAdmin?.booleanValue===true || v?.ownerId?.stringValue===auth.uid && owner===auth.uid);
    }
    if(!allowed) denied(403,'media_unavailable');
    const range=request.headers.get('range');
    if(range && !/^bytes=\d*-\d*$/.test(range)) denied(416,'invalid_range');
    const object=await env.BOOKINGS_BUCKET.get(key,range?{range:request.headers}:undefined);
    if(!object) denied(404,'media_unavailable');
    const h=new Headers({...headers,'content-type':'video/mp4','cache-control':'private, no-store','accept-ranges':'bytes','etag':object.httpEtag});
    if(object.range) {
      h.set('content-range',`bytes ${object.range.offset}-${object.range.offset+object.range.length-1}/${object.size}`);
      h.set('content-length',String(object.range.length));
    } else h.set('content-length',String(object.size));
    return new Response(request.method==='HEAD'?null:object.body,{status:object.range?206:200,headers:h});
  }
  denied(404,'not_found');
}
