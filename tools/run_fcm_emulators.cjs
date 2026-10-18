const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const env = { ...process.env, GCLOUD_PROJECT: 'demo-aqar', FCM_MIGRATION_ENABLED: 'true', FUNCTIONS_DISCOVERY_TIMEOUT: '60' };
delete env.GOOGLE_APPLICATION_CREDENTIALS;
delete env.FIREBASE_TOKEN;
const result = spawnSync(process.platform === 'win32' ? 'firebase.cmd' : 'firebase', [
    'emulators:exec', '--project', 'demo-aqar', '--config', 'firebase.fcm-emulators.json',
    '--only', 'auth,firestore,functions',
    process.platform === 'win32' ? '"node --test functions/staging/emulator.test.cjs"' : 'node --test functions/staging/emulator.test.cjs'
  ], { cwd: root, env, stdio: 'inherit', shell: process.platform === 'win32' });
process.exitCode = result.status ?? 1;
