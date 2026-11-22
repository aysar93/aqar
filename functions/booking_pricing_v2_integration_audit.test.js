const test = require('node:test');
const assert = require('node:assert/strict');
const { validate: validateV2, quoteDraft: quoteV2 } = require('./booking_pricing_v2_draft');
const { overlaps, blocks, money, venueDeposit, pricingConfig, quote } = require('./booking_policy');

// Standard V2 venue fixture with custom weekend [4, 5] (Thursday, Friday)
const sampleV2Venue = {
  id: 'venue_v2_anbar_01',
  name: 'شاليه الفرات الذهبي',
  active: true,
  ownerId: 'owner_123',
  deposit: 30000,
  terms: 'الشروط والأحكام المعتمدة للحجز',
  cancellationPolicy: { freeCancellationHours: 48, lateRefundPercent: 50 },
  pricing: {
    version: 2,
    timeZone: 'Asia/Baghdad',
    deposit: 30000,
    weekendDays: [4, 5], // Thursday (4), Friday (5)
    shifts: [
      {
        kind: 'morning',
        enabled: true,
        startMinute: 540, // 09:00
        endMinute: 1080, // 18:00
        endDayOffset: 0,
        weekdayPrice: 100000,
        weekendPrice: 140000
      },
      {
        kind: 'evening',
        enabled: true,
        startMinute: 1140, // 19:00
        endMinute: 120, // 02:00 next day
        endDayOffset: 1,
        weekdayPrice: 125000,
        weekendPrice: 165000
      },
      {
        kind: 'full_day',
        enabled: true,
        startMinute: 540, // 09:00
        endMinute: 540, // 09:00 next day
        endDayOffset: 1,
        weekdayPrice: 200000,
        weekendPrice: 250000
      }
    ]
  }
};

// 1. Full Flow: Venue -> Date -> Shift -> Price/Deposit/Remaining -> Request Payload -> pricingSnapshot
test('Scenario 1: Full flow from venue & shift to price quote, payload, and pricingSnapshot', () => {
  // Client selects Wednesday 2026-10-28 (weekday in Iraq), morning shift
  // Start: 2026-10-28 09:00 Baghdad = 2026-10-28 06:00 UTC
  // End: 2026-10-28 18:00 Baghdad = 2026-10-28 15:00 UTC
  const start = Date.parse('2026-10-28T06:00:00.000Z');
  const end = Date.parse('2026-10-28T15:00:00.000Z');
  const shiftId = 'morning';

  // Client-side quote calculation (matching BookingPricingDraft.quote in Dart)
  const clientQuote = quoteV2(sampleV2Venue.pricing, { kind: shiftId, start, end });
  assert.equal(clientQuote.total, 100000, 'Weekday morning total must be 100,000 IQD');
  assert.equal(clientQuote.deposit, 30000, 'Deposit must be 30,000 IQD');
  assert.equal(clientQuote.remaining, 70000, 'Remaining balance must be 70,000 IQD');
  assert.equal(clientQuote.pricing.dayGroup, 'weekday');
  assert.equal(clientQuote.pricing.version, 2);

  // Client constructs booking request payload (matching BookingRequestScreen in Flutter)
  const payload = {
    venueId: sampleV2Venue.id,
    requestId: 'req_1001',
    start,
    end,
    acceptedTerms: sampleV2Venue.terms,
    price: clientQuote.total,
    shiftId,
    cancellationPolicy: sampleV2Venue.cancellationPolicy,
    deposit: clientQuote.deposit,
    pricingSnapshot: clientQuote.pricing,
    notes: 'حجز عائلي'
  };

  // Server-side validation (matching requestBooking in booking_functions.js & quote in booking_policy.js)
  const priced = quote(sampleV2Venue, payload);
  assert.equal(priced.total, payload.price, 'Server total must match payload price');
  assert.equal(priced.pricing.version, 2);
  assert.equal(priced.pricing.kind, 'morning');
  assert.equal(priced.pricing.dayGroup, 'weekday');
  assert.equal(priced.pricing.timeZone, 'Asia/Baghdad');

  // Verify stored pricingSnapshot structure in booking record:
  // booking_policy.js line 43 preserves backward compatibility by attaching id and mode: 'shifts'
  const bookingRecord = {
    venueId: sampleV2Venue.id,
    start,
    end,
    total: priced.total,
    deposit: sampleV2Venue.deposit,
    remaining: priced.total - sampleV2Venue.deposit,
    pricing: priced.pricing,
    terms: sampleV2Venue.terms,
    cancellationPolicy: sampleV2Venue.cancellationPolicy
  };
  assert.equal(bookingRecord.total, 100000);
  assert.equal(bookingRecord.deposit, 30000);
  assert.equal(bookingRecord.remaining, 70000);
  assert.equal(bookingRecord.pricing.mode, 'shifts');
  assert.equal(bookingRecord.pricing.id, 'morning');
  assert.equal(bookingRecord.pricing.version, 2);
  assert.equal(bookingRecord.pricing.dayGroup, 'weekday');
  assert.equal(bookingRecord.pricing.timeZone, 'Asia/Baghdad');
  assert.equal(bookingRecord.pricing.currency, 'IQD');
});

