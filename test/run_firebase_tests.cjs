// Run through emulators:exec with firebase.release-test.json and demo-aqar.
const {spawnSync} = require('node:child_process');
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185' ||
    process.env.FIREBASE_DATABASE_EMULATOR_HOST !== '127.0.0.1:9195' ||
    process.env.GCLOUD_PROJECT !== 'demo-aqar') {
  throw new Error('ISOLATED_DEMO_EMULATORS_REQUIRED');
}
const suites = [
  ['python', ['test/firestore_activity_rules_test.py']],
  ['python', ['test/firestore_office_gift_rules_test.py']],
  [process.execPath, ['--test', 'functions/analytics_presence_access.integration.test.js',
    'functions/office_counters.integration.test.js', 'test/firestore_query_pagination.integration.cjs']],
  [process.execPath, ['--test', 'test/structured_catalog_pagination.integration.cjs']],
  [process.execPath, ['--test', 'test/office_followers_security.integration.cjs']],
];
for (const [command, args] of suites) {
  const result = spawnSync(command, args, {stdio: 'inherit', env: process.env});
  if (result.status !== 0) process.exit(result.status || 1);
}
