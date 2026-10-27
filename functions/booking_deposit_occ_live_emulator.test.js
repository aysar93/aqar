const { test } = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185' ||
    process.env.FIREBASE_STORAGE_EMULATOR_HOST !== '127.0.0.1:9198' ||
    process.env.GCLOUD_PROJECT !== 'demo-aqar') {
  throw Error('Isolated demo emulators required');
}

if (!getApps().length) {
  initializeApp({ projectId: 'demo-aqar', storageBucket: 'demo-aqar.appspot.com' });
}

const db = getFirestore();
const f = require('./booking_functions');
const call = (name, uid, data) => f[name].run({ auth: { uid }, data });

test('Deposit Reconciliation and OCC Concurrency Live on Firestore Emulator', async (t) => {
  // Wipe before running to ensure completely fresh isolated state
  await fetch('http://127.0.0.1:8185/emulator/v1/projects/demo-aqar/databases/(default)/documents', { method: 'DELETE' });

  // Setup users
  for (const uid of ['admin_user', 'owner_user', 'cust_1', 'cust_2']) {
    await db.doc(`users/${uid}`).set({
      name: uid,
      phone: '07700000000',
      isAdmin: uid === 'admin_user',
      isBlocked: false,
    });
  }

  const cp = { freeCancellationHours: 24, lateRefundPercent: 20 };
  const start = Date.now() + 86400000 * 2;
  const end = start + 3600000 * 4;

  await t.test('1. V1 Venue creation and request with root deposit', async () => {
    const v1Payload = {
      ownerId: 'owner_user',
      name: 'V1 Venue Root Deposit',
      location: 'Anbar Ramadi',
      category: 'chalet',
      price: 150000,
      deposit: 30000,
      terms: 'V1 terms',
      cancellationPolicy: cp,
      active: true,
    };
    const res = await call('saveBookingVenue', 'admin_user', v1Payload);
    const venueSnap = (await db.doc(`booking_venues/${res.id}`).get()).data();
    assert.equal(venueSnap.deposit, 30000);

    // Customer requests with matching server quote
    const req = await call('requestBooking', 'cust_1', {
      venueId: res.id,
      requestId: 'v1_req_1',
      start,
      end,
      price: 150000,
      deposit: 30000,
      acceptedTerms: 'V1 terms',
      cancellationPolicy: cp,
    });
    const bookingSnap = (await db.doc(`bookings/${req.id}`).get()).data();
    assert.equal(bookingSnap.deposit, 30000);
    assert.equal(bookingSnap.status, 'requested');
  });

  await t.test('2. V2 Venue creation and request with pricing.deposit', async () => {
    const v2Payload = {
      ownerId: 'owner_user',
      name: 'V2 Venue Pricing Deposit',
      location: 'Anbar Fallujah',
      category: 'farm',
      price: 200000,
      pricing: {
        v: 2,
        mode: 'shift',
        basePrice: 200000,
        deposit: 50000,
        weekendPrice: 250000,
      },
      terms: 'V2 terms',
      cancellationPolicy: cp,
      active: true,
    };
    const res = await call('saveBookingVenue', 'admin_user', v2Payload);
    const venueSnap = (await db.doc(`booking_venues/${res.id}`).get()).data();
    assert.equal(venueSnap.deposit, 50000);

    // Customer requests with V2 deposit
    const req = await call('requestBooking', 'cust_1', {
      venueId: res.id,
      requestId: 'v2_req_1',
      start,
      end,
      price: 200000,
      deposit: 50000,
      acceptedTerms: 'V2 terms',
      cancellationPolicy: cp,
    });
    const bookingSnap = (await db.doc(`bookings/${req.id}`).get()).data();
    assert.equal(bookingSnap.deposit, 50000);
    assert.equal(bookingSnap.status, 'requested');
  });

  await t.test('3. Conflicting venue creation (v.deposit != v.pricing.deposit) is rejected', async () => {
    const conflictPayload = {
      ownerId: 'owner_user',
      name: 'Conflict Venue',
      location: 'Anbar',
      category: 'resort',
      price: 200000,
      deposit: 25000,
      pricing: {
        v: 2,
        mode: 'shift',
        basePrice: 200000,
        deposit: 50000, // Conflict: 25000 vs 50000
      },
      terms: 'terms',
      cancellationPolicy: cp,
      active: true,
    };
    await assert.rejects(
      call('saveBookingVenue', 'admin_user', conflictPayload),
      /سعر أو نوع أو عربون غير صالح/
    );
  });

  await t.test('4. Tampered client price or deposit in requestBooking is rejected by server recalculation', async () => {
    const vPayload = {
      ownerId: 'owner_user',
      name: 'Tamper Protection Venue',
      location: 'Anbar',
      category: 'hall',
      price: 300000,
      pricing: {
        v: 2,
        mode: 'shift',
        basePrice: 300000,
        deposit: 75000,
      },
      terms: 'terms',
      cancellationPolicy: cp,
      active: true,
    };
    const venue = await call('saveBookingVenue', 'admin_user', vPayload);

    // Client attempts to pay 1000 deposit instead of 75000
    await assert.rejects(
      call('requestBooking', 'cust_1', {
        venueId: venue.id,
        requestId: 'tamper_deposit',
        start,
        end,
        price: 300000,
        deposit: 1000,
        acceptedTerms: 'terms',
        cancellationPolicy: cp,
      }),
      /راجع الأسعار والشروط الحالية/
    );

    // Client attempts to alter total price to 50000 instead of 300000
    await assert.rejects(
      call('requestBooking', 'cust_1', {
        venueId: venue.id,
        requestId: 'tamper_price',
        start,
        end,
        price: 50000,
        deposit: 75000,
        acceptedTerms: 'terms',
        cancellationPolicy: cp,
      }),
      /راجع السعر وسياسة الإلغاء/
    );
  });

  await t.test('5. Overlapping approval lock: Owner approves cust_1, cust_2 cannot take slot', async () => {
    const vPayload = {
      ownerId: 'owner_user',
      name: 'OCC Serialization Venue',
      location: 'Anbar',
      category: 'chalet',
      price: 180000,
      deposit: 40000,
      terms: 'terms',
      cancellationPolicy: cp,
      active: true,
    };
    const venue = await call('saveBookingVenue', 'admin_user', vPayload);

    // Two concurrent requests for same slot
    const req1 = await call('requestBooking', 'cust_1', {
      venueId: venue.id,
      requestId: 'occ_req_1',
      start,
      end,
      price: 180000,
      deposit: 40000,
      acceptedTerms: 'terms',
      cancellationPolicy: cp,
    });
    const req2 = await call('requestBooking', 'cust_2', {
      venueId: venue.id,
      requestId: 'occ_req_2',
      start,
      end,
      price: 180000,
      deposit: 40000,
      acceptedTerms: 'terms',
      cancellationPolicy: cp,
    });

    // Owner approves req1 -> status becomes 'held'
    await call('actOnBooking', 'owner_user', {
      bookingId: req1.id,
      action: 'approve',
    });

    const b1 = (await db.doc(`bookings/${req1.id}`).get()).data();
    assert.equal(b1.status, 'held');
    assert.ok(b1.holdUntil > Date.now());

    // Owner attempts to approve req2 for overlapping time -> must fail with 'الموعد محجوز'
    await assert.rejects(
      call('actOnBooking', 'owner_user', {
        bookingId: req2.id,
        action: 'approve',
      }),
      /الموعد محجوز/
    );

    // New request for same slot while held must also fail with 'الموعد محجوز'
    await assert.rejects(
      call('requestBooking', 'cust_2', {
        venueId: venue.id,
        requestId: 'occ_req_3',
        start,
        end,
        price: 180000,
        deposit: 40000,
        acceptedTerms: 'terms',
        cancellationPolicy: cp,
      }),
      /الموعد محجوز/
    );
  });
});
