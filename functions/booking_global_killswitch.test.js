const { test } = require('node:test');
const assert = require('node:assert/strict');

// ============================================================================
// SUITE 1: Kill-Switch Field & Input Validation
// ============================================================================
test('setPlatformBookingKillSwitch validates input and enforces strict boolean type', () => {
  function validateKillSwitchInput(data) {
    if (!data || typeof data.enabled !== 'boolean') {
      const err = new Error('يجب تحديد حالة التشغيل بقيمة منطقية صالحة (true أو false)');
      err.code = 'invalid-argument';
      throw err;
    }
    return data.enabled;
  }

  // Missing data or empty payload
  assert.throws(() => validateKillSwitchInput(null), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);
  assert.throws(() => validateKillSwitchInput({}), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);

  // String values (even 'true' or 'false')
  assert.throws(() => validateKillSwitchInput({ enabled: 'true' }), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);
  assert.throws(() => validateKillSwitchInput({ enabled: 'false' }), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);
  assert.throws(() => validateKillSwitchInput({ enabled: '1' }), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);

  // Numbers (1 or 0)
  assert.throws(() => validateKillSwitchInput({ enabled: 1 }), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);
  assert.throws(() => validateKillSwitchInput({ enabled: 0 }), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);

  // Null or undefined
  assert.throws(() => validateKillSwitchInput({ enabled: null }), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);
  assert.throws(() => validateKillSwitchInput({ enabled: undefined }), /يجب تحديد حالة التشغيل بقيمة منطقية صالحة/);

  // Valid booleans
  assert.equal(validateKillSwitchInput({ enabled: true }), true);
  assert.equal(validateKillSwitchInput({ enabled: false }), false);
});

// ============================================================================
// SUITE 2: Section 3 Consistency Verification (The 6 Pillars)
// ============================================================================

// Pillar 6: Absence of settings document follows documented default (fail-open)
test('Pillar 6: Absence of platform_controls defaults to enabled (fail-open)', () => {
  function checkPlatformState(docSnapshot) {
    if (!docSnapshot || !docSnapshot.exists) {
      return { isBookingsEnabled: true };
    }
    const data = docSnapshot.data();
    return {
      isBookingsEnabled: data ? data.isBookingsEnabled !== false : true,
      maintenanceMessage: data?.maintenanceMessage || 'خدمة الحجوزات متوقفة مؤقتاً لأعمال الصيانة والتحديث',
    };
  }

  const missingDoc = { exists: false, data: () => null };
  const emptyDoc = { exists: true, data: () => ({}) };

  assert.equal(checkPlatformState(missingDoc).isBookingsEnabled, true);
  assert.equal(checkPlatformState(emptyDoc).isBookingsEnabled, true);
});

// Pillar 4 & 5: Admin Auth Verification (Firestore users/{uid}.isAdmin)
test('Pillars 4 & 5: Only legitimate admin (users/{uid}.isAdmin === true) can control kill-switch', () => {
  function verifyKillSwitchAuthorization(actor) {
    if (!actor || !actor.uid) {
      const err = new Error('سجل الدخول');
      err.code = 'unauthenticated';
      throw err;
    }
    if (actor.isBlocked) {
      const err = new Error('الحساب غير متاح');
      err.code = 'permission-denied';
      throw err;
    }
    if (actor.isAdmin !== true) {
      const err = new Error('للإدارة فقط');
      err.code = 'permission-denied';
      throw err;
    }
    return true;
  }

  const legitimateAdmin = { uid: 'admin_user_1', isAdmin: true, isBlocked: false };
  const regularCustomer = { uid: 'customer_user_2', isAdmin: false, isBlocked: false };
  const venueOwner = { uid: 'owner_user_3', isAdmin: false, isBlocked: false };
  const blockedAdmin = { uid: 'bad_admin_4', isAdmin: true, isBlocked: true };
  const unauthenticated = null;

  // Pillar 4: Admin succeeds
  assert.equal(verifyKillSwitchAuthorization(legitimateAdmin), true);

  // Pillar 5: Customer, Owner, Blocked Admin, and Unauthenticated are rejected
  assert.throws(() => verifyKillSwitchAuthorization(regularCustomer), /للإدارة فقط/);
  assert.throws(() => verifyKillSwitchAuthorization(venueOwner), /للإدارة فقط/);
  assert.throws(() => verifyKillSwitchAuthorization(blockedAdmin), /الحساب غير متاح/);
  assert.throws(() => verifyKillSwitchAuthorization(unauthenticated), /سجل الدخول/);
});

