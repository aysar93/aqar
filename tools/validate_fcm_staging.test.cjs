const { test } = require('node:test');
const assert = require('node:assert/strict');
const { validate } = require('./validate_fcm_staging.cjs');
const config = { STAGING_PROJECT_ID: 'aqar-fcm-test-example', FCM_MIGRATION: true, STAGING_EMULATORS: false, STAGING_SENDER_ID: '123', STAGING_APP_ID: 'test-app', STAGING_API_KEY: 'test-key' };
const native = { project_info: { project_id: config.STAGING_PROJECT_ID, project_number: '123' }, client: [{ client_info: { android_client_info: { package_name: 'com.andalus.aqar.staging' }, mobilesdk_app_id: 'test-app' }, api_key: [{ current_key: 'test-key' }] }] };
test('accept matched isolated config', () => validate(config, native));
test('reject production and mismatched project, sender and app', () => {
  for (const replacement of [{ STAGING_PROJECT_ID: 'aqar-9f3f9' }, { STAGING_PROJECT_ID: 'aqar-fcm-test-other' }, { STAGING_SENDER_ID: 'other' }, { STAGING_APP_ID: 'other' }, { FCM_MIGRATION: false }]) assert.throws(() => validate({ ...config, ...replacement }, native));
});
