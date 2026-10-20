// Deliberately not exported by index.js: deployment requires a separate approval.
// GCS Admin writes never call Firebase upload or getDownloadURL endpoints.
const { createHash } = require('node:crypto');
function validateBody(body) {
  if (!body || !/^[a-f0-9]{32}$/.test(body.uploadId || '')) throw Error('INVALID_UPLOAD_OPERATION');
  const purposes = ['property', 'avatar', 'office', 'banner', 'appLogo', 'license', 'receipt', 'chatImage', 'chatAudio', 'bookingReceipt'];
  if (!body || !purposes.includes(body.purpose) || typeof body.content !== 'string' || body.content.length > 14 * 1024 * 1024 || !/^[A-Za-z0-9+/]*={0,2}$/.test(body.content)) throw Error('INVALID_MEDIA');
  const bytes = Buffer.from(body.content, 'base64');
  if (!bytes.length || bytes.toString('base64') !== body.content) throw Error('INVALID_MEDIA');
  let ext, mime;
  if (body.purpose === 'chatAudio') {
    if (bytes.length > 5 * 1024 * 1024 || !Number.isInteger(body.seconds) || body.seconds < 1 || body.seconds > 120 || bytes.subarray(4,8).toString() !== 'ftyp') throw Error('INVALID_AUDIO');
    ext='m4a'; mime='audio/mp4';
  } else {
    if (bytes.length > 10 * 1024 * 1024) throw Error('IMAGE_TOO_LARGE');
    if (bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) { ext='png'; mime='image/png'; }
    else if (bytes.length >= 3 && bytes[0]===255 && bytes[1]===216 && bytes[2]===255) { ext='jpg'; mime='image/jpeg'; }
    else throw Error('INVALID_IMAGE');
    if (body.purpose === 'bookingReceipt' && ext !== 'jpg') throw Error('INVALID_RECEIPT');
  }
  for (const key of ['chatId','bookingId']) if (body[key] != null && (typeof body[key] !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(body[key]))) throw Error('INVALID_ID');
  return {bytes,ext,mime,sha256:createHash('sha256').update(bytes).digest('hex')};
}
function createPrivateUploadHandler({auth,db,bucket,authorizeQuota}) {
  if (!bucket?.name || typeof authorizeQuota !== 'function') throw Error('Explicit bucket and bounded quota required');
  return async function handler(req,res) {
    try {
      if (req.method !== 'POST') return res.status(405).json({error:'method'});
      const bearer = /^Bearer (\S+)$/.exec(req.headers.authorization || '');
      if (!bearer) return res.status(401).json({error:'authentication'});
      const token = await auth.verifyIdToken(bearer[1],true);
      if (!token.uid || token.firebase?.sign_in_provider === 'anonymous') return res.status(403).json({error:'authentication'});
      const uid=token.uid, data=validateBody(req.body);
      const user=(await db.doc(`users/${uid}`).get()).data();
      if (!user || user.isBlocked !== false) return res.status(403).json({error:'access'});
      const body=req.body; let path;
      if (['chatImage','chatAudio'].includes(body.purpose)) {
        if (!body.chatId || (uid !== body.chatId && user.isAdmin !== true)) return res.status(403).json({error:'access'});
        const chat=(await db.doc(`chats/${body.chatId}`).get()).data();
        const settings=(await db.doc('settings/app_settings').get()).data();
        if (!chat || chat.isBlocked !== false || chat.isClosed !== false || settings?.allowChat !== true || (body.purpose==='chatAudio' && (settings.chatPreferences?.voiceEnabled !== true || body.seconds > (settings.chatPreferences.voiceSeconds ?? 120)))) return res.status(403).json({error:'chat'});
        path=`uploads/private/${body.purpose==='chatImage'?'chat_images':'chat_audio'}/${body.chatId}/${uid}/${body.uploadId}.${data.ext}`;
      } else if (body.purpose==='bookingReceipt') {
        if (!body.bookingId) throw Error('INVALID_BOOKING');
        const booking=(await db.doc(`bookings/${body.bookingId}`).get()).data();
        if (!booking || booking.customerId !== uid || booking.status !== 'held' || !Number.isFinite(booking.holdUntil) || booking.holdUntil <= Date.now()) return res.status(403).json({error:'booking'});
        // Stable digits retain the historical booking-path contract and deduplicate retries.
        const numeric=BigInt('0x'+body.uploadId).toString();
        path=`booking_receipts/${body.bookingId}/${uid}/${numeric}.jpg`;
      } else {
        const isPublic=['property','avatar','office','banner','appLogo'].includes(body.purpose);
        if (['banner','appLogo'].includes(body.purpose) && user.isAdmin!==true) return res.status(403).json({error:'admin'});
        path=`uploads/${isPublic?'public':'private'}/${body.purpose}/${uid}/${body.uploadId}.${data.ext}`;
      }
      const file=bucket.file(path); let metadata;
      try { [metadata]=await file.getMetadata(); }
      catch(error) { if (Number(error.code)!==404) throw error; }
      if (!metadata) {
        await authorizeQuota({uid,bytes:data.bytes.length,purpose:body.purpose});
        try { await file.save(data.bytes,{resumable:false,validation:'crc32c',preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:data.mime,cacheControl:'no-store',metadata:{sha256:data.sha256,uploadOperationId:body.uploadId,origin:'authenticated-media-broker'}}}); }
        catch(error) { if (Number(error.code)!==412) throw error; }
        [metadata]=await file.getMetadata();
      }
      if (Number(metadata.size)!==data.bytes.length || metadata.metadata?.sha256!==data.sha256 || metadata.metadata?.uploadOperationId!==body.uploadId || metadata.metadata?.firebaseStorageDownloadTokens) throw Error('UNSAFE_OBJECT_METADATA');
      return res.status(200).json({path,url:`https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media`});
    } catch (error) {
      const code=String(error?.code || '');
      if (code.startsWith('auth/')) return res.status(401).json({error:'authentication'});
      if (error?.message==='UPLOAD_QUOTA') return res.status(429).json({error:'upload_quota'});
      if (/^(INVALID_|IMAGE_TOO_LARGE)/.test(error?.message || '')) return res.status(400).json({error:'invalid_media'});
      if (error?.message==='UNSAFE_OBJECT_METADATA') return res.status(409).json({error:'object_conflict'});
      console.error('media_upload_dependency_error', /^[A-Za-z0-9_/-]{1,60}$/.test(code) ? code : 'unknown');
      return res.status(503).json({error:'temporarily_unavailable'});
    }
  };
}
// Supply this transaction-backed limiter only in the separately approved deployment.
function firestoreQuota(db,now=Date.now) {
  return async ({uid,bytes}) => db.runTransaction(async transaction => {
    const hour=Math.floor(now()/3600000), ref=db.doc(`media_upload_budgets/${uid}_${hour}`);
    const old=(await transaction.get(ref)).data() || {count:0,bytes:0};
    if (!Number.isSafeInteger(old.count) || !Number.isSafeInteger(old.bytes) || old.count<0 || old.bytes<0 || old.count>=20 || old.bytes+bytes>50*1024*1024) throw Error('UPLOAD_QUOTA');
    transaction.set(ref,{count:old.count+1,bytes:old.bytes+bytes,expiresAtMillis:(hour+2)*3600000});
  });
}
module.exports={createPrivateUploadHandler,validateBody,firestoreQuota};
