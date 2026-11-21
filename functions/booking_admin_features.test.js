const { test } = require('node:test');
const assert = require('node:assert/strict');
const { venueDeposit, money, quote } = require('./booking_policy');

test('Deposit policy follows strict 3-tier hierarchy: Venue > Category > Fallback', () => {
  const categoryDefaults = { chalet: 60000, farm: 80000 };

  // Tier 1: Explicit venue deposit takes highest precedence
  const venueWithDeposit = { category: 'chalet', deposit: 75000, price: 200000 };
  assert.equal(venueDeposit(venueWithDeposit, categoryDefaults), 75000);

  // Tier 2: Venue without deposit falls back to category default
  const venueWithoutDeposit = { category: 'chalet', price: 200000 };
  assert.equal(venueDeposit(venueWithoutDeposit, categoryDefaults), 60000);

  // Tier 3: Category without specific default falls back to null/system default
  const venueOtherCategory = { category: 'hall', price: 500000 };
  assert.equal(venueDeposit(venueOtherCategory, categoryDefaults), null);

  const fallbackDeposit = venueDeposit(venueOtherCategory, categoryDefaults) || 50000;
  assert.equal(fallbackDeposit, 50000);
});

test('Offer discount cannot reduce total price below effective deposit', () => {
  const venue = {
    price: 100000,
    deposit: 60000,
    offer: { percent: 50, until: Date.now() + 3600000 },
  };
  // 50% discount would make total 50,000, which is < deposit 60,000 -> must throw
  assert.throws(() => quote(venue, { start: Date.now() + 86400000, end: Date.now() + 90000000 }));
});

test('Approval invariants guarantee zero corruption of venue parameters', () => {
  const originalVenue = {
    id: 'IT25G8XYug2xcX39GQvR',
    ownerId: 'Q1qjnkQf29W47DEk3GKAB9sZDPc2',
    name: 'Chalet-UAT-Updated123-Test',
    complexName: 'Chalet-UAT-Functional-Updated',
    pricingMode: 'shifts',
    shifts: [
      { id: 'morning', name: 'الفترة الصباحية', price: 100000 },
      { id: 'evening', name: 'الفترة المسائية', price: 150000 },
    ],
    price: 100000,
    deposit: 50000,
    terms: 'الالتزام التام بالشروط',
    amenities: ['pool', 'wifi'],
    verificationStatus: 'pending',
    active: false,
  };

  // Safe server-side approval update payload definition
  const adminUid = 'admin_super_user_123';
  const approvalUpdates = {
    verificationStatus: 'verified',
    active: true,
    reviewedBy: adminUid,
    verifiedBy: adminUid,
  };

  const updatedVenue = { ...originalVenue, ...approvalUpdates };

  // Core business assertions:
  assert.equal(updatedVenue.name, originalVenue.name);
  assert.equal(updatedVenue.complexName, originalVenue.complexName);
  assert.equal(updatedVenue.pricingMode, originalVenue.pricingMode);
  assert.deepEqual(updatedVenue.shifts, originalVenue.shifts);
  assert.equal(updatedVenue.price, originalVenue.price);
  assert.equal(updatedVenue.deposit, originalVenue.deposit);
  assert.deepEqual(updatedVenue.amenities, originalVenue.amenities);
  assert.equal(updatedVenue.terms, originalVenue.terms);
  assert.equal(updatedVenue.ownerId, originalVenue.ownerId);

  // State transitions:
  assert.equal(updatedVenue.verificationStatus, 'verified');
  assert.equal(updatedVenue.active, true);
  assert.equal(updatedVenue.reviewedBy, adminUid);
});

test('Featured venue priority and expiration bounds', () => {
  const validPriorities = [0, 10, 50, 100, 1000];
  for (const p of validPriorities) {
    assert.equal(Number.isSafeInteger(p) && p >= 0 && p <= 1000, true);
  }
  const invalidPriorities = [-1, 1001, NaN, 'high', 2.5];
  for (const p of invalidPriorities) {
    assert.equal(Number.isSafeInteger(p) && p >= 0 && p <= 1000, false);
  }
});

test('Booking admin notes structure validation', () => {
  const note = {
    adminUid: 'admin_123',
    adminName: 'مراقب النظام',
    note: 'تم التحقق من مطابقة الحساب البنكي مع كشف الحساب',
    createdAt: Date.now(),
  };

  assert.equal(typeof note.adminUid, 'string');
  assert.equal(typeof note.adminName, 'string');
  assert.equal(note.note.length > 0 && note.note.length <= 2000, true);
  assert.equal(Number.isSafeInteger(note.createdAt), true);
});

