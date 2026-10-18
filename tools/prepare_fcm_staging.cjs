// Produces a reviewable bundle, never deploys or authenticates.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const project = process.argv[2];
assert.match(project || '', /^aqar-fcm-test-[a-z0-9-]+$/);
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'work', 'fcm-staging', project);
assert.ok(!fs.existsSync(out), 'Bundle already exists; review it before generating a new one');
fs.mkdirSync(path.join(out, 'functions'), { recursive: true });
for (const file of ['push_functions.js', 'push_policy.js']) fs.copyFileSync(path.join(root, 'functions', file), path.join(out, 'functions', file));
fs.copyFileSync(path.join(root, 'functions/staging/cloud-index.js'), path.join(out, 'functions/index.js'));
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'functions/package.json'), 'utf8'));
pkg.main = 'index.js'; pkg.engines.node = '22'; delete pkg.scripts; delete pkg.devDependencies;
fs.writeFileSync(path.join(out, 'functions/package.json'), JSON.stringify(pkg, null, 2));
// Flag remains disabled until a separate deployment/enablement approval.
fs.writeFileSync(path.join(out, 'functions', `.env.${project}`), 'FCM_MIGRATION_ENABLED=false\n');
fs.copyFileSync(path.join(root, 'firestore.rules'), path.join(out, 'firestore.rules'));
fs.copyFileSync(path.join(root, 'firestore.indexes.json'), path.join(out, 'firestore.indexes.json'));
fs.writeFileSync(path.join(out, 'firebase.json'), JSON.stringify({
  auth: { providers: { anonymous: true } },
  functions: [{ source: 'functions', codebase: 'fcm-staging', runtime: 'nodejs22' }],
  firestore: { rules: 'firestore.rules', indexes: 'firestore.indexes.json' }
}, null, 2));
fs.writeFileSync(path.join(out, '.firebaserc'), JSON.stringify({ projects: { default: project } }, null, 2));
console.log('Prepared isolated bundle:', out);
