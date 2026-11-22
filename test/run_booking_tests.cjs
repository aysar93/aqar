const {spawnSync}=require('node:child_process');
const path=require('node:path');
const nodePath=[path.resolve(__dirname,'../functions/node_modules'),'D:\\Projects\\aqar-unified-wt\\functions\\node_modules',process.env.NODE_PATH].filter(Boolean).join(path.delimiter);
const env={...process.env,NODE_PATH:nodePath};
for(const [command,args] of [[process.execPath,['--test','--test-concurrency=1','functions/booking_functions.integration.test.js','functions/booking_cycle_gaps.integration.test.js','functions/booking_finance_integrity.integration.test.js','functions/booking_checkout_recovery.integration.test.js','functions/booking_chat_recovery.integration.test.js','functions/booking_external_media.integration.test.js','functions/booking_legacy_external_media.integration.test.js','functions/payment_accounts.integration.test.js','test/firestore/payment_accounts.test.cjs','test/firestore/booking_banners.test.cjs']],['python',['test/booking_rules_test.py']]]) {
  const result=spawnSync(command,args,{stdio:'inherit',env});
  if(result.status!==0)process.exit(result.status||1);
}
