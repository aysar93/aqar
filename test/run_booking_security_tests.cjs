const {spawnSync}=require('node:child_process');
if(process.env.GCLOUD_PROJECT!=='demo-aqar' || process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185') throw Error('Local demo emulator required');
for(const [cmd,args] of [[process.execPath,['--test','--test-name-pattern=revoked','functions/booking_finance_integrity.integration.test.js']],['python',['-m','unittest','discover','-s','test','-p','booking_rules_test.py','-k','ledger_access']]]) {
  const result=spawnSync(cmd,args,{stdio:'inherit',env:process.env});
  if(result.status!==0) process.exit(result.status || 1);
}
