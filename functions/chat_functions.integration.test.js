const test = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
if (!['127.0.0.1:8185', 'localhost:8185'].includes(process.env.FIRESTORE_EMULATOR_HOST)) throw new Error('Local demo emulator required');
initializeApp({ projectId: 'demo-aqar', storageBucket: 'demo-aqar.appspot.com' });
const db = getFirestore();
const { deleteChatMessage, chatAwayReply, chatDeletedAttachmentCleanup } = require('./chat_functions');

test('server deletion authorizes sender, rejects expired and forged ownership, and maintains preview', async () => {
  await db.doc('users/function-owner').set({ isAdmin: false, isBlocked: false });
  await db.doc('users/function-admin').set({ isAdmin: true, isBlocked: false });
  await db.doc('settings/app_settings').set({ chatPreferences: { deleteHours: 24 } });
  const chat = db.doc('chats/function-owner');
  await chat.set({ lastMessageId: 'fresh', lastMessage: 'private' });
  const create = (id, age, senderId = 'function-owner') => chat.collection('messages').doc(id).set({ senderType: 'user', senderId, createdAt: Timestamp.fromMillis(Date.now() - age), message: 'private', type: 'text' });
  await create('fresh', 1000);
  await create('expired', 25 * 3600000);
  await create('foreign', 1000, 'other');
  const request = (messageId, uid = 'function-owner') => ({ auth: { uid }, data: { chatId: 'function-owner', messageId } });
  await assert.rejects(deleteChatMessage.run(request('expired')), error => error.code === 'permission-denied');
  await assert.rejects(deleteChatMessage.run(request('foreign')), error => error.code === 'permission-denied');
  await assert.rejects(deleteChatMessage.run(request('fresh', 'intruder')), error => error.code === 'permission-denied');
  await deleteChatMessage.run(request('fresh'));
  const deleted = (await chat.collection('messages').doc('fresh').get()).data();
  assert.equal(deleted.message, '');
  assert.equal(deleted.type, 'deleted');
  assert.equal(deleted.deletedBy, 'function-owner');
  assert.equal((await chat.get()).data().lastMessage, 'تم حذف هذه الرسالة');
  await deleteChatMessage.run(request('fresh'));
  await deleteChatMessage.run(request('expired', 'function-admin'));
});

test('outside-hours reply is server-generated and idempotent under simultaneous triggers', async () => {
  await db.doc('settings/app_settings').set({ allowChat: true, chatPreferences: { hoursEnabled: true, openingMinute: 540, closingMinute: 1080, workDays: [5], awayMessage: 'خارج وقت العمل' } });
  const chat = db.doc('chats/away-owner');
  await chat.set({ isClosed: false, isBlocked: false, unreadUser: 0, lastMessageId: 'source' });
  const reference = chat.collection('messages').doc('source');
  await reference.set({ senderType: 'user', message: 'hello', createdAt: Timestamp.fromDate(new Date('2026-10-02T20:00:00Z')) });
  const snapshot = await reference.get();
  const event = { data: snapshot, params: { chatId: 'away-owner', messageId: 'source' } };
  await Promise.all([chatAwayReply.run(event), chatAwayReply.run(event)]);
  assert.equal((await chat.collection('messages').doc('away_2026-10-02').get()).data().senderType, 'system');
  assert.equal((await chat.get()).data().unreadUser, 1);
  assert.equal((await chat.collection('messages').get()).size, 2);
});

test('deletion removes stored media and the retry trigger cleans remaining attachments', async () => {
  if (!['127.0.0.1:9198', 'localhost:9198'].includes(process.env.FIREBASE_STORAGE_EMULATOR_HOST)) throw new Error('Isolated storage emulator required');
  const bucket = getStorage().bucket();
  const audioPath = 'chat_audio/function-owner/function-owner/123.m4a';
  const imagePath = 'chat_images/function-owner/function-owner/124.jpg';
  const audio = bucket.file(audioPath);
  const image = bucket.file(imagePath);
  await audio.save(Buffer.from('audio'), { resumable: false, metadata: { contentType: 'audio/mp4' } });
  await image.save(Buffer.from('image'), { resumable: false, metadata: { contentType: 'image/jpeg' } });
  const reference = db.doc('chats/function-owner/messages/media');
  await reference.set({ senderId: 'function-owner', senderType: 'user', createdAt: Timestamp.now(), type: 'audio', message: '', audioPath, imagePath });
  await deleteChatMessage.run({ auth: { uid: 'function-owner' }, data: { chatId: 'function-owner', messageId: 'media' } });
  assert.equal((await audio.exists())[0], false);
  assert.equal((await image.exists())[0], false);
  await image.save(Buffer.from('retry cleanup'), { resumable: false });
  await chatDeletedAttachmentCleanup.run({ data: { after: await reference.get() }, params: { chatId: 'function-owner', messageId: 'media' } });
  assert.equal((await image.exists())[0], false);
});
