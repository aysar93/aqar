const {spawnSync}=require('node:child_process');
for(const [command,args] of [[process.execPath,['--test','--test-concurrency=1','functions/booking_functions.integration.test.js','functions/booking_external_media.integration.test.js','functions/booking_legacy_external_media.integration.test.js','functions/payment_accounts.integration.test.js','test/firestore/payment_accounts.test.cjs','test/firestore/booking_banners.test.cjs']],['python',['test/booking_rules_test.py']]]) {
  const result=spawnSync(command,args,{stdio:'inherit',env:process.env});
  if(result.status!==0)process.exit(result.status||1);
}