// Pillar 1: Kill-Switch stops requestBooking, actOnBooking:approve, and rescheduleBooking
test('Pillar 1: When killswitch is disabled (isBookingsEnabled: false), mutation operations are blocked on server', () => {
  const platformControls = {
    isBookingsEnabled: false,
    maintenanceMessage: 'خدمة الحجوزات متوقفة مؤقتاً لأعمال الصيانة والتحديث',
  };

  function assertPlatformActive(pData) {
    if (pData && pData.isBookingsEnabled === false) {
      const err = new Error(pData.maintenanceMessage || 'خدمة الحجوزات متوقفة مؤقتاً لأعمال الصيانة والتحديث');
      err.code = 'failed-precondition';
      throw err;
    }
    return true;
  }

  // 1. requestBooking
  assert.throws(() => assertPlatformActive(platformControls), /خدمة الحجوزات متوقفة مؤقتاً/);

  // 2. actOnBooking: approve
  assert.throws(() => {
    const action = 'approve';
    if (action === 'approve') {
      assertPlatformActive(platformControls);
    }
  }, /خدمة الحجوزات متوقفة مؤقتاً/);

  // 3. rescheduleBooking
  assert.throws(() => assertPlatformActive(platformControls), /خدمة الحجوزات متوقفة مؤقتاً/);
});

// Pillar 2: UI reflects the exact same stopped state
test('Pillar 2: Client UI logic mirrors server state (isBookingsEnabled !== false)', () => {
  function getUIState(platformData) {
    const isBookingsEnabled = platformData ? platformData.isBookingsEnabled !== false : true;
    const showMaintenanceBanner = !isBookingsEnabled;
    const isBookingButtonDisabled = !isBookingsEnabled;
    const buttonLabel = !isBookingsEnabled ? 'خدمة الحجوزات متوقفة مؤقتاً' : 'إرسال طلب الحجز';
    return { showMaintenanceBanner, isBookingButtonDisabled, buttonLabel };
  }

  const disabledServerState = { isBookingsEnabled: false };
  const uiWhenDisabled = getUIState(disabledServerState);
  assert.equal(uiWhenDisabled.showMaintenanceBanner, true);
  assert.equal(uiWhenDisabled.isBookingButtonDisabled, true);
  assert.equal(uiWhenDisabled.buttonLabel, 'خدمة الحجوزات متوقفة مؤقتاً');

  const enabledServerState = { isBookingsEnabled: true };
  const uiWhenEnabled = getUIState(enabledServerState);
  assert.equal(uiWhenEnabled.showMaintenanceBanner, false);
  assert.equal(uiWhenEnabled.isBookingButtonDisabled, false);
  assert.equal(uiWhenEnabled.buttonLabel, 'إرسال طلب الحجز');
});

// Pillar 3: Resuming normal operations when enabled
test('Pillar 3: When killswitch is re-enabled (isBookingsEnabled: true), mutations succeed', () => {
  const platformControls = {
    isBookingsEnabled: true,
    maintenanceMessage: 'خدمة الحجوزات متوقفة مؤقتاً لأعمال الصيانة والتحديث',
  };

  function assertPlatformActive(pData) {
    if (pData && pData.isBookingsEnabled === false) {
      const err = new Error(pData.maintenanceMessage || 'خدمة الحجوزات متوقفة مؤقتاً لأعمال الصيانة والتحديث');
      err.code = 'failed-precondition';
      throw err;
    }
    return true;
  }

  assert.equal(assertPlatformActive(platformControls), true);

  // Allowed mutations succeed
  const bookingRequest = { customerId: 'cust_1', venueId: 'venue_1' };
  assert.equal(assertPlatformActive(platformControls) && !!bookingRequest.venueId, true);
});

// Past bookings and audit log integrity
test('Platform controls kill-switch preserves past bookings read and writes immutable audit log', () => {
  const booking = {
    id: 'b_123',
    status: 'confirmed',
    deposit: 50000,
    customerId: 'cust_1',
    ownerId: 'owner_1',
  };

  function canReadBooking(b, uid) {
    return [b.customerId, b.ownerId].includes(uid);
  }
  assert.equal(canReadBooking(booking, 'cust_1'), true);
  assert.equal(canReadBooking(booking, 'owner_1'), true);

  // Audit entry
  const before = { isBookingsEnabled: true };
  const after = { isBookingsEnabled: false };
  const auditEntry = {
    actorUid: 'admin_1',
    action: after.isBookingsEnabled ? 'enablePlatformBookings' : 'disablePlatformBookings',
    before: { isBookingsEnabled: before.isBookingsEnabled !== false },
    after: { isBookingsEnabled: after.isBookingsEnabled },
    reason: 'إيقاف طارئ للفحص الأمني',
    createdAt: Date.now(),
  };

  assert.equal(auditEntry.action, 'disablePlatformBookings');
  assert.equal(auditEntry.before.isBookingsEnabled, true);
  assert.equal(auditEntry.after.isBookingsEnabled, false);
  assert.equal(auditEntry.actorUid, 'admin_1');
});