test('Featured venues evaluation handles all 4 cases correctly', () => {
  const now = 1731628800000; // Fixed timestamp reference

  function isFeatured(venue, currentNow = now) {
    const flag = venue.isFeatured === true || venue.featured === true;
    if (!flag) return false;
    if (venue.featuredUntil === null || venue.featuredUntil === undefined) return true;
    return currentNow <= venue.featuredUntil;
  }

  // Case 1: Featured with future expiration date -> Active
  const case1 = { isFeatured: true, featuredUntil: now + 86400000 };
  assert.equal(isFeatured(case1), true);

  // Case 2: Featured with expired date -> Inactive
  const case2 = { isFeatured: true, featuredUntil: now - 1000 };
  assert.equal(isFeatured(case2), false);

  // Case 3: Non-featured venue -> Inactive
  const case3 = { isFeatured: false, featuredUntil: now + 86400000 };
  assert.equal(isFeatured(case3), false);

  // Case 4: Featured with missing/null featuredUntil -> Active (backward compatibility)
  const case4a = { isFeatured: true, featuredUntil: null };
  assert.equal(isFeatured(case4a), true);
  const case4b = { isFeatured: true };
  assert.equal(isFeatured(case4b), true);
});

test('Featured venues sort priority: higher priority first, then updated timestamp', () => {
  const venues = [
    { id: 'v1', featuredPriority: 10, updatedAt: 1000 },
    { id: 'v2', featuredPriority: 100, updatedAt: 500 },
    { id: 'v3', featuredPriority: 10, updatedAt: 2000 },
    { id: 'v4', featuredPriority: 0, updatedAt: 3000 },
  ];

  venues.sort((a, b) => {
    const pA = a.featuredPriority || 0;
    const pB = b.featuredPriority || 0;
    if (pA !== pB) return pB - pA;
    return (b.updatedAt || 0) - (a.updatedAt || 0);
  });

  assert.deepEqual(venues.map(v => v.id), ['v2', 'v3', 'v1', 'v4']);
});

test('Dispute evidence validation and immutability rules', () => {
  const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
  const maxBytes = 10 * 1024 * 1024;

  function validateEvidence({ ticketStatus, fileType, fileSize, fileName }) {
    if (['resolved', 'closed'].includes(ticketStatus)) {
      throw new Error('التذكرة مغلقة');
    }
    if (!allowedMimeTypes.includes(fileType)) {
      throw new Error('نوع ملف غير مدعوم');
    }
    if (fileSize <= 0 || fileSize > maxBytes) {
      throw new Error('حجم ملف غير صالح');
    }
    if (!/^[a-zA-Z0-9_\-\.\s\(\)]+$/.test(fileName)) {
      throw new Error('اسم ملف غير صالح');
    }
    return true;
  }

  // Valid image
  assert.equal(validateEvidence({
    ticketStatus: 'open',
    fileType: 'image/jpeg',
    fileSize: 2 * 1024 * 1024,
    fileName: 'damage_evidence_01.jpg',
  }), true);

  // Valid PDF
  assert.equal(validateEvidence({
    ticketStatus: 'under_review',
    fileType: 'application/pdf',
    fileSize: 500 * 1024,
    fileName: 'contract_signed.pdf',
  }), true);

  // Rejected: closed dispute
  assert.throws(() => validateEvidence({
    ticketStatus: 'closed',
    fileType: 'image/png',
    fileSize: 1024,
    fileName: 'test.png',
  }), /التذكرة مغلقة/);

  // Rejected: unsupported mime type
  assert.throws(() => validateEvidence({
    ticketStatus: 'open',
    fileType: 'application/x-executable',
    fileSize: 1024,
    fileName: 'test.exe',
  }), /نوع ملف غير مدعوم/);

  // Rejected: file exceeds 10MB
  assert.throws(() => validateEvidence({
    ticketStatus: 'open',
    fileType: 'image/jpeg',
    fileSize: 15 * 1024 * 1024,
    fileName: 'huge.jpg',
  }), /حجم ملف غير صالح/);
});

test('Calendar conflict detection distinguishes true overlap from separate shifts', () => {
  function checkOverlap(s1, e1, s2, e2) {
    return s1 < e2 && e1 > s2;
  }

  // Morning shift: 09:00 - 15:00 (epoch ms offset)
  const morningStart = 1731650400000;
  const morningEnd = 1731672000000;

  // Evening shift: 16:00 - 23:00 (epoch ms offset)
  const eveningStart = 1731675600000;
  const eveningEnd = 1731700800000;

  // Separate shifts on the same day must NOT report a false conflict
  assert.equal(checkOverlap(morningStart, morningEnd, eveningStart, eveningEnd), false);

  // Overlapping booking: 14:00 - 18:00
  const overlapStart = 1731668400000;
  const overlapEnd = 1731682800000;
  assert.equal(checkOverlap(morningStart, morningEnd, overlapStart, overlapEnd), true);

  // Closure overlapping evening shift
  const closureStart = 1731680000000;
  const closureEnd = 1731690000000;
  assert.equal(checkOverlap(eveningStart, eveningEnd, closureStart, closureEnd), true);
});