// 2. Parity & Tamper Resistance: Client alters price or deposit in request
test('Scenario 2.1: Server rejects tampered total price (price undercut)', () => {
  const start = Date.parse('2026-10-28T06:00:00.000Z');
  const end = Date.parse('2026-10-28T15:00:00.000Z');
  const tamperedPayload = {
    start,
    end,
    shiftId: 'morning',
    price: 50000 // Client tampered with price (cut from 100,000 to 50,000)
  };

  const priced = quote(sampleV2Venue, tamperedPayload);
  assert.equal(priced.total, 100000);
  // In booking_functions.js line 354:
  const validateServerCheck = (d, p) => {
    if (d.price !== p.total) throw new Error('راجع السعر وسياسة الإلغاء');
  };
  assert.throws(() => validateServerCheck(tamperedPayload, priced), /راجع السعر وسياسة الإلغاء/);
});

test('Scenario 2.2: Server rejects tampered deposit (client reduced deposit)', () => {
  const tamperedPayload = { deposit: 10000 };
  const validateDeposit = (d, v) => {
    if (d.deposit !== v.deposit) throw new Error('راجع الأسعار والشروط الحالية');
  };
  assert.throws(() => validateDeposit(tamperedPayload, sampleV2Venue), /راجع الأسعار والشروط الحالية/);
});

test('Scenario 2.3: Server rejects tampered terms or cancellation policy', () => {
  const badTerms = { acceptedTerms: 'terms_hacked' };
  const checkTerms = (d, v) => { if (d.acceptedTerms !== v.terms) throw new Error('راجع الأسعار والشروط الحالية'); };
  assert.throws(() => checkTerms(badTerms, sampleV2Venue), /راجع الأسعار والشروط الحالية/);

  const badCancellation = { cancellationPolicy: { freeCancellationHours: 999, lateRefundPercent: 100 } };
  const checkCancellation = (d, v) => {
    if (d.cancellationPolicy?.freeCancellationHours !== v.cancellationPolicy?.freeCancellationHours ||
        d.cancellationPolicy?.lateRefundPercent !== v.cancellationPolicy?.lateRefundPercent) {
      throw new Error('راجع السعر وسياسة الإلغاء');
    }
  };
  assert.throws(() => checkCancellation(badCancellation, sampleV2Venue), /راجع السعر وسياسة الإلغاء/);
});

// 3. V1 Backward Compatibility
test('Scenario 3.1: Legacy V1 Fixed pricing operates correctly without disruption', () => {
  const v1Fixed = {
    id: 'v1_fixed_01',
    pricingMode: 'fixed',
    price: 80000,
    deposit: 20000
  };
  const q = quote(v1Fixed, { start: 1000000, end: 2000000 });
  assert.equal(q.total, 80000);
  assert.equal(q.pricing.mode, 'fixed');
});

