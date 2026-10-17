const {test}=require('node:test'),assert=require('node:assert/strict'),{execFileSync}=require('node:child_process');
test('preview shared dispatcher loads when require(esm) is disabled by the host',()=>{
 const output=execFileSync(process.execPath,['--no-experimental-require-module','-e',"require('./functions/push_bridge_dispatch'); if(Object.keys(require.cache).some(p=>p.includes('firebase-admin/lib/auth/')))throw Error('Auth wrapper loaded');console.log('ready');"],{cwd:require('node:path').resolve(__dirname,'../..'),encoding:'utf8'});
 assert.match(output,/ready/);
});
