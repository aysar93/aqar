const fs = require('node:fs');
const assert = require('node:assert/strict');
// Check before any native build. No credentials or configuration values are logged.
function validate(config, android) {
  assert.match(config.STAGING_PROJECT_ID, /^aqar-fcm-test-[a-z0-9-]+$/);
  assert.equal(config.FCM_MIGRATION, true);
  assert.equal(config.STAGING_EMULATORS, false);
  assert.equal(android.project_info.project_id, config.STAGING_PROJECT_ID);
  assert.equal(String(android.project_info.project_number), config.STAGING_SENDER_ID);
  const client = android.client.find(c => c.client_info.android_client_info.package_name === 'com.andalus.aqar.staging');
  assert.ok(client, 'Distinct staging application ID required');
  assert.equal(client.client_info.mobilesdk_app_id, config.STAGING_APP_ID);
  assert.ok(client.api_key.some(k => k.current_key === config.STAGING_API_KEY));
}
module.exports = { validate };
if (require.main === module) {
  validate(JSON.parse(fs.readFileSync(process.argv[2], 'utf8')), JSON.parse(fs.readFileSync('android/app/google-services.json', 'utf8')));
  console.log('Isolated Android staging configuration verified');
}