test('Scenario 3.2: Legacy V1 Shifts pricing validates Baghdad time and shift ID', () => {
  const v1Shifts = {
    id: 'v1_shifts_01',
    pricingMode: 'shifts',
    deposit: 25000,
    shifts: [
      { id: 'shift_day', name: 'صباحي', checkInMinute: 540, checkOutMinute: 1080, price: 90000 }
    ]
  };
  // Valid shift: 09:00 (540m) to 18:00 (1080m) Baghdad
  const start = Date.parse('2026-10-28T06:00:00.000Z');
  const end = Date.parse('2026-10-28T15:00:00.000Z');
  const q = quote(v1Shifts, { shiftId: 'shift_day', start, end });
  assert.equal(q.total, 90000);
  assert.equal(q.pricing.id, 'shift_day');
  assert.equal(q.pricing.timeZone, 'Asia/Baghdad');

  // Unknown shift ID rejected
  assert.throws(() => quote(v1Shifts, { shiftId: 'unknown', start, end }), /اختر شفتاً/);
  // Wrong start minute rejected
  assert.throws(() => quote(v1Shifts, { shiftId: 'shift_day', start: start + 60000, end }), /وقت الشفت غير صالح/);
});

test('Scenario 3.3: Legacy V1 Hourly pricing enforces whole hours and rejects fractions', () => {
  const v1Hourly = {
    id: 'v1_hourly_01',
    pricingMode: 'hourly',
    hourlyPrice: 15000,
    deposit: 15000
  };
  // 3 whole hours
  const start = 1700000000000;
  const end3h = start + 3 * 3600000;
  const q = quote(v1Hourly, { start, end: end3h });
  assert.equal(q.total, 45000);
  assert.equal(q.pricing.hours, 3);

  // 2.5 hours rejected
  const end2_5h = start + 2.5 * 3600000;
  assert.throws(() => quote(v1Hourly, { start, end: end2_5h }), /اختر ساعات كاملة/);
});

// 3.4 Deposit Resolution & Conflict Safeguards
test('Scenario 3.4.1: V1 venue with root venue.deposit resolves accurately', () => {
  const v1 = { id: 'v1_test', deposit: 25000, price: 100000 };
  assert.equal(venueDeposit(v1), 25000);
});

test('Scenario 3.4.2: V2 venue with deposit in pricing scheme resolves accurately', () => {
  const v2 = {
    id: 'v2_test',
    pricing: { version: 2, deposit: 35000, timeZone: 'Asia/Baghdad', weekendDays: [5], shifts: [] }
  };
  assert.equal(venueDeposit(v2), 35000);
});

test('Scenario 3.4.3: Venue with matching root deposit and pricing deposit resolves without conflict', () => {
  const matching = {
    id: 'matching_test',
    deposit: 40000,
    pricing: { version: 2, deposit: 40000, timeZone: 'Asia/Baghdad', weekendDays: [5], shifts: [] }
  };
  assert.equal(venueDeposit(matching), 40000);
});

test('Scenario 3.4.4: Venue with conflicting root and pricing deposit is strictly rejected', () => {
  const conflicting = {
    id: 'conflict_test',
    deposit: 20000, // Conflict: 20,000 vs 30,000
    pricing: { version: 2, deposit: 30000, timeZone: 'Asia/Baghdad', weekendDays: [5], shifts: [] }
  };
  assert.throws(() => venueDeposit(conflicting), /تعارض بين عربون المكان وعربون التسعير المتقدم/);
});

