// Only the FCM Functions are packaged for the separate test project.
const { initializeApp } = require('firebase-admin/app');
const project = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
if (!/^aqar-fcm-test-[a-z0-9-]+$/.test(project || '')) {
  throw new Error('ISOLATED_FCM_TEST_PROJECT_REQUIRED');
}
initializeApp({ projectId: project });
// Keep the isolated paid test project bounded without permanently warm instances.
require('firebase-functions/v2').setGlobalOptions({ maxInstances: 2, minInstances: 0 });
Object.assign(exports, require('./push_functions'));
