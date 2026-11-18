const fs=require('fs'),vm=require('vm'),assert=require('assert');
const s=fs.readFileSync(require('node:path').resolve(__dirname,'../../functions/chat_functions.js'),'utf8');
const a=s.indexOf('async function removeAttachments('),b=s.indexOf('exports.deleteChatMessage',a);
const ctx={getStorage:()=>{throw Error('Unexpected physical delete')},getFirestore:()=>{throw Error('Unexpected reference assumption')}};
vm.runInNewContext(s.slice(a,b)+'\nretention=removeAttachments;',ctx);
(async()=>{for(const paths of [['uploads/private/chat_images/c/u/a.png'],['gs://unexpected/archive'],['staging/private/archive'],[]]){const v=await ctx.retention('c',paths);assert.equal(v.retained,true)}
console.log('4 backend retention safety checks passed')})().catch(e=>{console.error(e.message);process.exitCode=1});
