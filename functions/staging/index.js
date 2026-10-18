// Isolated entry point: do not load legacy Functions or external services.
const { initializeApp } = require('firebase-admin/app');
const project = process.env.GCLOUD_PROJECT;
if (project !== 'demo-aqar' || process.env.FUNCTIONS_EMULATOR !== 'true') {
  throw new Error('This entry point is for demo-aqar emulators only; deployment is forbidden.');
}
initializeApp({ projectId: project });
Object.assign(exports, require('../push_functions'));
Object.assign(exports, require('../push_bridge_functions'));
