'use strict';
require('./loopback-only.cjs');
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
// Emulator HTTP only. No TLS interception or remote targets. Local emulator
// authorization headers are forwarded within loopback but are never logged.
let armed=null, held=[], attempts=0;const events=[];
const event=(name,fields={})=>events.push({event:name,atUtc:new Date().toISOString(),...fields});
const persist=()=>{fs.mkdirSync(path.join(__dirname,'.local'),{recursive:true});fs.writeFileSync(path.join(__dirname,'.local/proxy-events.json'),JSON.stringify({project:'demo-aqar',events},null,2));};
const server=http.createServer((req,res)=>{
  if(req.url==='/__state'&&req.method==='GET')return res.end(JSON.stringify({armed,held:held.length,attempts,events}));
  if(req.url==='/__release'&&req.method==='POST'){
    for(const release of held.splice(0))release();event('RELEASE');persist();return res.end('ok');
  }
  if(req.url==='/__arm'&&req.method==='POST'){
    let raw='';req.on('data',b=>{raw+=b;if(raw.length>2048)req.destroy();});req.on('end',()=>{
      try {const value=JSON.parse(raw);
        if(!['requestBooking','uploadBookingVideoChunk','uploadBookingImage','finishBookingVideo'].includes(value.function)||
           !['cut','hold-response'].includes(value.mode)||
           (value.mode==='cut'&&(!Number.isSafeInteger(value.offset)||value.offset<1)))throw Error();
        armed=value;attempts=0;event('ARM',{function:value.function,mode:value.mode,offset:value.offset});persist();res.end('ok');
      }catch(_){res.writeHead(400);res.end();}
    });return;
  }
  const fn=/^\/demo-aqar\/us-central1\/([A-Za-z]+)(?:\?|$)/.exec(req.url||'')?.[1];
  if(!fn||!['reserveBookingVideo','finishBookingVideo','uploadBookingVideoChunk','uploadBookingImage','requestBooking','bookingMediaContent'].includes(fn)){
    res.writeHead(403);return res.end();
  }
  const rule=armed?.function===fn?armed:null;
  if(rule)attempts++;
  const shouldCut=rule?.mode==='cut'&&attempts===1;
  let received=0,forwarded=0,cut=false;
  const trace=fn==='requestBooking'?crypto.randomUUID():null;
  const requestId=trace?JSON.parse(fs.readFileSync(path.join(__dirname,'.local/native-defines.json'))).BOOKINGS_LOCAL_REQUEST_ID:null;
  const headers={...req.headers,...(trace?{'x-booking-local-trace':trace,'x-booking-local-request-id':requestId}:{})};
  const upstream=http.request({hostname:'127.0.0.1',port:5002,method:req.method,path:req.url,headers},back=>{
    const chunks=[];back.on('data',b=>chunks.push(b));back.on('end',()=>{
      event('BACKEND_RESPONSE',{function:fn,status:back.statusCode,received,forwarded});
      const deliver=()=>{if(!res.destroyed){res.writeHead(back.statusCode,back.headers);res.end(Buffer.concat(chunks));}};
      if(rule?.mode==='hold-response'){held.push(deliver);event('RESPONSE_HELD',{function:fn});persist();}else{deliver();persist();}
    });
  });
  upstream.on('error',()=>{if(!cut&&!res.destroyed){res.writeHead(502);res.end();}});
  req.on('data',b=>{
    received+=b.length;
    if(cut)return;
    if(shouldCut&&forwarded+b.length>=rule.offset){
      const remaining=rule.offset-forwarded;
      if(remaining)upstream.write(b.subarray(0,remaining));forwarded+=remaining;cut=true;
      // Count bytes accepted by the proxy and submitted upstream separately.
      // A write is NOT proof the Functions handler received these bytes.
      const cutFields={function:fn,proxyReceived:received,submittedUpstream:forwarded,declaredLength:Number(req.headers['content-length']||0)};
      if(trace){
        const began=Date.now();
        const waitForReceiver=()=>{
          const file=path.join(__dirname,'.local/ingress-events.jsonl');
          const rows=fs.existsSync(file)?fs.readFileSync(file,'utf8').trim().split('\n').filter(Boolean).map(s=>JSON.parse(s)):[];
          const receipt=rows.find(e=>e.trace===trace&&e.port===5002&&e.event==='RECEIVER_DATA'&&e.receivedBytes===forwarded);
          if(receipt||Date.now()-began>5000){
            event('REQUEST_CUT',{...cutFields,trace,requestId,receiverReceipt:receipt||null});persist();upstream.destroy();req.destroy();res.destroy();
          }else setTimeout(waitForReceiver,20);
        };waitForReceiver();
      }else{event('REQUEST_CUT',cutFields);persist();upstream.destroy();req.destroy();res.destroy();}
    }else{upstream.write(b);forwarded+=b.length;}
  });
  req.on('end',()=>{if(!cut)upstream.end();});
  req.on('aborted',()=>upstream.destroy());
});
server.listen(5001,'127.0.0.1',()=>console.log('Local demo Functions proxy ready on 127.0.0.1:5001'));
process.on('SIGTERM',()=>{persist();server.close();});
