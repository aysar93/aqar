const crypto = require('node:crypto');
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const validId = value => typeof value === 'string' && value.length > 0 && value.length <= 128 && !value.includes('/');

function pushEvent(after, before, notificationId) {
  if (!after || after.pushTransport !== 'fcm_v1' || after.deliveryType === 'internal' || !validId(after.userId) || after.userId === 'all') return null;
  if (after.type === 'chat_message') {
    if (!validId(after.chatId) || !validId(after.messageId) || before?.messageId === after.messageId) return null;
  } else if (before) return null;
  const identity = after.type === 'chat_message'
    ? ['chat', after.chatId, after.messageId, after.userId]
    : after.type === 'comment' && validId(after.commentId)
      ? ['comment', after.propertyId, after.commentId, after.userId]
      : after.type === 'reply' && validId(after.replyId)
        ? ['reply', after.propertyId, after.commentId, after.replyId, after.userId]
        : ['notification', notificationId, after.userId];
  return { ...after, key: hash(JSON.stringify(identity)), notificationId };
}

function messageFor(event, token) {
  const data = { notificationId: event.notificationId, userId: event.userId };
  for (const key of ['type', 'propertyId', 'officeId', 'chatId', 'messageId', 'commentId', 'replyId', 'requestId', 'subscriptionId', 'unreadCount']) {
    if (event[key] !== undefined && event[key] !== null) data[key] = String(event[key]).slice(0, 128);
  }
  const collapse = event.type === 'chat_message' ? hash(`chat:${event.chatId}`).slice(0, 32) : event.key.slice(0, 32);
  return {
    token, data,
    notification: { title: String(event.title || 'عقارات الأنبار').slice(0, 120), body: String(event.message || event.body || '').slice(0, 500) },
    android: { priority: 'high', collapseKey: collapse, notification: { sound: 'default', tag: collapse } },
    apns: { headers: { 'apns-push-type': 'alert', 'apns-priority': '10', 'apns-collapse-id': collapse }, payload: { aps: { sound: 'default' } } },
  };
}

const permanentErrors = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);
module.exports = { hash, validId, pushEvent, messageFor, permanentErrors };
