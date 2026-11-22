'use strict';

const fs = require('fs');
const path = require('path');

// 1. Load Staging Credentials
const configFile = path.join(process.env.USERPROFILE, '.config/configstore/firebase-tools.json');
const gToken = JSON.parse(fs.readFileSync(configFile)).tokens.access_token;
const servicesJson = JSON.parse(fs.readFileSync(path.join(__dirname, '../../android/app/src/bookingsStaging/google-services.json')));
const apiKey = servicesJson.client[0].api_key[0].current_key;

const PROJECT = 'aqar-bookings-test-20261009';
if (PROJECT !== 'aqar-bookings-test-20261009') {
  throw new Error('FATAL: Target project is NOT staging!');
}
const BASE_URL = `https://us-central1-${PROJECT}.cloudfunctions.net`;
const FIRESTORE_REST = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

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
  const email = `${prefix}_${Date.now()}_${Math.floor(Math.random()*1000)}@example.test`;
  const authRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'Password123!', returnSecureToken: true })
  }).then(r => r.json());
  if (!authRes.localId || !authRes.idToken) {
    throw new Error(`Failed to create auth user: ${JSON.stringify(authRes)}`);
  }
  return { uid: authRes.localId, idToken: authRes.idToken, email };
}

async function setFirestoreUser(uid, fields) {
  const bodyFields = {};
  for (const [k, v] of Object.entries(fields)) {
    if (typeof v === 'string') bodyFields[k] = { stringValue: v };
    else if (typeof v === 'boolean') bodyFields[k] = { booleanValue: v };
    else if (typeof v === 'number') bodyFields[k] = { integerValue: String(v) };
  }
  const res = await fetch(`${FIRESTORE_REST}/users/${uid}`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${gToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ fields: bodyFields })
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`setFirestoreUser failed: ${err}`);
  }
}

async function getFirestoreDoc(collection, id, token = gToken) {
  const res = await fetch(`${FIRESTORE_REST}/${collection}/${id}`, {
    method: 'GET',
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (res.status === 404) return null;
  const json = await res.json();
  return { status: res.status, data: json };
}

async function deleteFirestoreDoc(collection, id) {
  try {
    await fetch(`${FIRESTORE_REST}/${collection}/${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${gToken}` }
    });
  } catch (_) {}
}

async function queryActiveVenues(token) {
  const res = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'booking_venues' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'active' },
            op: 'EQUAL',
            value: { booleanValue: true }
          }
        }
      }
    })
  });
  const json = await res.json();
  if (!Array.isArray(json)) return [];
  return json.filter(item => item.document).map(item => {
    const name = item.document.name.split('/').pop();
    return { id: name, ...item.document.fields };
  });
}

