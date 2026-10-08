const {spawnSync}=require('node:child_process');
for(const [command,args] of [[process.execPath,['--test','functions/booking_functions.integration.test.js']],['python',['test/booking_rules_test.py']]]) {
  const result=spawnSync(command,args,{stdio:'inherit',env:process.env});
  if(result.status!==0)process.exit(result.status||1);
}