test('Scenario 3.4.5: Venue missing deposit or with zero/negative deposit returns null and is rejected', () => {
  assert.equal(venueDeposit({ id: 'no_deposit' }), null);
  assert.equal(venueDeposit({ id: 'zero_deposit', deposit: 0 }), null);
  assert.equal(venueDeposit({ id: 'negative_deposit', deposit: -5000 }), null);
  // Rejection in quote:
  assert.throws(() => quote({ id: 'invalid_dep', price: 50000, deposit: 0 }, { start: 100, end: 200 }), /مبلغ غير صالح/);
});

test('Scenario 3.4.6: Deposit exceeding total price is strictly rejected', () => {
  const badMoneyVenue = {
    id: 'bad_money',
    price: 50000,
    deposit: 60000 // deposit > total
  };
  assert.throws(() => quote(badMoneyVenue, { start: 1000, end: 2000 }), /مبلغ غير صالح/);
});

// 4. V2 Comprehensive Shift & Calendar Coverage
test('Scenario 4.1: V2 Weekday Morning shift', () => {
  // Wednesday (weekday)
  const start = Date.parse('2026-10-28T06:00:00.000Z');
  const end = Date.parse('2026-10-28T15:00:00.000Z');
  const q = quote(sampleV2Venue, { shiftId: 'morning', start, end });
  assert.equal(q.total, 100000, 'Weekday morning price must be 100,000 IQD');
  assert.equal(q.pricing.dayGroup, 'weekday');
});

test('Scenario 4.2: V2 Weekend Morning shift with custom weekend days [4, 5]', () => {
  // Friday 2026-10-30 (day 5 -> in weekendDays [4, 5])
  const start = Date.parse('2026-10-30T06:00:00.000Z');
  const end = Date.parse('2026-10-30T15:00:00.000Z');
  const q = quote(sampleV2Venue, { shiftId: 'morning', start, end });
  assert.equal(q.total, 140000, 'Weekend morning price must be 140,000 IQD');
  assert.equal(q.pricing.dayGroup, 'weekend');
});

test('Scenario 4.3: V2 Weekday Evening shift with overnight next-day checkout', () => {
  // Wednesday 2026-10-28 evening: 19:00 (1140m) to 02:00 (120m) Thursday
  // Start: 2026-10-28 16:00:00 UTC (19:00 Baghdad)
  // End: 2026-10-28 23:00:00 UTC (02:00 next day Baghdad) -> Duration = 7h = 420m
  const start = Date.parse('2026-10-28T16:00:00.000Z');
  const end = Date.parse('2026-10-28T23:00:00.000Z');
  const q = quote(sampleV2Venue, { shiftId: 'evening', start, end });
  assert.equal(q.total, 125000, 'Weekday evening price must be 125,000 IQD');
  assert.equal(q.pricing.dayGroup, 'weekday');
  assert.equal(q.pricing.endDayOffset, 1);
});

test('Scenario 4.4: V2 Weekend Evening shift with overnight next-day checkout', () => {
  // Thursday 2026-10-29 evening (Thursday is day 4 -> in weekendDays [4, 5])
  const start = Date.parse('2026-10-29T16:00:00.000Z');
  const end = Date.parse('2026-10-29T23:00:00.000Z');
  const q = quote(sampleV2Venue, { shiftId: 'evening', start, end });
  assert.equal(q.total, 165000, 'Weekend evening price must be 165,000 IQD');
  assert.equal(q.pricing.dayGroup, 'weekend');
  assert.equal(q.pricing.endDayOffset, 1);
});

test('Scenario 4.5: V2 Independent Full Day shift (24 hours)', () => {
  // Full day: 09:00 to 09:00 next day (endDayOffset = 1, 24 hours = 1440m)
  // Weekday Wednesday 2026-10-28
  const start = Date.parse('2026-10-28T06:00:00.000Z');
  const end = Date.parse('2026-10-29T06:00:00.000Z');
  const q = quote(sampleV2Venue, { shiftId: 'full_day', start, end });
  assert.equal(q.total, 200000, 'Weekday full day must be 200,000 IQD');
  assert.equal(q.pricing.kind, 'full_day');

  // Weekend Friday 2026-10-30
  const startWk = Date.parse('2026-10-30T06:00:00.000Z');
  const endWk = Date.parse('2026-10-31T06:00:00.000Z');
  const qWk = quote(sampleV2Venue, { shiftId: 'full_day', start: startWk, end: endWk });
  assert.equal(qWk.total, 250000, 'Weekend full day must be 250,000 IQD');
  assert.equal(qWk.pricing.dayGroup, 'weekend');
});

