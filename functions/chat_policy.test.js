const test = require('node:test');
const assert = require('node:assert/strict');
const { canDeleteMessage, isOfficeOpen } = require('./chat_policy');
const now = Date.parse('2026-10-02T12:00:00Z');
const message = (age, extras = {}) => ({ senderId: 'owner', senderType: 'user', createdAt: { toMillis: () => now - age }, ...extras });
test('delete window uses server time and rejects foreign, old, missing and future timestamps', () => {
  const check = (m, uid = 'owner', preferences = {}) => canDeleteMessage({ message: m, uid, admin: false, now, preferences });
  assert.equal(check(message(3600000)), true);
  assert.equal(check(message(24 * 3600000)), false);
  assert.equal(check(message(-1000)), false);
  assert.equal(check({ senderId: 'owner', senderType: 'user' }), false);
  assert.equal(check(message(1000), 'other'), false);
  assert.equal(check(message(1000, { senderType: 'admin', authorUid: 'owner' })), false);
  assert.equal(check(message(2 * 3600000), 'owner', { deleteHours: 1 }), false);
  assert.equal(check(message(25 * 3600000), 'owner', { deleteHours: -1 }), false);
});
test('admin moderation is independent of sender window', () => {
  assert.equal(canDeleteMessage({ message: message(300 * 3600000), uid: 'admin', admin: true, now }), true);
});
test('business hours follow Baghdad timezone, boundaries and weekdays', () => {
  const p = { hoursEnabled: true, workDays: [5], openingMinute: 540, closingMinute: 1080 };
  assert.equal(isOfficeOpen(p, new Date('2026-10-02T06:00:00Z')), true);
  assert.equal(isOfficeOpen(p, new Date('2026-10-02T05:59:59Z')), false);
  assert.equal(isOfficeOpen(p, new Date('2026-10-02T15:00:00Z')), false);
  assert.equal(isOfficeOpen(p, new Date('2026-10-03T09:00:00Z')), false);
});
test('overnight hours continue into the next day of a scheduled shift', () => {
  const p = { hoursEnabled: true, workDays: [5], openingMinute: 1320, closingMinute: 120 };
  assert.equal(isOfficeOpen(p, new Date('2026-10-02T20:00:00Z')), true);
  assert.equal(isOfficeOpen(p, new Date('2026-10-02T22:00:00Z')), true);
  assert.equal(isOfficeOpen(p, new Date('2026-10-02T23:00:00Z')), false);
});
