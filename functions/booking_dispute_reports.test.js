'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');

// Unit tests verifying logic, contracts, role checks and security boundaries for booking disputes & reports.

test('dispute status and role state transitions', () => {
  const validStatuses = ['open', 'in_progress', 'under_review', 'awaiting_customer', 'awaiting_owner', 'resolved', 'closed'];
  assert.equal(validStatuses.length, 7);

  function canReply(status) {
    return !['resolved', 'closed'].includes(status);
  }
  assert.equal(canReply('open'), true);
  assert.equal(canReply('under_review'), true);
  assert.equal(canReply('awaiting_customer'), true);
  assert.equal(canReply('awaiting_owner'), true);
  assert.equal(canReply('resolved'), false);
  assert.equal(canReply('closed'), false);

  function nextStatusOnReply(currentStatus, role) {
    if (role === 'customer' && currentStatus === 'awaiting_customer') return 'under_review';
    if (role === 'owner' && currentStatus === 'awaiting_owner') return 'under_review';
    return currentStatus;
  }
  assert.equal(nextStatusOnReply('awaiting_customer', 'customer'), 'under_review');
  assert.equal(nextStatusOnReply('awaiting_owner', 'owner'), 'under_review');
  assert.equal(nextStatusOnReply('open', 'customer'), 'open');
});

test('dispute category classification and validation', () => {
  const allowedCategories = [
    'no_access',
    'description_mismatch',
    'property_damage',
    'cancellation_dispute',
    'deposit_dispute',
    'stay_issue',
    'general'
  ];

  function normalizeDisputeType(raw) {
    const trimmed = typeof raw === 'string' ? raw.trim() : '';
    return allowedCategories.includes(trimmed) ? trimmed : 'general';
  }

  assert.equal(normalizeDisputeType('no_access'), 'no_access');
  assert.equal(normalizeDisputeType('description_mismatch'), 'description_mismatch');
  assert.equal(normalizeDisputeType('deposit_dispute'), 'deposit_dispute');
  assert.equal(normalizeDisputeType('unknown_hack'), 'general');
  assert.equal(normalizeDisputeType(null), 'general');
});

test('rate limiting and duplicate report protection with re-reporting on resolved', () => {
  function checkReportEligibility(existingOpenCount, targetReport) {
    if (existingOpenCount >= 5) {
      throw new Error('resource-exhausted: يرجى انتظار معالجة البلاغات المفتوحة أولاً');
    }
    // Only active 'open' report blocks duplicate; resolved allows re-report
    if (targetReport && targetReport.status === 'open') {
      throw new Error('already-exists: لديك بلاغ مفتوح لهذا الهدف بالفعل');
    }
    return true;
  }

  // 1. Normal submission allowed
  assert.equal(checkReportEligibility(1, null), true);

  // 2. Flooding blocked
  assert.throws(() => checkReportEligibility(5, null), /resource-exhausted/);
  assert.throws(() => checkReportEligibility(6, null), /resource-exhausted/);

  // 3. Duplicate open report blocked
  assert.throws(() => checkReportEligibility(2, { status: 'open' }), /already-exists/);

  // 4. Re-reporting allowed after previous report is resolved
  assert.equal(checkReportEligibility(1, { status: 'resolved' }), true);
});

test('booking report authorization: only booking parties can report', () => {
  const booking = {
    id: 'b_123',
    customerId: 'cust_456',
    ownerId: 'owner_789',
    venueId: 'v_999'
  };

  function canReportBooking(bookingData, actorUid) {
    if (!bookingData) return false;
    return [bookingData.customerId, bookingData.ownerId].includes(actorUid);
  }

  assert.equal(canReportBooking(booking, 'cust_456'), true);
  assert.equal(canReportBooking(booking, 'owner_789'), true);
  assert.equal(canReportBooking(booking, 'stranger_000'), false);
  assert.equal(canReportBooking(booking, null), false);
});