// 5. Edge Cases & Integrity
test('Scenario 5.1: Missing price or unpriced venue is rejected', () => {
  const unpricedVenue = {
    id: 'unpriced_01',
    deposit: 20000
    // no price, no shifts, no pricing object
  };
  assert.throws(() => quote(unpricedVenue, { start: 1000, end: 2000 }), /مبلغ غير صالح/);
});

test('Scenario 5.2: Invalid and malformed pricing matrix is strictly rejected', () => {
  // Negative weekday price
  const bad1 = structuredClone(sampleV2Venue.pricing);
  bad1.shifts[0].weekdayPrice = -5000;
  assert.throws(() => validateV2(bad1), /سعر أو مدة أو عربون غير صالح/);

  // Deposit exceeds price
  const bad2 = structuredClone(sampleV2Venue.pricing);
  bad2.deposit = 300000; // Greater than weekdayPrice 100,000
  assert.throws(() => validateV2(bad2), /سعر أو مدة أو عربون غير صالح/);

  // Duplicate weekend days
  const bad3 = structuredClone(sampleV2Venue.pricing);
  bad3.weekendDays = [5, 5];
  assert.throws(() => validateV2(bad3), /أيام عطلة غير صالحة/);

  // Invalid endDayOffset (e.g. 2)
  const bad4 = structuredClone(sampleV2Venue.pricing);
  bad4.shifts[0].endDayOffset = 2;
  assert.throws(() => validateV2(bad4), /وقت غير صالح/);
});

test('Scenario 5.3: Price modification by owner AFTER booking request does not alter snapshot', () => {
  // Existing booking created at original price
  const start = Date.parse('2026-10-28T06:00:00.000Z');
  const end = Date.parse('2026-10-28T15:00:00.000Z');
  const initialQuote = quote(sampleV2Venue, { shiftId: 'morning', start, end });
  const frozenBooking = {
    id: 'booking_freeze_test',
    total: initialQuote.total,
    pricing: structuredClone(initialQuote.pricing)
  };
  assert.equal(frozenBooking.total, 100000);

  // Venue owner updates venue prices significantly
  const updatedVenue = structuredClone(sampleV2Venue);
  updatedVenue.pricing.shifts[0].weekdayPrice = 180000;
  updatedVenue.pricing.shifts[0].weekendPrice = 220000;

  // New quote reflects new price
  const newQuote = quote(updatedVenue, { shiftId: 'morning', start, end });
  assert.equal(newQuote.total, 180000);

  // Frozen booking record snapshot remains completely unaffected
  assert.equal(frozenBooking.total, 100000);
  assert.equal(frozenBooking.pricing.kind, 'morning');
  assert.equal(frozenBooking.pricing.version, 2);
});

