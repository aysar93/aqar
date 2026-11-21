'use strict';
require('./loopback-only.cjs');
const test=require('node:test'),assert=require('node:assert/strict'),net=require('node:net');

test('new Node guard rejects external TCP before socket creation',()=>{
 assert.throws(()=>net.createConnection({host:'example.invalid',port:443}),/LOCAL_TEST_NON_LOOPBACK_BLOCKED/);
});
test('new Node guard rejects external fetch before transport',()=>{
 assert.throws(()=>fetch('https://example.invalid/no-request'),/LOCAL_TEST_NON_LOOPBACK_BLOCKED/);
});
test('CLI unspecified connect address is rewritten to real loopback',async()=>{
 let remote;
 const server=net.createServer(socket=>{remote=socket.remoteAddress;socket.end('ok');});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 try{
  await new Promise((resolve,reject)=>{
   const client=net.createConnection({host:'0.0.0.0',port:server.address().port});
   client.on('data',()=>{});client.on('end',resolve);client.on('error',reject);
  });
  assert.equal(remote,'127.0.0.1');
 }finally{await new Promise(resolve=>server.close(resolve));}
});
test('Windows local emulator worker named pipe remains usable', {skip:process.platform!=='win32'},async()=>{
 const pipe='\\\\?\\pipe\\booking_local_guard_'+process.pid;
 const server=net.createServer(socket=>socket.end('ok'));
 await new Promise(resolve=>server.listen(pipe,resolve));
 try{
  let result='';await new Promise((resolve,reject)=>{
   const client=net.createConnection(pipe);client.on('data',b=>result+=b);
   client.on('end',resolve);client.on('error',reject);
  });assert.equal(result,'ok');
 }finally{await new Promise(resolve=>server.close(resolve));}
});
