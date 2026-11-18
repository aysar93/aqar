async function authorizedPath({db,bucket,uid,user,path}) {
  if (typeof path !== 'string' || path.length>1024 || path.includes('..')) return false;
  const parts=path.split('/');
  if (parts.length===5 && parts[0]==='uploads' && parts[1]==='private' && ['license','receipt'].includes(parts[2])) return user.isAdmin===true || parts[3]===uid;
  if (parts.length===6 && parts[0]==='uploads' && parts[1]==='private' && ['chat_images','chat_audio'].includes(parts[2])) return user.isAdmin===true || parts[3]===uid;
  if (parts.length===4 && parts[0]==='booking_receipts') {
    const b=(await db.doc(`bookings/${parts[1]}`).get()).data();
    return !!b && (user.isAdmin===true || b.customerId===uid || b.ownerId===uid);
  }
  if (parts.length===7 && parts.slice(0,3).join('/')==='staging/private/cloudinary-hwxcrlcj') {
    const acl=(await db.doc(`media_asset_acl/${parts[4]}`).get()).data();
    return !!acl && acl.object===path && acl.classification==='private' && acl.approved===true && (user.isAdmin===true || (Array.isArray(acl.owners) && acl.owners.includes(uid)));
  }
  return false;
}
function createPrivateReadHandler({auth,db,bucket}) {
  return async (req,res) => {
    try {
      if (!['GET','HEAD'].includes(req.method)) return res.status(405).end();
      const bearer=/^Bearer (\S+)$/.exec(req.headers.authorization || '');
      if (!bearer) return res.status(401).end();
      const token=await auth.verifyIdToken(bearer[1],true);
      if (!token.uid || token.firebase?.sign_in_provider==='anonymous') return res.status(403).end();
      const user=(await db.doc(`users/${token.uid}`).get()).data();
      if (!user || (user.isBlocked!==undefined&&user.isBlocked!==false) || !await authorizedPath({db,bucket,uid:token.uid,user,path:req.query?.path})) return res.status(403).end();
      const file=bucket.file(req.query.path),[metadata]=await file.getMetadata();
      if (metadata.metadata?.firebaseStorageDownloadTokens || Number(metadata.size)>10*1024*1024) return res.status(409).end();
      if (req.query.path.startsWith('staging/private/cloudinary-hwxcrlcj/')) {
        const acl=(await db.doc(`media_asset_acl/${req.query.path.split('/')[4]}`).get()).data();
        if (!acl || acl.approved!==true || String(acl.generation)!==String(metadata.generation) || acl.sha256!==metadata.metadata?.sha256) return res.status(409).end();
      }
      res.set('Cache-Control','no-store');res.set('Content-Type',metadata.contentType || 'application/octet-stream');res.set('X-Content-Type-Options','nosniff');
      if (req.method==='HEAD') return res.status(200).end();
      const pinnedFile=metadata.generation ? bucket.file(req.query.path,{generation:metadata.generation}) : file;
      const [bytes]=await pinnedFile.download({validation:'crc32c'});
      return res.status(200).send(bytes);
    } catch (error) {
      const code=String(error?.code || '');
      if (code.startsWith('auth/')) return res.status(401).end();
      if (Number(error?.code)===404) return res.status(404).end();
      console.error('media_read_dependency_error', /^[A-Za-z0-9_/-]{1,60}$/.test(code) ? code : 'unknown');
      return res.status(503).end();
    }
  };
}
module.exports={authorizedPath,createPrivateReadHandler};