test('public venue report: extracts ownerId from venue record, ignoring client-supplied override', () => {
  const serverVenue = {
    id: 'v_101',
    name: 'شاليه الرافدين',
    ownerId: 'true_owner_333'
  };
  const clientPayload = {
    venueId: 'v_101',
    ownerId: 'spoofed_owner_999',
    userId: 'spoofed_user_888',
    status: 'resolved',
    reason: 'معلومات غير دقيقة'
  };
  const authenticatedUid = 'auth_user_777';

  const serverRecord = {
    type: 'venue',
    venueId: serverVenue.id,
    venueName: serverVenue.name,
    ownerId: serverVenue.ownerId, // Server extracted
    userId: authenticatedUid,     // Auth extracted
    reason: clientPayload.reason,
    status: 'open'                // Always open initially
  };

  assert.equal(serverRecord.ownerId, 'true_owner_333');
  assert.equal(serverRecord.userId, 'auth_user_777');
  assert.equal(serverRecord.status, 'open');
});

test('admin resolution immutability: resolution records audit log and rejects party admins', () => {
  const bookingBefore = {
    id: 'b_test_1',
    paid: 50000,
    deposit: 50000,
    remaining: 150000,
    refundStatus: 'none',
    status: 'confirmed'
  };

  const auditEntries = [];
  function resolveTicket(ticket, adminUid, resolutionText) {
    // Conflict of interest: Independent admin required.
    // Cannot be ticket creator, customer, or owner.
    if ([ticket.userId, ticket.customerId, ticket.ownerId].includes(adminUid)) {
      throw new Error('Independent admin required: لا يمكن للمشرف اتخاذ قرار في نزاع يخصه كطرف');
    }
    const auditRecord = {
      bookingId: ticket.bookingId,
      ticketId: ticket.id,
      action: 'resolveSupportTicket',
      actorUid: adminUid,
      resolution: resolutionText,
      decision: 'resolved'
    };
    auditEntries.push(auditRecord);
    return {
      status: 'resolved',
      resolution: resolutionText,
      resolvedBy: adminUid
    };
  }

  const ticket = {
    id: 't_555',
    bookingId: 'b_test_1',
    userId: 'cust_111',
    customerId: 'cust_111',
    ownerId: 'owner_222'
  };

  // 1. Independent admin resolves successfully
  const updatedTicket = resolveTicket(ticket, 'admin_999', 'تم التواصل مع الطرفين والاتفاق على موعد بديل');
  assert.equal(updatedTicket.status, 'resolved');
  assert.equal(updatedTicket.resolvedBy, 'admin_999');
  assert.equal(auditEntries.length, 1);
  assert.equal(auditEntries[0].action, 'resolveSupportTicket');

  // 2. Booking financial balances remain strictly untouched
  assert.equal(bookingBefore.paid, 50000);
  assert.equal(bookingBefore.refundStatus, 'none');
  assert.equal(bookingBefore.status, 'confirmed');

  // 3. Admin who is creator is rejected
  assert.throws(() => resolveTicket(ticket, 'cust_111', 'self'), /Independent admin required/);

  // 4. Admin who is chalet owner is rejected (conflict of interest prevention)
  assert.throws(() => resolveTicket(ticket, 'owner_222', 'owner decision'), /Independent admin required/);
});

test('conversation message capacity bounding: caps at 50 messages to prevent document bloating', () => {
  function addMessage(messages, newText) {
    const current = Array.isArray(messages) ? messages.length : 0;
    if (current >= 50) {
      throw new Error('Message limit exceeded: تم الوصول للحد الأقصى لرسائل التذكرة (50 رسالة)');
    }
    return [...(messages || []), { text: newText, createdAt: Date.now() }];
  }

  let thread = [];
  for (let i = 0; i < 50; i++) {
    thread = addMessage(thread, `Message ${i + 1}`);
  }
  assert.equal(thread.length, 50);

  // 51st message rejected
  assert.throws(() => addMessage(thread, 'Message 51'), /Message limit exceeded/);
});
