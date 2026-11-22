const { test, describe, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

const projectId = process.env.GCLOUD_PROJECT || 'aqar-bookings-test-20261009';

describe('Firebase Security Rules - Comprehensive Invariant Suite', () => {
  let testEnv;

  before(async () => {
    const [fHost, fPort] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
    const [sHost, sPort] = (process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199').split(':');

    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
        host: fHost,
        port: parseInt(fPort, 10),
      },
      storage: {
        rules: fs.readFileSync(path.resolve(__dirname, '../storage.rules'), 'utf8'),
        host: sHost,
        port: parseInt(sPort, 10),
      }
    });

    // Seed test fixtures with admin bypass
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      // Users
      await db.doc('users/admin_user').set({ isAdmin: true, isBlocked: false });
      await db.doc('users/finance_user').set({ isAdmin: false, canReviewBookingPayments: true, isBlocked: false });
      await db.doc('users/cust_1').set({ isAdmin: false, isBlocked: false });
      await db.doc('users/owner_1').set({ isAdmin: false, isBlocked: false });
      await db.doc('users/other_user').set({ isAdmin: false, isBlocked: false });

      // Bookings
      await db.doc('bookings/b_party').set({
        customerId: 'cust_1',
        ownerId: 'owner_1',
        venueId: 'v_approved',
        status: 'confirmed',
        total: 150000,
        deposit: 50000,
      });

      // Admin Notes subcollection
      await db.doc('bookings/b_party/admin_notes/note_1').set({
        adminUid: 'admin_user',
        note: 'ملاحظة سرية للتدقيق الإداري',
        createdAt: Date.now()
      });

      // Venues
      await db.doc('booking_venues/v_approved').set({
        ownerId: 'owner_1',
        name: 'شاليه اليمامة',
        active: true,
        verificationStatus: 'verified'
      });
      await db.doc('booking_venues/v_draft').set({
        ownerId: 'owner_1',
        name: 'شاليه مسودة غير منشور',
        active: false,
        verificationStatus: 'pending'
      });

      // Disputes & Support Tickets
      await db.doc('booking_support/ticket_open').set({
        ticketId: 'ticket_open',
        customerId: 'cust_1',
        ownerId: 'owner_1',
        userId: 'cust_1',
        status: 'open',
        bookingId: 'b_party'
      });
      await db.doc('booking_support/ticket_closed').set({
        ticketId: 'ticket_closed',
        customerId: 'cust_1',
        ownerId: 'owner_1',
        userId: 'cust_1',
        status: 'resolved',
        bookingId: 'b_party'
      });
      await db.doc('booking_disputes/disp_open').set({
        disputeId: 'disp_open',
        customerId: 'cust_1',
        ownerId: 'owner_1',
        status: 'open',
        bookingId: 'b_party'
      });

      // Action Audit
      await db.doc('booking_action_audit/audit_1').set({
        action: 'approveBookingVenue',
        actorUid: 'admin_user',
        bookingId: 'b_party'
      });
    });
  });

  after(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  // ==========================================
  // 1. FIRESTORE RULES TESTS
  // ==========================================
  describe('Firestore Security Rules', () => {
    test('FS-1: Unauthenticated user cannot read private booking', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.doc('bookings/b_party').get());
    });

    test('FS-2: Customer can read their own booking', async () => {
      const db = testEnv.authenticatedContext('cust_1').firestore();
      await assertSucceeds(db.doc('bookings/b_party').get());
    });

    test('FS-3: Customer CANNOT read admin_notes subcollection', async () => {
      const db = testEnv.authenticatedContext('cust_1').firestore();
      await assertFails(db.doc('bookings/b_party/admin_notes/note_1').get());
    });

    test('FS-4: Venue Owner can read booking for their venue', async () => {
      const db = testEnv.authenticatedContext('owner_1').firestore();
      await assertSucceeds(db.doc('bookings/b_party').get());
    });

    test('FS-5: Venue Owner CANNOT read admin_notes subcollection', async () => {
      const db = testEnv.authenticatedContext('owner_1').firestore();
      await assertFails(db.doc('bookings/b_party/admin_notes/note_1').get());
    });

    test('FS-6: Admin CAN read admin_notes subcollection', async () => {
      const db = testEnv.authenticatedContext('admin_user').firestore();
      await assertSucceeds(db.doc('bookings/b_party/admin_notes/note_1').get());
    });

    test('FS-7: Normal user CANNOT write to admin_notes directly', async () => {
      const db = testEnv.authenticatedContext('cust_1').firestore();
      await assertFails(db.doc('bookings/b_party/admin_notes/hacked_note').set({ note: 'malicious' }));
    });

    test('FS-8: Non-party user CANNOT read booking belonging to others', async () => {
      const db = testEnv.authenticatedContext('other_user').firestore();
      await assertFails(db.doc('bookings/b_party').get());
    });

    test('FS-9: Financial user (canReviewBookingPayments) CAN read booking financial data', async () => {
      const db = testEnv.authenticatedContext('finance_user').firestore();
      await assertSucceeds(db.doc('bookings/b_party').get());
    });

    test('FS-10: Financial user CANNOT read admin_notes subcollection', async () => {
      const db = testEnv.authenticatedContext('finance_user').firestore();
      await assertFails(db.doc('bookings/b_party/admin_notes/note_1').get());
    });

    test('FS-11: Normal user CANNOT read booking_action_audit directly', async () => {
      const db = testEnv.authenticatedContext('cust_1').firestore();
      await assertFails(db.doc('booking_action_audit/audit_1').get());
    });

    test('FS-12: Normal user CANNOT write to booking_action_audit directly', async () => {
      const db = testEnv.authenticatedContext('cust_1').firestore();
      await assertFails(db.doc('booking_action_audit/hack').set({ action: 'tamper' }));
    });

    test('FS-13: Dispute party CAN read booking_support ticket', async () => {
      const db = testEnv.authenticatedContext('cust_1').firestore();
      await assertSucceeds(db.doc('booking_support/ticket_open').get());
    });

    test('FS-14: Non-party CANNOT read booking_support ticket', async () => {
      const db = testEnv.authenticatedContext('other_user').firestore();
      await assertFails(db.doc('booking_support/ticket_open').get());
    });

    test('FS-15: Dispute party CAN read booking_disputes document', async () => {
      const db = testEnv.authenticatedContext('owner_1').firestore();
      await assertSucceeds(db.doc('booking_disputes/disp_open').get());
    });

    test('FS-16: Non-party CANNOT read booking_disputes document', async () => {
      const db = testEnv.authenticatedContext('other_user').firestore();
      await assertFails(db.doc('booking_disputes/disp_open').get());
    });

    test('FS-17: Public user CAN read approved & verified venue', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertSucceeds(db.doc('booking_venues/v_approved').get());
    });

    test('FS-18: Public user CANNOT read draft / unverified venue', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.doc('booking_venues/v_draft').get());
    });

    test('FS-19: Venue Owner CAN read their own draft venue', async () => {
      const db = testEnv.authenticatedContext('owner_1').firestore();
      await assertSucceeds(db.doc('booking_venues/v_draft').get());
    });
  });

  // ==========================================
  // 2. STORAGE RULES TESTS
  // ==========================================
  describe('Storage Security Rules', () => {
    test('ST-1: Authorized dispute party CAN upload valid JPEG (<= 10MB) to open dispute', async () => {
      const storage = testEnv.authenticatedContext('cust_1').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/evidence1.jpg');
      await assertSucceeds(ref.put(Buffer.from('fake-jpeg-data'), { contentType: 'image/jpeg' }));
    });

    test('ST-2: Authorized dispute party CAN upload valid PNG (<= 10MB) to open dispute', async () => {
      const storage = testEnv.authenticatedContext('cust_1').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/evidence2.png');
      await assertSucceeds(ref.put(Buffer.from('fake-png-data'), { contentType: 'image/png' }));
    });

    test('ST-3: Authorized dispute party CAN upload valid WEBP (<= 10MB) to open dispute', async () => {
      const storage = testEnv.authenticatedContext('cust_1').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/evidence3.webp');
      await assertSucceeds(ref.put(Buffer.from('fake-webp-data'), { contentType: 'image/webp' }));
    });

    test('ST-4: Authorized dispute party CAN upload valid PDF (<= 10MB) to open dispute', async () => {
      const storage = testEnv.authenticatedContext('cust_1').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/document.pdf');
      await assertSucceeds(ref.put(Buffer.from('%PDF-1.4 fake pdf data'), { contentType: 'application/pdf' }));
    });

    test('ST-5: Unsupported MIME type (executable / script) is REJECTED', async () => {
      const storage = testEnv.authenticatedContext('cust_1').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/malware.exe');
      await assertFails(ref.put(Buffer.from('evil-bytes'), { contentType: 'application/x-msdownload' }));
    });

    test('ST-6: File larger than 10MB is REJECTED', async () => {
      const storage = testEnv.authenticatedContext('cust_1').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/oversized.jpg');
      const largeBuffer = Buffer.alloc(11 * 1024 * 1024); // 11MB
      await assertFails(ref.put(largeBuffer, { contentType: 'image/jpeg' }));
    });

    test('ST-7: Non-party CANNOT upload evidence to another dispute', async () => {
      const storage = testEnv.authenticatedContext('other_user').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/other_user/evidence.jpg');
      await assertFails(ref.put(Buffer.from('fake-jpeg-data'), { contentType: 'image/jpeg' }));
    });

    test('ST-8: Non-party CANNOT read dispute evidence', async () => {
      const storage = testEnv.authenticatedContext('other_user').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/evidence1.jpg');
      await assertFails(ref.getDownloadURL());
    });

    test('ST-9: Uploading evidence to a CLOSED dispute is REJECTED', async () => {
      const storage = testEnv.authenticatedContext('cust_1').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_closed/cust_1/late_evidence.jpg');
      await assertFails(ref.put(Buffer.from('fake-jpeg-data'), { contentType: 'image/jpeg' }));
    });

    test('ST-10: Overwriting / updating existing evidence is REJECTED (immutability)', async () => {
      const storage = testEnv.authenticatedContext('cust_1').storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/evidence1.jpg');
      // Attempting to overwrite existing file must fail (resource != null)
      await assertFails(ref.put(Buffer.from('tampered-bytes'), { contentType: 'image/jpeg' }));
    });

    test('ST-11: Unauthenticated user CANNOT read dispute evidence (zero public read)', async () => {
      const storage = testEnv.unauthenticatedContext().storage();
      const ref = storage.ref('booking_dispute_evidence/ticket_open/cust_1/evidence1.jpg');
      await assertFails(ref.getDownloadURL());
    });
  });
});