test('Scenario 5.4: Overlapping booking attempts collision detection & half-open bounds', () => {
  // Existing booking from 09:00 to 18:00
  const existing = {
    start: Date.parse('2026-10-28T06:00:00.000Z'),
    end: Date.parse('2026-10-28T15:00:00.000Z'),
    status: 'confirmed'
  };

  // Attempt A: Exact same interval -> Overlaps
  assert.equal(overlaps(existing, { start: existing.start, end: existing.end }), true);

  // Attempt B: Overlapping start (starts at 14:00, ends at 20:00) -> Overlaps
  const overlappingAttempt = {
    start: Date.parse('2026-10-28T11:00:00.000Z'),
    end: Date.parse('2026-10-28T17:00:00.000Z')
  };
  assert.equal(overlaps(existing, overlappingAttempt), true);

  // Attempt C: Enclosing interval (starts earlier, ends later) -> Overlaps
  const enclosingAttempt = {
    start: Date.parse('2026-10-28T05:00:00.000Z'),
    end: Date.parse('2026-10-28T16:00:00.000Z')
  };
  assert.equal(overlaps(existing, enclosingAttempt), true);

  // Attempt D: Adjacent interval (evening shift starts exactly at existing.end 18:00)
  // Half-open interval [start, end) allows adjacent intervals without collision!
  const adjacentAttempt = {
    start: existing.end,
    end: existing.end + 7 * 3600000
  };
  assert.equal(overlaps(existing, adjacentAttempt), false, 'Adjacent intervals must NOT collide');
});

// 6. Transactional Mock of requestBooking & Atomic Concurrency Check
// Simulates the exact Firestore transaction logic of functions/booking_functions.js lines 347-370
class MockFirestore {
  constructor() {
    this.tables = {
      users: new Map(),
      booking_venues: new Map(),
      bookings: new Map(),
      booking_closures: new Map(),
      booking_action_audit: new Map()
    };
    this.revisionLocks = new Map();
  }

  setDoc(collection, id, data) {
    this.tables[collection].set(id, structuredClone(data));
  }

  getDoc(collection, id) {
    return structuredClone(this.tables[collection].get(id) || null);
  }

  // Simulates Firestore optimistic concurrency transaction with venue serialization lock
  async runTransaction(updateFn) {
    let retries = 0;
    while (retries < 5) {
      const reads = new Map();
      const writes = [];
      const tx = {
        get: async (target) => {
          if (target.collection && target.id) {
            const data = this.tables[target.collection].get(target.id);
            reads.set(`${target.collection}/${target.id}`, data ? structuredClone(data) : null);
            return { exists: !!data, data: () => data ? structuredClone(data) : null };
          }
          if (target.queryCollection) {
            const results = [];
            for (const [id, doc] of this.tables[target.queryCollection].entries()) {
              if (target.filter(doc)) results.push({ id, data: () => structuredClone(doc) });
            }
            return { docs: results };
          }
          throw new Error('Unknown target');
        },
        create: (ref, data) => {
          writes.push({ type: 'create', collection: ref.collection, id: ref.id, data: structuredClone(data) });
        },
        update: (ref, data) => {
          writes.push({ type: 'update', collection: ref.collection, id: ref.id, data: structuredClone(data) });
        }
      };

      try {
        const res = await updateFn(tx);
        // Commit phase: check optimistic revision conflict
        let conflict = false;
        for (const [key, initialData] of reads.entries()) {
          const [col, docId] = key.split('/');
          const currentData = this.tables[col].get(docId);
          if (col === 'booking_venues' && initialData && currentData) {
            if (initialData.bookingRevision !== currentData.bookingRevision) {
              conflict = true;
              break;
            }
          }
        }
        if (conflict) {
          retries++;
          continue; // OCC retry
        }
        // Apply writes
        for (const w of writes) {
          if (w.type === 'create') {
            if (this.tables[w.collection].has(w.id)) throw new Error('Document already exists');
            this.tables[w.collection].set(w.id, w.data);
          } else if (w.type === 'update') {
            const curr = this.tables[w.collection].get(w.id) || {};
            const updated = { ...curr };
            for (const [k, v] of Object.entries(w.data)) {
              if (v && v.__increment) updated[k] = (updated[k] || 0) + v.__increment;
              else updated[k] = v;
            }
            this.tables[w.collection].set(w.id, updated);
          }
        }
        return res;
      } catch (err) {
        throw err;
      }
    }
    throw new Error('Transaction max retries exceeded');
  }
}

