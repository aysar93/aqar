'use strict';

const fs = require('fs');
const path = require('path');

const configFile = path.join(process.env.USERPROFILE, '.config/configstore/firebase-tools.json');
const gToken = JSON.parse(fs.readFileSync(configFile)).tokens.access_token;
const servicesJson = JSON.parse(fs.readFileSync(path.join(__dirname, '../../android/app/src/bookingsStaging/google-services.json')));
const apiKey = servicesJson.client[0].api_key[0].current_key;
const PROJECT = 'aqar-bookings-test-20261009';
const BASE_URL = `https://us-central1-${PROJECT}.cloudfunctions.net`;

async function callFunction(name, idToken, data) {
  const res = await fetch(`${BASE_URL}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${idToken}`
    },
    body: JSON.stringify({ data })
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch (_) { json = text; }
  return { status: res.status, body: json };
}

async function createAuthUser(prefix) {
  const email = `${prefix}_${Date.now()}@example.test`;
  const authRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'Password123!', returnSecureToken: true })
  }).then(r => r.json());
  return { uid: authRes.localId, idToken: authRes.idToken, email };
}

async function setFirestoreUser(uid, fields) {
  const bodyFields = {};
  for (const [k, v] of Object.entries(fields)) {
    if (typeof v === 'string') bodyFields[k] = { stringValue: v };
    else if (typeof v === 'boolean') bodyFields[k] = { booleanValue: v };
    else if (typeof v === 'number') bodyFields[k] = { integerValue: String(v) };
  }
  await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${gToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ fields: bodyFields })
  });
}

