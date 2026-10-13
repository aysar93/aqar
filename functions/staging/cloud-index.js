// Only the FCM Functions are packaged for the separate test project.
const { initializeApp } = require('firebase-admin/app');
const project = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
if (!/^aqar-fcm-test-[a-z0-9-]+$/.test(project || '')) {
  throw new Error('ISOLATED_FCM_TEST_PROJECT_REQUIRED');
}
initializeApp({ projectId: project });
Object.assign(exports, require('./push_functions'));