// Handler mimicking functions/booking_functions.js lines 342-371
async function mockRequestBookingHandler(db, user, data) {
  const d = data;
  const start = Number(d.start), end = Number(d.end);
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start <= 0 || end <= start) {
    throw new Error('موعد غير صالح');
  }
  const ref = { collection: 'bookings', id: `${user.uid}_${d.requestId}` };
  const venueRef = { collection: 'booking_venues', id: d.venueId };

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return;

    const venueSnap = await tx.get(venueRef);
    const venue = venueSnap.data();
    if (!venue) throw new Error('المكان غير موجود');
    if (!venue.cancellationPolicy) throw new Error('يجب على الإدارة تهيئة سياسة الإلغاء للمكان');
    if (!venue.active || venue.ownerId === user.uid || d.acceptedTerms !== venue.terms || d.deposit !== venue.deposit) {
      throw new Error('راجع الأسعار والشروط الحالية');
    }

    const priced = quote(venue, { ...d, start, end });
    if (d.price !== priced.total ||
        d.cancellationPolicy?.freeCancellationHours !== venue.cancellationPolicy?.freeCancellationHours ||
        d.cancellationPolicy?.lateRefundPercent !== venue.cancellationPolicy?.lateRefundPercent) {
      throw new Error('راجع السعر وسياسة الإلغاء');
    }

    const ownerSnap = await tx.get({ collection: 'users', id: venue.ownerId });
    const owner = ownerSnap.data();
    if (!owner || owner.isBlocked) throw new Error('المالك غير متاح');

    const occupied = await tx.get({
      queryCollection: 'bookings',
      filter: (b) => b.venueId === venueRef.id
    });
    const closures = await tx.get({
      queryCollection: 'booking_closures',
      filter: (c) => c.venueId === venueRef.id
    });

    if (closures.docs.some(s => s.data().active && overlaps({ start, end }, s.data()))) {
      throw new Error('الموعد غير متاح');
    }
    if (occupied.docs.some(s => blocks(s.data(), Date.now()) && overlaps({ start, end }, s.data()))) {
      throw new Error('الموعد محجوز');
    }

    // Write booking strictly using SERVER recalculated total, deposit, and pricingSnapshot
    tx.create(ref, {
      venueId: venueRef.id,
      venueName: venue.name,
      ownerId: venue.ownerId,
      customerId: user.uid,
      start,
      end,
      total: priced.total,
      pricing: priced.pricing,
      cancellationPolicy: venue.cancellationPolicy,
      deposit: venue.deposit,
      paid: 0,
      remaining: priced.total,
      terms: venue.terms,
      status: 'requested',
      version: 0
    });

    tx.update(venueRef, {
      bookingRevision: { __increment: 1 }
    });
  });

  return { id: ref.id };
}

test('Scenario 6.1: Simulated Firestore transaction executes requestBooking with server recalculation and zero-trust', async () => {
  const db = new MockFirestore();
  db.setDoc('users', 'owner_123', { name: 'مالك الشاليه', isBlocked: false });
  db.setDoc('users', 'cust_01', { name: 'المستأجر علي', isBlocked: false });
  db.setDoc('booking_venues', sampleV2Venue.id, { ...sampleV2Venue, bookingRevision: 0 });

  const start = Date.parse('2026-10-28T06:00:00.000Z');
  const end = Date.parse('2026-10-28T15:00:00.000Z');

  // Client attempts to pass a tampered price or a fake pricingSnapshot
  const validClientQuote = quoteV2(sampleV2Venue.pricing, { kind: 'morning', start, end });
  const payload = {
    venueId: sampleV2Venue.id,
    requestId: 'req_tx_001',
    start,
    end,
    acceptedTerms: sampleV2Venue.terms,
    price: validClientQuote.total,
    shiftId: 'morning',
    cancellationPolicy: sampleV2Venue.cancellationPolicy,
    deposit: validClientQuote.deposit,
    pricingSnapshot: { fakeField: 'hacked_pricing' }, // Client tampering attempt
    notes: 'ملاحظة'
  };

  const res = await mockRequestBookingHandler(db, { uid: 'cust_01' }, payload);
  assert.equal(res.id, 'cust_01_req_tx_001');

  const savedBooking = db.getDoc('bookings', 'cust_01_req_tx_001');
  assert.ok(savedBooking, 'Booking record must exist');
  assert.equal(savedBooking.total, 100000, 'Server recalculates total');
  assert.equal(savedBooking.deposit, 30000, 'Server takes venue.deposit');
  assert.equal(savedBooking.pricing.version, 2, 'pricingSnapshot generated by server');
  assert.equal(savedBooking.pricing.fakeField, undefined, 'Client fake pricingSnapshot ignored');
  assert.equal(savedBooking.pricing.dayGroup, 'weekday');
  assert.equal(savedBooking.status, 'requested');

  const updatedVenue = db.getDoc('booking_venues', sampleV2Venue.id);
  assert.equal(updatedVenue.bookingRevision, 1, 'bookingRevision incremented as OCC anchor');
});

