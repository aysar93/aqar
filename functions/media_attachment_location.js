function attachmentLocation(chatId, path, mediaBucket) {
  if (typeof path !== 'string' || typeof chatId !== 'string' || !chatId || chatId.includes('/') || path.includes('..')) return null;
  const p = path.split('/');
  if (p.length === 4 && ['chat_images', 'chat_audio'].includes(p[0]) && p[1] === chatId && p[2] && /^[0-9]+\.(jpg|png|m4a)$/.test(p[3])) return { path, bucket: null };
  if (p.length !== 6 || p[0] !== 'uploads' || p[1] !== 'private' || !['chat_images', 'chat_audio'].includes(p[2]) || p[3] !== chatId || !p[4] || !mediaBucket) return null;
  const suffix = p[2] === 'chat_audio' ? /^[a-f0-9]{32}\.m4a$/ : /^[a-f0-9]{32}\.(jpg|png)$/;
  return suffix.test(p[5]) ? { path, bucket: mediaBucket } : null;
}
module.exports = { attachmentLocation };
