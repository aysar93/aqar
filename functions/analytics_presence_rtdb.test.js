'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { resolveDatabaseURLForTest } = require('./analytics_presence_access');

test('RTDB URL resolution: resolves from app.options.databaseURL', () => {
  const fakeApp = { options: { databaseURL: 'https://staging-rtdb.firebaseio.com' } };
  assert.equal(resolveDatabaseURLForTest(fakeApp), 'https://staging-rtdb.firebaseio.com');
});

test('RTDB URL resolution: resolves strictly to Staging RTDB when configured for aqar-bookings-test-20261009 and never leaks production', () => {
  const stagingApp = {
    options: {
      projectId: 'aqar-bookings-test-20261009',
      databaseURL: 'https://aqar-bookings-test-20261009-default-rtdb.asia-southeast1.firebasedatabase.app'
    }
  };
  const resolved = resolveDatabaseURLForTest(stagingApp);
  assert.equal(resolved, 'https://aqar-bookings-test-20261009-default-rtdb.asia-southeast1.firebasedatabase.app');
  assert.notEqual(resolved, 'https://aqar-9f3f9-default-rtdb.asia-southeast1.firebasedatabase.app');
});

test('RTDB URL resolution: resolves from process.env.RTDB_URL or DATABASE_URL', () => {
  const prevRtdb = process.env.RTDB_URL;
  const prevDb = process.env.DATABASE_URL;
  const prevEmu = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  const fakeApp = { options: {} };

  try {
    delete process.env.FIREBASE_DATABASE_EMULATOR_HOST;
    process.env.RTDB_URL = 'https://custom-env-rtdb.firebaseio.com';
    assert.equal(resolveDatabaseURLForTest(fakeApp), 'https://custom-env-rtdb.firebaseio.com');

    delete process.env.RTDB_URL;
    process.env.DATABASE_URL = 'https://fallback-db-rtdb.firebaseio.com';
    assert.equal(resolveDatabaseURLForTest(fakeApp), 'https://fallback-db-rtdb.firebaseio.com');
  } finally {
    if (prevRtdb !== undefined) process.env.RTDB_URL = prevRtdb; else delete process.env.RTDB_URL;
    if (prevDb !== undefined) process.env.DATABASE_URL = prevDb; else delete process.env.DATABASE_URL;
    if (prevEmu !== undefined) process.env.FIREBASE_DATABASE_EMULATOR_HOST = prevEmu; else delete process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  }
});

test('RTDB URL resolution: parses FIREBASE_CONFIG JSON correctly', () => {
  const prevConfig = process.env.FIREBASE_CONFIG;
  const prevEmu = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  const fakeApp = { options: {} };

  try {
    delete process.env.FIREBASE_DATABASE_EMULATOR_HOST;
    // 1. With databaseURL
    process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'test-proj', databaseURL: 'https://config-rtdb.firebaseio.com' });
    assert.equal(resolveDatabaseURLForTest(fakeApp), 'https://config-rtdb.firebaseio.com');

    // 2. Without databaseURL (common in many Firebase deployments)
    process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'test-proj' });
    assert.equal(resolveDatabaseURLForTest(fakeApp), null);

    // 3. Malformed JSON
    process.env.FIREBASE_CONFIG = 'NOT_JSON';
    assert.equal(resolveDatabaseURLForTest(fakeApp), null);
  } finally {
    if (prevConfig !== undefined) process.env.FIREBASE_CONFIG = prevConfig; else delete process.env.FIREBASE_CONFIG;
    if (prevEmu !== undefined) process.env.FIREBASE_DATABASE_EMULATOR_HOST = prevEmu; else delete process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  }
});

test('RTDB URL resolution: resolves local emulator when host is set', () => {
  const prevEmu = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  const prevProj = process.env.GCLOUD_PROJECT;
  const fakeApp = { options: { projectId: 'my-test-proj' } };

  try {
    process.env.FIREBASE_DATABASE_EMULATOR_HOST = '127.0.0.1:9000';
    process.env.GCLOUD_PROJECT = 'my-test-proj';
    assert.equal(resolveDatabaseURLForTest(fakeApp), 'http://127.0.0.1:9000?ns=my-test-proj-default-rtdb');
  } finally {
    if (prevEmu !== undefined) process.env.FIREBASE_DATABASE_EMULATOR_HOST = prevEmu; else delete process.env.FIREBASE_DATABASE_EMULATOR_HOST;
    if (prevProj !== undefined) process.env.GCLOUD_PROJECT = prevProj; else delete process.env.GCLOUD_PROJECT;
  }
});

test('RTDB URL resolution: returns null when unconfigured and never falls back to production aqar-9f3f9', () => {
  const prevRtdb = process.env.RTDB_URL;
  const prevDb = process.env.DATABASE_URL;
  const prevConfig = process.env.FIREBASE_CONFIG;
  const prevEmu = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  const fakeApp = { options: {} };

  try {
    delete process.env.RTDB_URL;
    delete process.env.DATABASE_URL;
    delete process.env.FIREBASE_CONFIG;
    delete process.env.FIREBASE_DATABASE_EMULATOR_HOST;

    const resolved = resolveDatabaseURLForTest(fakeApp);
    assert.equal(resolved, null, 'Should return null when unconfigured');
    assert.notEqual(resolved, 'https://aqar-9f3f9-default-rtdb.asia-southeast1.firebasedatabase.app', 'MUST NEVER fall back to production URL');
  } finally {
    if (prevRtdb !== undefined) process.env.RTDB_URL = prevRtdb;
    if (prevDb !== undefined) process.env.DATABASE_URL = prevDb;
    if (prevConfig !== undefined) process.env.FIREBASE_CONFIG = prevConfig;
    if (prevEmu !== undefined) process.env.FIREBASE_DATABASE_EMULATOR_HOST = prevEmu;
  }
});