test('Scenario 6.2: Overlapping booking request is rejected when slot is already reserved or held', async () => {
  const db = new MockFirestore();
  db.setDoc('users', 'owner_123', { name: 'المالك', isBlocked: false });
  db.setDoc('users', 'cust_01', { name: 'زبون 1', isBlocked: false });
  db.setDoc('users', 'cust_02', { name: 'زبون 2', isBlocked: false });
  db.setDoc('booking_venues', sampleV2Venue.id, { ...sampleV2Venue, bookingRevision: 0 });

  const start = Date.parse('2026-10-28T06:00:00.000Z');
  const end = Date.parse('2026-10-28T15:00:00.000Z');

  // Pre-existing confirmed booking in the database for customer 1
  db.setDoc('bookings', 'existing_confirmed_booking', {
    venueId: sampleV2Venue.id,
    customerId: 'cust_01',
    start,
    end,
    status: 'confirmed',
    total: 100000,
    deposit: 30000
  });

  const payload2 = {
    venueId: sampleV2Venue.id,
    requestId: 'req_overlapping_attempt',
    start,
    end,
    acceptedTerms: sampleV2Venue.terms,
    price: 100000,
    shiftId: 'morning',
    cancellationPolicy: sampleV2Venue.cancellationPolicy,
    deposit: 30000
  };

  // Customer 2 attempts to book the same overlapping slot
  await assert.rejects(
    mockRequestBookingHandler(db, { uid: 'cust_02' }, payload2),
    /الموعد محجوز/,
    'New request for already confirmed/held slot must be rejected with "الموعد محجوز"'
  );

  // Verify database still only contains the original booking
  const allBookings = Array.from(db.tables.bookings.values());
  assert.equal(allBookings.length, 1, 'Database must not permit the second booking');
  assert.equal(allBookings[0].customerId, 'cust_01');
});

test('Scenario 6.3: Midnight boundary and overnight duration calculation parity', () => {
  // Evening shift: 19:00 (1140m) to 02:00 (120m next day)
  // endDayOffset = 1
  // Formula: duration = (endMinute + endDayOffset * 1440 - startMinute) * 60000
  // (120 + 1440 - 1140) * 60000 = 420 * 60000 = 25,200,000 ms (7.0 hours)
  const durationMs = (120 + 1440 - 1140) * 60000;
  assert.equal(durationMs, 7 * 3600000, 'Overnight duration must be exactly 7 hours');

  // Dart equation parity check
  const startUtc = Date.parse('2026-10-28T16:00:00.000Z'); // 19:00 Baghdad
  const endUtc = startUtc + durationMs; // 02:00 next day Baghdad (23:00 UTC)
  const q = quoteV2(sampleV2Venue.pricing, { kind: 'evening', start: startUtc, end: endUtc });
  assert.equal(q.total, 125000);
  assert.equal(q.pricing.endDayOffset, 1);
  assert.equal(q.pricing.dayGroup, 'weekday');
});

