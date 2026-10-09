const {spawnSync}=require('node:child_process');
if(process.env.GCLOUD_PROJECT!=='demo-aqar' || process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185' || process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:9198' || process.env.FIREBASE_DATABASE_EMULATOR_HOST!=='127.0.0.1:9195') throw Error('Isolated demo emulators required');
for(const args of [
  ['test/run_booking_tests.cjs'],
  ['test/run_firebase_tests.cjs'],
  ['--test','--test-concurrency=1','functions/chat_functions.integration.test.js','test/firestore/featured_properties.test.cjs'],
]) {
  const result=spawnSync(process.execPath,args,{stdio:'inherit',env:process.env});
  if(result.status!==0)process.exit(result.status || 1);
}