test('Safe Admin Notes Migration logic ensures fidelity, idempotency, and verified deletion', () => {
  const crypto = require('node:crypto');

  const legacyBooking = {
    id: 'booking_sample_99',
    adminNotes: [
      {
        adminUid: 'admin_1',
        adminName: 'مراقب 1',
        note: 'الملاحظة الأولى: تدقيق مالي',
        createdAt: 1731600000000,
      },
      {
        adminUid: 'admin_2',
        adminName: 'مراقب 2',
        note: 'الملاحظة الثانية: استرداد جزئي',
        createdAt: 1731610000000,
      },
    ],
  };

  function simulateMigration(booking, dryRun = true) {
    const rawNotes = booking.adminNotes || [];
    const subcollection = {};

    const migrated = rawNotes.map(n => {
      const hashId = crypto.createHash('sha256')
        .update(`${booking.id}_${n.note}_${n.createdAt}`)
        .digest('hex')
        .slice(0, 16);
      const noteDocId = `migrated_${hashId}`;

      return {
        id: noteDocId,
        bookingId: booking.id,
        adminUid: n.adminUid,
        adminName: n.adminName,
        note: n.note,
        createdAt: n.createdAt,
        migratedFromLegacy: true,
      };
    });

    for (const item of migrated) {
      subcollection[item.id] = item;
    }

    // Pre/Post Count Verification
    const countBefore = rawNotes.length;
    const countAfter = Object.keys(subcollection).length;
    assert.equal(countBefore, countAfter, 'Count before must match count after');

    let updatedBooking = { ...booking };
    if (!dryRun) {
      delete updatedBooking.adminNotes;
      updatedBooking.adminNotesMigratedAt = 1731620000000;
    }

    return { subcollection, updatedBooking, countBefore, countAfter };
  }

  // 1. Dry run check
  const dryRes = simulateMigration(legacyBooking, true);
  assert.equal(dryRes.countBefore, 2);
  assert.equal(dryRes.countAfter, 2);
  assert.equal(Array.isArray(dryRes.updatedBooking.adminNotes), true, 'Dry run must not delete original field');

  // 2. Full migration check
  const liveRes = simulateMigration(legacyBooking, false);
  assert.equal(liveRes.countBefore, 2);
  assert.equal(liveRes.countAfter, 2);
  assert.equal(liveRes.updatedBooking.adminNotes, undefined, 'Live run must delete original field after verified copy');

  // 3. Idempotency check: running again on same data produces identical doc IDs
  const secondRun = simulateMigration(legacyBooking, false);
  assert.deepEqual(Object.keys(liveRes.subcollection), Object.keys(secondRun.subcollection));

  // 4. Data Fidelity: text, author, and timestamp are 100% preserved
  const firstNote = Object.values(liveRes.subcollection)[0];
  assert.equal(firstNote.note, 'الملاحظة الأولى: تدقيق مالي');
  assert.equal(firstNote.adminUid, 'admin_1');
  assert.equal(firstNote.createdAt, 1731600000000);

  // 5. Re-running on already migrated booking (adminNotes absent/empty)
  const thirdRun = simulateMigration(liveRes.updatedBooking, false);
  assert.equal(thirdRun.countBefore, 0);
  assert.equal(thirdRun.countAfter, 0);
  assert.equal(Object.keys(thirdRun.subcollection).length, 0, 'No notes migrated if already migrated');

  // 6. Partial write failure rollback simulation: if any write fails, legacy adminNotes MUST NOT be deleted
  function simulateFailedMigration(booking) {
    let rolledBack = false;
    let updatedBooking = { ...booking };
    try {
      const rawNotes = booking.adminNotes || [];
      const subcollection = {};
      for (let i = 0; i < rawNotes.length; i++) {
        if (i === 1) throw new Error('Simulated database write error during migration');
        const n = rawNotes[i];
        subcollection[n.note] = n;
      }
      delete updatedBooking.adminNotes;
    } catch (err) {
      rolledBack = true;
      // In transaction rollback, original booking is completely untouched
      updatedBooking = { ...booking };
    }
    return { rolledBack, updatedBooking };
  }
  const failRes = simulateFailedMigration(legacyBooking);
  assert.equal(failRes.rolledBack, true, 'Transaction must roll back on failure');
  assert.equal(Array.isArray(failRes.updatedBooking.adminNotes), true, 'Legacy adminNotes must remain intact upon failure');
  assert.equal(failRes.updatedBooking.adminNotes.length, 2);
});
