const LIMITS = Object.freeze({image: 10 * 1024 * 1024, video: 50 * 1024 * 1024, files: 30, dailyFiles: 100, dailyBytes: 500 * 1024 * 1024});
function validId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw new Error('invalid_id');
  return value;
}
function imageBytes(value) {
  if (typeof value !== 'string' || value.length > Math.ceil(LIMITS.image / 3) * 4 || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) throw new Error('invalid_image');
  const bytes = Buffer.from(value, 'base64');
  const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  const png = bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
  if (!bytes.length || bytes.length > LIMITS.image || (!jpeg && !png)) throw new Error('invalid_image');
  return {bytes, type: jpeg ? 'image/jpeg' : 'image/png'};
}
function canRead(media, venue, user, uid) {
  if (!media || !['pending','approved'].includes(media.status)) return false;
  if (user && !user.isBlocked && (user.isAdmin === true || (venue?.ownerId === uid && media.ownerUid === uid))) return true;
  return media.kind === 'venue' && media.status === 'approved' && venue?.active === true && venue.ownerId === media.ownerUid;
}
function canDeleteKey(media, id) {
  return media.provider === 'r2' && media.key === `bookings/venues/${media.venueId}/${media.ownerUid}/${id}.mp4` && media.status === 'delete_pending';
}
module.exports = {LIMITS, validId, imageBytes, canRead, canDeleteKey};
