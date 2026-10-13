const test = require('node:test');
const assert = require('node:assert/strict');
const { pushEvent, messageFor, permanentErrors } = require('./push_policy');
const base = { userId: 'recipient', pushTransport: 'fcm_v1', type: 'general', title: 'عنوان', message: 'رسالة' };
test('legacy, internal, broadcast, deletion and read updates never send', () => {
  for (const data of [null, { ...base, pushTransport: undefined }, { ...base, deliveryType: 'internal' }, { ...base, userId: 'all' }, { ...base, userId: '../other' }]) assert.equal(pushEvent(data, null, 'n'), null);
  assert.equal(pushEvent(base, { ...base, readBy: [] }, 'n'), null);
});
test('collapsed chat sends every new message, but ignores read/deletion-preview updates', () => {
  const chat = { ...base, type: 'chat_message', chatId: 'c', messageId: 'm1' };
  assert.ok(pushEvent(chat, null, 'n'));
  assert.equal(pushEvent({ ...chat, message: 'deleted', unreadCount: 0 }, chat, 'n'), null);
  assert.notEqual(pushEvent(chat, null, 'n').key, pushEvent({ ...chat, messageId: 'm2' }, chat, 'n').key);
  assert.equal(pushEvent({ ...chat, messageId: '' }, null, 'n'), null);
});
test('comment/reply retry identities survive duplicate inbox documents and separate recipients', () => {
  for (const type of ['comment', 'reply']) {
    const event = { ...base, type, propertyId: 'p', commentId: 'c', replyId: 'r' };
    assert.equal(pushEvent(event, null, 'a').key, pushEvent(event, null, 'b').key);
    assert.notEqual(pushEvent(event, null, 'a').key, pushEvent({ ...event, userId: 'another' }, null, 'a').key);
  }
});
test('server controls identity; FCM data strings preserve destinations and iOS/Android collapse', () => {
  const event = pushEvent({ ...base, notificationId: 'forged', key: 'forged', chatId: 'c', type: 'chat_message', messageId: 'm', unreadCount: 3, officeId: 'o', propertyId: 'p', requestId: 'r', subscriptionId: 's' }, null, 'real');
  const message = messageFor(event, 'token');
  assert.equal(message.data.notificationId, 'real');
  assert.equal(message.data.unreadCount, '3');
  assert.ok(Object.values(message.data).every(value => typeof value === 'string'));
  assert.equal(message.apns.headers['apns-collapse-id'], message.android.collapseKey);
  assert.equal(message.apns.payload.aps.sound, 'default');
  assert.equal(message.apns.headers['apns-push-type'], 'alert');
  assert.equal(permanentErrors.has('messaging/invalid-argument'), false);
  assert.equal(messageFor(pushEvent({ ...base, message: undefined, body: 'body' }, null, 'n'), 't').notification.body, 'body');
});