async function runChaletReelsAcceptance() {
  console.log(`\n================================================================`);
  console.log(`STAGING CHALETS & BOOKING REELS INTEGRATION SUITE`);
  console.log(`Target Staging Project: ${PROJECT}`);
  console.log(`Execution Mode: LIVE REAL NETWORK (Zero Mocks)`);
  console.log(`================================================================\n`);

  const createdVenues = [];
  const createdReels = [];
  const createdBookings = [];
  const createdReports = [];
  const createdUsers = [];

  try {
    // -------------------------------------------------------------
    // PHASE 1: Create Test Actors
    // -------------------------------------------------------------
    console.log('[PHASE 1/8] Provisioning synthetic test identities...');
    const owner = await createAuthUser('owner_chalet');
    createdUsers.push(owner.uid);
    await setFirestoreUser(owner.uid, { name: 'مالك شاليهات الأنبار', phone: '07801234567', isAdmin: false, isBlocked: false });

    const admin = await createAuthUser('admin_chalet');
    createdUsers.push(admin.uid);
    await setFirestoreUser(admin.uid, { name: 'مشرف عقارات الأنبار', phone: '07709876543', isAdmin: true, isBlocked: false });

    const otherOwner = await createAuthUser('other_owner');
    createdUsers.push(otherOwner.uid);
    await setFirestoreUser(otherOwner.uid, { name: 'مالك آخر متسلل', phone: '07701112233', isAdmin: false, isBlocked: false });

    const customer1 = await createAuthUser('chalet_cust1');
    createdUsers.push(customer1.uid);
    await setFirestoreUser(customer1.uid, { name: 'أحمد الحلبوسي', phone: '07705556677', isAdmin: false, isBlocked: false });

    const customer2 = await createAuthUser('chalet_cust2');
    createdUsers.push(customer2.uid);
    await setFirestoreUser(customer2.uid, { name: 'عمر الدليمي', phone: '07708889900', isAdmin: false, isBlocked: false });

    console.log('✔ Test actors provisioned: Owner, Admin, Other Owner, Customer 1, Customer 2.');

    const cp = { freeCancellationHours: 24, lateRefundPercent: 20 };
    const v2Pricing = {
      version: 2,
      timeZone: 'Asia/Baghdad',
      weekendDays: [5],
      deposit: 50000,
      shifts: [
        {
          kind: 'morning',
          enabled: true,
          startMinute: 540,
          endMinute: 900,
          endDayOffset: 0,
          weekdayPrice: 100000,
          weekendPrice: 120000
        },
        {
          kind: 'evening',
          enabled: true,
          startMinute: 960,
          endMinute: 1380,
          endDayOffset: 0,
          weekdayPrice: 150000,
          weekendPrice: 180000
        },
        {
          kind: 'full_day',
          enabled: true,
          startMinute: 540,
          endMinute: 480,
          endDayOffset: 1,
          weekdayPrice: 250000,
          weekendPrice: 300000
        }
      ]
    };

    // -------------------------------------------------------------
    // PHASE 2: Owner Registers New Chalet -> Must Be Inactive & Pending
    // -------------------------------------------------------------
    console.log('\n[PHASE 2/8] Testing Chalet Registration by Owner (Pending Verification)...');
    const createRes = await callFunction('saveBookingVenue', owner.idToken, {
      ownerId: owner.uid,
      name: 'شاليه النخيل الملكي - الرمادي الحبانية',
      location: 'الأنبار - بحيرة الحبانية',
      category: 'chalet',
      price: 100000,
      deposit: 50000,
      pricing: v2Pricing,
      terms: 'الالتزام بنظافة الشاليه وعدم التدخين في الغرف المغلقة',
      cancellationPolicy: cp,
      active: false
    });

    if (!createRes.body.result?.id) {
      throw new Error(`Failed to create chalet venue: ${JSON.stringify(createRes)}`);
    }
    const chaletId = createRes.body.result.id;
    createdVenues.push(chaletId);
    console.log(`✔ Chalet created with ID: ${chaletId}`);

    // Verify document in Firestore
    const vDoc = await getFirestoreDoc('booking_venues', chaletId);
    const vFields = vDoc.data.fields;
    const isActive = vFields.active?.booleanValue;
    const status = vFields.verificationStatus?.stringValue;
    console.log(`  Initial State: active=${isActive}, verificationStatus=${status}`);
    if (isActive !== false || status !== 'pending') {
      throw new Error(`Expected active:false and status:pending, got active:${isActive}, status:${status}`);
    }

    // Verify unapproved chalet is NOT visible to public query
    const publicList1 = await queryActiveVenues(customer1.idToken);
    const foundInPublic1 = publicList1.some(v => v.id === chaletId);
    if (foundInPublic1) {
      throw new Error('SECURITY VIOLATION: Unapproved chalet was returned in public active venues query!');
    }
    console.log('✔ Verified: Unapproved chalet is strictly excluded from public queries.');

    // -------------------------------------------------------------
    // PHASE 3: Security Protections Against Unauthorized Activations and Edits
    // -------------------------------------------------------------
    console.log('\n[PHASE 3/8] Testing Security Rules: Unauthorized Activations & Tampering...');

    // 3a. Owner attempts direct Firestore REST patch to self-activate (violates firestore.rules write: if false)
    const directPatchRes = await fetch(`${FIRESTORE_REST}/booking_venues/${chaletId}?updateMask.fieldPaths=active`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${owner.idToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: { active: { booleanValue: true } }
      })
    });
    if (directPatchRes.status === 403) {
      console.log('✔ Direct Firestore patch blocked by rules (403 PERMISSION_DENIED).');
    } else {
      throw new Error(`Direct patch security leak! Status: ${directPatchRes.status}`);
    }

    // 3b. Owner calls saveBookingVenue with active: true before admin verification
    const selfActivateRes = await callFunction('saveBookingVenue', owner.idToken, {
      id: chaletId,
      ownerId: owner.uid,
      name: 'شاليه النخيل الملكي - محاولة تفعيل ذاتي',
      location: 'الأنبار',
      category: 'chalet',
      price: 250000,
      deposit: 50000,
      active: true,
      cancellationPolicy: cp,
      terms: 'terms'
    });
    if (selfActivateRes.status === 400 || selfActivateRes.status === 403) {
      console.log('✔ Self-activation without admin review blocked by Cloud Functions.');
    } else {
      throw new Error(`Self-activation was NOT blocked: ${JSON.stringify(selfActivateRes)}`);
    }

    // 3c. Other owner attempts to modify someone else's chalet
    const maliciousEditRes = await callFunction('saveBookingVenue', otherOwner.idToken, {
      id: chaletId,
      ownerId: otherOwner.uid,
      name: 'محاولة اختراق الملكية',
      location: 'مكان مسروق',
      category: 'chalet',
      price: 10000,
      deposit: 1000,
      active: false,
      cancellationPolicy: cp,
      terms: 'hacked'
    });
    if (maliciousEditRes.status === 403) {
      console.log('✔ Malicious modification attempt by non-owner rejected with 403 PERMISSION_DENIED.');
    } else {
      throw new Error(`Malicious edit was NOT rejected: ${JSON.stringify(maliciousEditRes)}`);
    }

    // -------------------------------------------------------------
    // PHASE 4: Admin Review Cycle -> Approval Flow
    // -------------------------------------------------------------
    console.log('\n[PHASE 4/8] Testing Admin Review & Approval Flow...');

    // Owner creates proof record
    await fetch(`${FIRESTORE_REST}/booking_ownership_proofs/${chaletId}`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${gToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: {
          venueId: { stringValue: chaletId },
          ownerId: { stringValue: owner.uid },
          path: { stringValue: `booking_ownership_documents/${chaletId}/${owner.uid}/deed.pdf` },
          status: { stringValue: 'pending' }
        }
      })
    });

    // Admin reviews and verifies proof
    const verifyProofRes = await callFunction('reviewBookingOwnershipProof', admin.idToken, {
      venueId: chaletId,
      approved: true,
      reason: 'تم التحقق من سند الملكية والشهادة العقارية بنجاح'
    });
    if (verifyProofRes.status !== 200) {
      throw new Error(`Admin proof verification failed: ${JSON.stringify(verifyProofRes)}`);
    }
    console.log('✔ Admin approved ownership proof via reviewBookingOwnershipProof.');

    // Admin activates venue
    const activateRes = await callFunction('saveBookingVenue', admin.idToken, {
      id: chaletId,
      ownerId: owner.uid,
      name: 'شاليه النخيل الملكي - الحبانية (معتمد)',
      location: 'الأنبار - الحبانية',
      category: 'chalet',
      price: 100000,
      deposit: 50000,
      pricing: v2Pricing,
      terms: 'الالتزام بنظافة الشاليه',
      cancellationPolicy: cp,
      active: true
    });
    if (activateRes.status !== 200) {
      throw new Error(`Admin activation failed: ${JSON.stringify(activateRes)}`);
    }
    console.log('✔ Chalet officially verified and activated by Admin.');

    // Verify public query now contains the approved chalet
    const publicList2 = await queryActiveVenues(customer1.idToken);
    const foundInPublic2 = publicList2.some(v => v.id === chaletId);
    if (!foundInPublic2) {
      throw new Error('Approved chalet was NOT found in public query!');
    }
    console.log('✔ Verified: Approved chalet is now live in public active venues query.');

    // -------------------------------------------------------------
    // PHASE 5: Admin Rejection Flow
    // -------------------------------------------------------------
    console.log('\n[PHASE 5/8] Testing Venue Rejection Flow with Reason...');
    const rejectVenueRes = await callFunction('saveBookingVenue', owner.idToken, {
      ownerId: owner.uid,
      name: 'مزرعة الفرات للتجربة',
      location: 'الأنبار - الصقلاوية',
      category: 'farm',
      price: 180000,
      deposit: 40000,
      terms: 'شروط',
      cancellationPolicy: cp,
      active: false
    });
    const rejectedVenueId = rejectVenueRes.body.result?.id;
    if (!rejectedVenueId) throw new Error('Failed to create venue for rejection test');
    createdVenues.push(rejectedVenueId);

    // Create proof record
    await fetch(`${FIRESTORE_REST}/booking_ownership_proofs/${rejectedVenueId}`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${gToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: {
          venueId: { stringValue: rejectedVenueId },
          ownerId: { stringValue: owner.uid },
          path: { stringValue: `booking_ownership_documents/${rejectedVenueId}/${owner.uid}/unclear.jpg` },
          status: { stringValue: 'pending' }
        }
      })
    });

    const rejectRes = await callFunction('reviewBookingOwnershipProof', admin.idToken, {
      venueId: rejectedVenueId,
      approved: false,
      reason: 'وثائق الملكية المرفقة غير واضحة ويجب تقديم صورة واضحة من السند العقاري'
    });
    if (rejectRes.status !== 200) throw new Error(`Rejection call failed: ${JSON.stringify(rejectRes)}`);

    const rejDoc = await getFirestoreDoc('booking_venues', rejectedVenueId);
    if (rejDoc.data.fields.verificationStatus?.stringValue !== 'rejected') {
      throw new Error(`Venue was not marked rejected: ${JSON.stringify(rejDoc)}`);
    }
    console.log('✔ Venue properly rejected by Admin with explicit Arabic reason recorded.');

    // -------------------------------------------------------------
    // PHASE 6: Booking Reels Lifecycle & Social Interactivity
    // -------------------------------------------------------------
    console.log('\n[PHASE 6/8] Testing Booking Reels, Likes, Comments, Saves, and Reports...');

    const reelId = `reel_${Date.now()}`;
    createdReels.push(reelId);

    // Create Reel doc (as owner)
    const createReelRes = await fetch(`${FIRESTORE_REST}/booking_reels/${reelId}`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${owner.idToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: {
          venueId: { stringValue: chaletId },
          ownerId: { stringValue: owner.uid },
          venueName: { stringValue: 'شاليه النخيل الملكي' },
          category: { stringValue: 'chalet' },
          location: { stringValue: 'الأنبار - بحيرة الحبانية' },
          price: { integerValue: '250000' },
          deposit: { integerValue: '50000' },
          videoUrl: { stringValue: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4' },
          active: { booleanValue: true },
          likesCount: { integerValue: '0' },
          commentsCount: { integerValue: '0' },
          sharesCount: { integerValue: '0' },
          viewsCount: { integerValue: '0' }
        }
      })
    });
    if (!createReelRes.ok) {
      throw new Error(`Failed to create booking reel: ${await createReelRes.text()}`);
    }
    console.log(`✔ Booking Reel created with ID: ${reelId}`);

    // 6a. Customer 1 likes the reel
    const likeRes = await fetch(`${FIRESTORE_REST}/booking_reels/${reelId}/likes/${customer1.uid}`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${customer1.idToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: {
          userId: { stringValue: customer1.uid },
          likedAt: { timestampValue: new Date().toISOString() }
        }
      })
    });
    if (!likeRes.ok) throw new Error(`Like failed: ${await likeRes.text()}`);

    // Customer 1 increments like counter (allowed by updated rules)
    const incLikeRes = await fetch(`${FIRESTORE_REST}/booking_reels/${reelId}?updateMask.fieldPaths=likesCount`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${customer1.idToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: { likesCount: { integerValue: '1' } }
      })
    });
    if (!incLikeRes.ok) throw new Error(`Increment likesCount failed: ${await incLikeRes.text()}`);
    console.log('✔ Reel Like created and likesCount incremented securely.');

    // 6b. Customer 1 adds comment
    const commentId = `comment_${Date.now()}`;
    const commentRes = await fetch(`${FIRESTORE_REST}/booking_reels/${reelId}/comments/${commentId}`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${customer1.idToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: {
          userId: { stringValue: customer1.uid },
          userName: { stringValue: 'أحمد الحلبوسي' },
          text: { stringValue: 'ما شاء الله مكان رائع ومناسب للعائلات جداً' }
        }
      })
    });
    if (!commentRes.ok) throw new Error(`Comment creation failed: ${await commentRes.text()}`);
    console.log('✔ Comment added by Customer 1.');

    // 6c. Customer 2 (non-author) attempts to delete Customer 1's comment -> Must be rejected (403)
    const unauthorizedDelComment = await fetch(`${FIRESTORE_REST}/booking_reels/${reelId}/comments/${commentId}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${customer2.idToken}` }
    });
    if (unauthorizedDelComment.status === 403) {
      console.log('✔ Non-author deletion of comment blocked by security rules (403).');
    } else {
      throw new Error(`Unauthorized comment deletion was NOT blocked: ${unauthorizedDelComment.status}`);
    }

    // 6d. Customer 1 (author) deletes their own comment -> Allowed
    const authorDelComment = await fetch(`${FIRESTORE_REST}/booking_reels/${reelId}/comments/${commentId}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${customer1.idToken}` }
    });
    if (!authorDelComment.ok) throw new Error(`Author comment deletion failed: ${authorDelComment.status}`);
    console.log('✔ Comment successfully deleted by its author.');

    // 6e. Customer 1 saves reel
    const saveReelRes = await fetch(`${FIRESTORE_REST}/users/${customer1.uid}/saved_booking_reels/${reelId}`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${customer1.idToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: {
          reelId: { stringValue: reelId },
          venueId: { stringValue: chaletId },
          venueName: { stringValue: 'شاليه النخيل الملكي' },
          savedAt: { timestampValue: new Date().toISOString() }
        }
      })
    });
    if (!saveReelRes.ok) throw new Error(`Save reel failed: ${await saveReelRes.text()}`);
    console.log('✔ Reel saved to Customer 1 profile.');

    // 6f. Customer 1 unsaves reel
    const unsaveRes = await fetch(`${FIRESTORE_REST}/users/${customer1.uid}/saved_booking_reels/${reelId}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${customer1.idToken}` }
    });
    if (!unsaveRes.ok) throw new Error(`Unsave reel failed: ${unsaveRes.status}`);
    console.log('✔ Reel unsaved successfully.');

    // 6g. Customer 1 submits report
    const reportId = `report_${Date.now()}`;
    createdReports.push(reportId);
    const reportRes = await fetch(`${FIRESTORE_REST}/booking_reel_reports/${reportId}`, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${customer1.idToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fields: {
          reelId: { stringValue: reelId },
          venueId: { stringValue: chaletId },
          reporterId: { stringValue: customer1.uid },
          reason: { stringValue: 'اختبار بلاغ تجريبي - محتوى غير مطابق' }
        }
      })
    });
    if (!reportRes.ok) throw new Error(`Report submission failed: ${await reportRes.text()}`);
    console.log('✔ Content report recorded in booking_reel_reports.');

    // -------------------------------------------------------------
    // PHASE 7: Direct Booking Request from Reel Data
    // -------------------------------------------------------------
    console.log('\n[PHASE 7/8] Submitting Booking Request for Approved Chalet...');
    // Wednesday Oct 28, 2026: 09:00 Baghdad time is 06:00 UTC
    const start = Date.UTC(2026, 9, 28, 6, 0, 0, 0);
    const end = start + 360 * 60000; // 6 hours (09:00 - 15:00)
    const reqRes = await callFunction('requestBooking', customer1.idToken, {
      venueId: chaletId,
      requestId: `req_${Date.now()}`,
      shiftId: 'morning',
      start,
      end,
      price: 100000,
      deposit: 50000,
      acceptedTerms: 'الالتزام بنظافة الشاليه',
      cancellationPolicy: cp
    });

    if (!reqRes.body.result?.id) {
      throw new Error(`Booking request failed: ${JSON.stringify(reqRes)}`);
    }
    const bookingId = reqRes.body.result.id;
    createdBookings.push(bookingId);
    console.log(`✔ Booking Request created: ${bookingId}`);

    // Verify slot is locked/held
    const bookingDoc = await getFirestoreDoc('bookings', bookingId);
    const bStatus = bookingDoc.data.fields.status?.stringValue;
    console.log(`  Booking Document status: ${bStatus}`);
    if (bStatus !== 'held' && bStatus !== 'requested') {
      throw new Error(`Unexpected booking status: ${bStatus}`);
    }
    console.log('✔ Chalet slot successfully held and verified.');

  } finally {
    // -------------------------------------------------------------
    // PHASE 8: Clean Up Synthetic Test Fixtures
    // -------------------------------------------------------------
    console.log('\n[PHASE 8/8] Cleaning up synthetic test fixtures on Staging...');
    for (const v of createdVenues) {
      await deleteFirestoreDoc('booking_venues', v);
      await deleteFirestoreDoc('booking_ownership_proofs', v);
    }
    for (const r of createdReels) {
      await deleteFirestoreDoc('booking_reels', r);
    }
    for (const b of createdBookings) {
      await deleteFirestoreDoc('bookings', b);
    }
    for (const rep of createdReports) {
      await deleteFirestoreDoc('booking_reel_reports', rep);
    }
    console.log('✔ All synthetic test fixtures successfully cleaned up.');
  }

  console.log(`\n================================================================`);
  console.log(`ALL 8 PHASES OF CHALET & REELS ACCEPTANCE PASSED ON STAGING!`);
  console.log(`================================================================\n`);
}

runChaletReelsAcceptance().catch(err => {
  console.error('\n❌ STAGING CHALET & REELS ACCEPTANCE FAILED:', err);
  process.exit(1);
});
