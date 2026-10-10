// Booking v3 only. Authorize against live documents, without Storage's two-read limit.
const {onRequest} = require('firebase-functions/v2/https');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {createHash} = require('node:crypto');
const CHUNK = 4 * 1024 * 1024;
async function identity(req) {
  const header = req.get('authorization');
  if (!header) return null;
  const token = await getAuth().verifyIdToken(header.replace(/^(Bearer|Firebase) /, ''), true);
  const user = (await getFirestore().doc(`users/${token.uid}`).get()).data();
  if (!user || user.isBlocked || token.firebase?.sign_in_provider === 'anonymous') throw Error('denied');
  return {...user, uid: token.uid};
}
async function context(id, legacyPath) {
  if (legacyPath !== undefined) {
    const parts = /^booking_media\/([A-Za-z0-9_-]+)\/([A-Za-z0-9_-]+)\/([A-Za-z0-9_-]+\.(jpg|png|mp4))$/.exec(legacyPath);
    if (!parts) throw Error('denied');
    const [,venueId,ownerUid,name,ext] = parts;
    const record = (await getFirestore().doc(`booking_media_reviews/${venueId}_${name}`).get()).data();
    const type = {jpg:'image/jpeg',png:'image/png',mp4:'video/mp4'}[ext];
    if (!record || record.schemaVersion || record.path !== legacyPath || record.venueId !== venueId || record.ownerId !== ownerUid || record.type !== type) throw Error('denied');
    const [owner,venue] = await Promise.all([getFirestore().doc(`users/${ownerUid}`).get(),getFirestore().doc(`booking_venues/${venueId}`).get()]);
    return {m:{...record,kind:'venue',ownerUid},owner:owner.data(),venue:venue.data()};
  }
  if (typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(id)) throw Error('denied');
  const m = (await getFirestore().doc(`booking_media_reviews/${id}`).get()).data();
  if (!m || m.schemaVersion !== 3 || m.provider !== 'firebase') throw Error('denied');
  const ext = {'image/jpeg':'jpg','image/png':'png','video/mp4':'mp4'}[m.type];
  if (!ext || !/^[A-Za-z0-9_-]+$/.test(m.venueId) || !/^[A-Za-z0-9_-]+$/.test(m.ownerUid) || m.path !== `booking_media_v3/${m.venueId}/${m.ownerUid}/${id}.${ext}`) throw Error('denied');
  const [owner, venue] = await Promise.all([
    getFirestore().doc(`users/${m.ownerUid}`).get(),
    getFirestore().doc(`${m.kind === 'banner' ? 'booking_banners' : 'booking_venues'}/${m.kind === 'banner' ? m.bannerId || '__missing__' : m.venueId}`).get()
  ]);
  return {m, owner:owner.data(), venue:venue.data()};
}
function canRead({m, owner, venue}, u) {
  if (!['pending','approved'].includes(m.status)) return false;
  const owns = m.kind === 'banner' ? u?.uid === m.ownerUid : venue?.ownerId === m.ownerUid && u?.uid === m.ownerUid;
  if (u?.isAdmin === true || owns) return true;
  return m.status === 'approved' && owner && !owner.isBlocked &&
    (m.kind === 'banner' ? venue?.isActive === true && venue?.mediaId === m.path.split('/').pop().split('.')[0] : venue?.active === true && venue?.ownerId === m.ownerUid && (venue.mediaPaths || []).includes(m.path));
}
function canUpload({m, venue}, u) {
  return u && m.kind === 'venue' && m.type === 'video/mp4' && m.status === 'uploading' && m.expiresAt > Date.now() && m.ownerUid === u.uid && venue?.ownerId === u.uid;
}
exports.bookingMediaContent = onRequest({cors:true, timeoutSeconds:120, memory:'256MiB', maxInstances:5, concurrency:4}, async (req,res) => {
  res.set('Cache-Control','private, no-store');
  if (!['GET','HEAD'].includes(req.method)) return res.status(405).end();
  try {
    const u = await identity(req), c = await context(req.query.mediaId, req.query.path);
    if (!canRead(c,u)) return res.status(403).end();
    const file = getStorage().bucket().file(c.m.path), [meta] = await file.getMetadata();
    if (meta.contentType !== c.m.type || (c.m.schemaVersion === 3 && String(meta.generation) !== c.m.generation)) return res.status(403).end();
    const size = Number(meta.size); let start=0, end=size-1;
    if (req.get('range')) {
      const range = /^bytes=(\d*)-(\d*)$/.exec(req.get('range'));
      if (!range || (!range[1] && !range[2])) return res.status(416).set('Content-Range',`bytes */${size}`).end();
      start=range[1]?Number(range[1]):Math.max(0,size-Number(range[2]));
      end=range[1]&&range[2]?Math.min(size-1,Number(range[2])):size-1;
      if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start>end || start>=size) return res.status(416).set('Content-Range',`bytes */${size}`).end();
      res.status(206).set('Content-Range',`bytes ${start}-${end}/${size}`);
    }
    // Keep each streamed response below the Functions streaming payload limit.
    // HEAD advertises the full size; mobile fetches authenticated ranges.
    if (req.method !== 'HEAD' && end-start+1 > 8*1024*1024) return res.status(416).set('Content-Range',`bytes */${size}`).end();
    res.set({'Content-Type':c.m.type,'Content-Length':String(end-start+1),'Accept-Ranges':'bytes'});
    if (req.method==='HEAD') return res.end();
    const stream = file.createReadStream({start,end,generation:meta.generation});
    res.on('close',()=>stream.destroy());
    stream.on('error',()=>{if(!res.headersSent) res.status(404).end(); else res.destroy();}).pipe(res);
  } catch (e) { console.warn('booking_media_read_denied', {code:e.code || 'authorization'}); res.status(e.code===404?404:403).end(); }
});
exports.uploadBookingVideoChunk = onRequest({cors:true, timeoutSeconds:120, memory:'256MiB', maxInstances:5, concurrency:4}, async (req,res) => {
  if(req.method!=='POST') return res.status(405).end();
  try {
    const u=await identity(req), id=req.query.mediaId, c=await context(id), index=Number(req.query.index);
    if(!canUpload(c,u)) return res.status(403).end();
    const count=Math.ceil(c.m.size/CHUNK), bytes=req.rawBody;
    if(!Number.isInteger(index) || index<0 || index>=count || !bytes || bytes.length!==Math.min(CHUNK,c.m.size-index*CHUNK)) return res.status(400).end();
    const file=getStorage().bucket().file(`_booking_upload_parts/${id}/${index}`), digest=createHash('sha256').update(bytes).digest('hex');
    try {await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{metadata:{sha256:digest},cacheControl:'private, no-store'}});}
    catch(e) {if(e.code!==412) throw e; const [meta]=await file.getMetadata(); if(meta.metadata?.sha256!==digest) return res.status(409).end();}
    if(!canUpload(await context(id),await identity(req))) return res.status(403).end();
    res.json({ok:true,index});
  } catch(e) {console.warn('booking_video_chunk_failed',{code:e.code || 'authorization'});res.status(e.message==='denied' || String(e.code).startsWith('auth/') ? 403 : 500).end();}
});
exports._policy = {canRead,canUpload,CHUNK};
