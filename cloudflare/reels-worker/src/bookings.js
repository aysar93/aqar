// Read-only compatibility for private legacy booking videos.
const idPattern = /^[A-Za-z0-9_-]{1,128}$/;
function denied(status, message) { const e=new Error(message); e.status=status; throw e; }
export async function bookingRoute(request, env, headers, helpers) {
  const url=new URL(request.url);
  if(!['GET','HEAD'].includes(request.method)) denied(410,'booking_uploads_retired');
  if(!env.BOOKINGS_BUCKET) denied(503,'booking_configuration_required');
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
