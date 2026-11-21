'use strict';
// Observe actual bytes emitted by the local Emulator HTTP receiver. Never log bodies/credentials.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
if(process.env.GCLOUD_PROJECT!=='demo-aqar')throw Error('DEMO_PROJECT_REQUIRED');
const destination=process.env.BOOKING_LOCAL_INGRESS_LOG;
if(!destination||!path.isAbsolute(destination))throw Error('LOCAL_INGRESS_LOG_REQUIRED');
const emit=http.Server.prototype.emit;
http.Server.prototype.emit=function(name,...args){
 if(name==='request'){
  const req=args[0],trace=req.headers['x-booking-local-trace'],requestId=req.headers['x-booking-local-request-id'];
  if(typeof trace==='string'&&/^[a-f0-9-]{36}$/.test(trace)&&typeof requestId==='string'&&/^native_[a-f0-9]+$/.test(requestId)){
   let bytes=0;
   const record=event=>fs.appendFileSync(destination,JSON.stringify({event,atUtc:new Date().toISOString(),pid:process.pid,port:req.socket.localPort,trace,requestId,receivedBytes:bytes,declaredBytes:Number(req.headers['content-length']),complete:req.complete})+'\n');
   record('RECEIVER_HEADERS');req.on('data',chunk=>{bytes+=chunk.length;record('RECEIVER_DATA');});req.on('end',()=>record('RECEIVER_END'));req.on('aborted',()=>record('RECEIVER_ABORTED'));
  }
 }
 return emit.call(this,name,...args);
};
