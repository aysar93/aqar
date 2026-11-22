'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { resolveBookingRecipients } = require('./booking_policy');

test('booking recipient matrix: payment_review targets reviewers without general admins', () => {
  const b = { customerId: 'cust_1', ownerId: 'owner_1', status: 'payment_review' };
  const reviewers = ['fin_1', 'fin_2'];
  const admins = ['admin_1', 'admin_2'];

  const recipients = resolveBookingRecipients(b, { reviewers, admins });
  assert.equal(recipients.length, 4); // cust_1, owner_1, fin_1, fin_2
  assert.deepEqual(recipients.sort(), ['cust_1', 'fin_1', 'fin_2', 'owner_1'].sort());
  assert.equal(recipients.includes('admin_1'), false, 'General admin 1 should not receive payment_review notification');
  assert.equal(recipients.includes('admin_2'), false, 'General admin 2 should not receive payment_review notification');
});

test('booking recipient matrix: confirmed targets customer and owner only, avoiding all reviewers', () => {
  const b = { customerId: 'cust_1', ownerId: 'owner_1', status: 'confirmed' };
  const reviewers = ['fin_1', 'fin_2'];
  const admins = ['admin_1', 'admin_2'];

  const recipients = resolveBookingRecipients(b, { reviewers, admins });
  assert.equal(recipients.length, 2);
  assert.deepEqual(recipients.sort(), ['cust_1', 'owner_1'].sort());
  assert.equal(recipients.includes('fin_1'), false, 'Reviewer 1 should not receive confirmed notification');
  assert.equal(recipients.includes('fin_2'), false, 'Reviewer 2 should not receive confirmed notification');
  assert.equal(recipients.includes('admin_1'), false, 'Admin 1 should not receive confirmed notification');
});

test('booking recipient matrix: cancel_requested alerts both reviewers and admins for intervention', () => {
  const b = { customerId: 'cust_1', ownerId: 'owner_1', status: 'cancel_requested' };
  const reviewers = ['fin_1'];
  const admins = ['admin_1'];

  const recipients = resolveBookingRecipients(b, { reviewers, admins });
  assert.equal(recipients.length, 4);
  assert.deepEqual(recipients.sort(), ['admin_1', 'cust_1', 'fin_1', 'owner_1'].sort());
});

test('booking recipient matrix: cancelled alerts reviewers only when refundStatus is pending', () => {
  const reviewers = ['fin_1'];
  const admins = ['admin_1'];

  // 1. With pending refund
  const bRefund = { customerId: 'cust_1', ownerId: 'owner_1', status: 'cancelled', refundStatus: 'pending' };
  const recipientsRefund = resolveBookingRecipients(bRefund, { reviewers, admins });
  assert.equal(recipientsRefund.length, 3);
  assert.deepEqual(recipientsRefund.sort(), ['cust_1', 'fin_1', 'owner_1'].sort());

  // 2. Without refund (none)
  const bNoRefund = { customerId: 'cust_1', ownerId: 'owner_1', status: 'cancelled', refundStatus: 'none' };
  const recipientsNoRefund = resolveBookingRecipients(bNoRefund, { reviewers, admins });
  assert.equal(recipientsNoRefund.length, 2);
  assert.deepEqual(recipientsNoRefund.sort(), ['cust_1', 'owner_1'].sort());
});

test('booking recipient matrix: routine states (held, requested, expired, rejected) alert only customer and owner', () => {
  const reviewers = ['fin_1'];
  const admins = ['admin_1'];

  for (const status of ['requested', 'held', 'rejected', 'expired', 'payment_rejected', 'arrived', 'completed']) {
    const recipients = resolveBookingRecipients({ customerId: 'cust_1', ownerId: 'owner_1', status }, { reviewers, admins });
    assert.deepEqual(recipients.sort(), ['cust_1', 'owner_1'].sort(), `Failed for status ${status}`);
  }
});

test('booking recipient matrix: dedupes identical UIDs and handles missing options gracefully', () => {
  // If owner is also customer (edge case), no duplicate
  const b = { customerId: 'same_user', ownerId: 'same_user', status: 'payment_review' };
  const recipients = resolveBookingRecipients(b, { reviewers: ['fin_1', 'fin_1'] });
  assert.equal(recipients.length, 2);
  assert.deepEqual(recipients.sort(), ['fin_1', 'same_user'].sort());

  // If options omitted
  const noOpts = resolveBookingRecipients({ customerId: 'c', ownerId: 'o', status: 'payment_review' });
  assert.deepEqual(noOpts.sort(), ['c', 'o'].sort());
});