async function deleteFirestoreDoc(collection, id) {
  try {
    await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/${collection}/${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${gToken}` }
    });
  } catch (_) {}
}

async function runStagingAcceptance() {
  console.log(`\n================================================================`);
  console.log(`RUNNING LIVE STAGING ACCEPTANCE SUITE ON: ${PROJECT}`);
  console.log(`================================================================\n`);

  const createdVenues = [];
  const createdBookings = [];

  try {
    // 1. Setup Identities
    console.log('[1/7] Creating synthetic test identities on Staging Auth...');
    const admin = await createAuthUser('stage_admin');
    await setFirestoreUser(admin.uid, { name: 'Staging Admin', phone: '07700000000', isAdmin: true, isBlocked: false });
    
    const owner = await createAuthUser('stage_owner');
    await setFirestoreUser(owner.uid, { name: 'Staging Owner', phone: '07700000001', isAdmin: false, isBlocked: false });

    const cust1 = await createAuthUser('stage_cust1');
    await setFirestoreUser(cust1.uid, { name: 'Customer One', phone: '07700000002', isAdmin: false, isBlocked: false });

    const cust2 = await createAuthUser('stage_cust2');
    await setFirestoreUser(cust2.uid, { name: 'Customer Two', phone: '07700000003', isAdmin: false, isBlocked: false });
    console.log('✔ Synthetic test identities created successfully.');

    const cp = { freeCancellationHours: 24, lateRefundPercent: 20 };
    const start = Date.now() + 86400000 * 3;
    const end = start + 3600000 * 4;

    // 2. Conflicting Deposit Rejection
    console.log('\n[2/7] Testing conflicting deposit rejection (v.deposit != v.pricing.deposit)...');
    const conflictRes = await callFunction('saveBookingVenue', admin.idToken, {
      ownerId: owner.uid,
      name: 'Conflict Venue Test',
      location: 'Ramadi',
      category: 'chalet',
      price: 200000,
      deposit: 25000,
      pricing: { version: 2, deposit: 50000, shifts: [] },
      terms: 'terms',
      cancellationPolicy: cp,
      active: true
    });
    if (conflictRes.status === 400 && conflictRes.body.error?.message?.includes('تعارض بين عربون المكان وعربون التسعير المتقدم')) {
      console.log('✔ Conflicting deposit strictly rejected with 400 FAILED_PRECONDITION.');
    } else {
      throw new Error(`Conflict test failed! Result: ${JSON.stringify(conflictRes)}`);
    }

    // 3. V1 Venue Creation
    console.log('\n[3/7] Testing V1 legacy venue creation and booking...');
    const v1Res = await callFunction('saveBookingVenue', admin.idToken, {
      ownerId: owner.uid,
      name: 'V1 Staging Venue',
      location: 'Ramadi Corniche',
      category: 'chalet',
      price: 150000,
      deposit: 30000,
      terms: 'V1 terms',
      cancellationPolicy: cp,
      active: true
    });
    if (!v1Res.body.result?.id) throw new Error(`V1 venue creation failed: ${JSON.stringify(v1Res)}`);
    const v1VenueId = v1Res.body.result.id;
    createdVenues.push(v1VenueId);
    console.log(`✔ V1 Venue created with ID: ${v1VenueId}`);

    // 4. Tampered Price & Deposit Protection
    console.log('\n[4/7] Testing client price and deposit tamper protection on requestBooking...');
    const tamperDepositRes = await callFunction('requestBooking', cust1.idToken, {
      venueId: v1VenueId,
      requestId: 'tamper_dep_req',
      start,
      end,
      price: 150000,
      deposit: 1000, // Tampered deposit (should be 30000)
      acceptedTerms: 'V1 terms',
      cancellationPolicy: cp
    });
    if (tamperDepositRes.status === 400) {
      console.log('✔ Client-tampered deposit was rejected with 400.');
    } else {
      throw new Error(`Tampered deposit was NOT rejected: ${JSON.stringify(tamperDepositRes)}`);
    }

    const tamperPriceRes = await callFunction('requestBooking', cust1.idToken, {
      venueId: v1VenueId,
      requestId: 'tamper_price_req',
      start,
      end,
      price: 5000, // Tampered total price (should be 150000)
      deposit: 30000,
      acceptedTerms: 'V1 terms',
      cancellationPolicy: cp
    });
    if (tamperPriceRes.status === 400) {
      console.log('✔ Client-tampered price was rejected with 400.');
    } else {
      throw new Error(`Tampered price was NOT rejected: ${JSON.stringify(tamperPriceRes)}`);
    }

    // 5. Valid Booking Request
    console.log('\n[5/7] Testing valid booking request submission...');
    const req1 = await callFunction('requestBooking', cust1.idToken, {
      venueId: v1VenueId,
      requestId: 'stage_valid_req_1',
      start,
      end,
      price: 150000,
      deposit: 30000,
      acceptedTerms: 'V1 terms',
      cancellationPolicy: cp
    });
    if (!req1.body.result?.id) throw new Error(`Valid requestBooking failed: ${JSON.stringify(req1)}`);
    const booking1Id = req1.body.result.id;
    createdBookings.push(booking1Id);
    console.log(`✔ Booking request created with ID: ${booking1Id}`);

    // Competing customer 2 request for same slot
    const req2 = await callFunction('requestBooking', cust2.idToken, {
      venueId: v1VenueId,
      requestId: 'stage_valid_req_2',
      start,
      end,
      price: 150000,
      deposit: 30000,
      acceptedTerms: 'V1 terms',
      cancellationPolicy: cp
    });
    const booking2Id = req2.body.result?.id;
    if (booking2Id) createdBookings.push(booking2Id);
    console.log(`✔ Competing booking request created with ID: ${booking2Id}`);

    // 6. Owner Approval and OCC Concurrency Lock
    console.log('\n[6/7] Testing owner approval and OCC collision prevention...');
    const approveRes = await callFunction('actOnBooking', owner.idToken, {
      bookingId: booking1Id,
      action: 'approve'
    });
    if (approveRes.status !== 200) throw new Error(`Owner approve failed: ${JSON.stringify(approveRes)}`);
    console.log('✔ Owner approved booking 1 -> Status is now HELD with temporary timeout.');

    // Owner attempts to approve competing booking 2 for overlapping slot
    const approve2Res = await callFunction('actOnBooking', owner.idToken, {
      bookingId: booking2Id,
      action: 'approve'
    });
    if (approve2Res.status === 400 && approve2Res.body.error?.message?.includes('الموعد محجوز')) {
      console.log('✔ Competing approval on overlapping slot was strictly rejected with: الموعد محجوز');
    } else {
      throw new Error(`Overlapping approval was NOT rejected: ${JSON.stringify(approve2Res)}`);
    }

    // New request for same slot while held
    const req3 = await callFunction('requestBooking', cust2.idToken, {
      venueId: v1VenueId,
      requestId: 'stage_overlapping_new_req',
      start,
      end,
      price: 150000,
      deposit: 30000,
      acceptedTerms: 'V1 terms',
      cancellationPolicy: cp
    });
    if (req3.status === 400 && req3.body.error?.message?.includes('الموعد محجوز')) {
      console.log('✔ New request during temporary hold was strictly rejected with: الموعد محجوز');
    } else {
      throw new Error(`New request during hold was NOT rejected: ${JSON.stringify(req3)}`);
    }

    // 7. Cancellation Lifecycle
    console.log('\n[7/7] Testing customer cancellation while held...');
    const cancelRes = await callFunction('actOnBooking', cust1.idToken, {
      bookingId: booking1Id,
      action: 'cancel',
      reason: 'Synthetic acceptance test cancellation'
    });
    if (cancelRes.status === 200) {
      console.log('✔ Booking successfully cancelled by customer while held.');
    } else {
      throw new Error(`Cancellation failed: ${JSON.stringify(cancelRes)}`);
    }

    console.log('\n================================================================');
    console.log('ALL LIVE STAGING ACCEPTANCE TESTS PASSED (100%)');
    console.log('================================================================\n');

  } finally {
    // Cleanup synthetic fixtures
    console.log('Cleaning up synthetic test fixtures from Staging Firestore...');
    for (const bId of createdBookings) await deleteFirestoreDoc('bookings', bId);
    for (const vId of createdVenues) await deleteFirestoreDoc('booking_venues', vId);
    console.log('✔ Cleanup complete.');
  }
}

runStagingAcceptance().catch(err => {
  console.error('\n✖ STAGING ACCEPTANCE SUITE FAILED:', err);
  process.exitCode = 1;
});

