'use strict';
// Refresh only the disposable Firebase test bundle. Never deploy implicitly.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),project='aqar-fcm-test-20261014';
const out=path.join(root,'work','fcm-staging',project);
const config=JSON.parse(fs.readFileSync(path.join(out,'.firebaserc')));
if(config.projects.default!==project)throw Error('Exact isolated project required');
for(const file of ['push_functions.js','push_policy.js','push_bridge_policy.js','push_bridge_functions.js','push_bridge_delivery.js','push_onesignal.js','package-lock.json'])fs.copyFileSync(path.join(root,'functions',file),path.join(out,'functions',file));
const pkg=JSON.parse(fs.readFileSync(path.join(root,'functions/package.json')));pkg.engines.node='22';delete pkg.scripts;
fs.writeFileSync(path.join(out,'functions/package.json'),JSON.stringify(pkg,null,2));
fs.writeFileSync(path.join(out,'functions/index.js'),`const {initializeApp}=require('firebase-admin/app');
if((process.env.GCLOUD_PROJECT||process.env.GOOGLE_CLOUD_PROJECT)!=='${project}')throw Error('EXACT_TEST_PROJECT_REQUIRED');
initializeApp({projectId:'${project}'});
require('firebase-functions/v2').setGlobalOptions({maxInstances:2,minInstances:0});
Object.assign(exports,require('./push_functions'),require('./push_bridge_functions'));
`);
fs.writeFileSync(path.join(out,'functions','.env.'+project),'FCM_MIGRATION_ENABLED=true\nPUSH_BRIDGE_ENABLED=true\n');
for(const file of ['firestore.rules','firestore.indexes.json'])fs.copyFileSync(path.join(root,file),path.join(out,file));
console.log(JSON.stringify({prepared:out,project,deployed:false,oneSignalProductionCredentialsIncluded:false}));
