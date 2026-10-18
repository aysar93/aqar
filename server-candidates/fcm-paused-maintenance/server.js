'use strict';
// Credential-free recovery artifact. No Firebase, provider or filesystem calls.
function handler(req,res){
 let path;try{path=new URL(req.url,'http://localhost').pathname;}catch{res.statusCode=400;return res.end();}
 res.setHeader('Content-Type','application/json');res.setHeader('Access-Control-Allow-Origin','*');
 res.setHeader('Access-Control-Allow-Headers','Content-Type, Authorization');res.setHeader('Access-Control-Allow-Methods','GET, POST, OPTIONS');
 if(req.method==='OPTIONS'){res.statusCode=204;return res.end();}
 if(req.method==='GET'&&path==='/'){res.statusCode=200;return res.end(JSON.stringify({service:'notification-server',status:'maintenance',mode:'paused',pushSent:false}));}
 if(req.method==='POST'&&path==='/send'){res.statusCode=202;return res.end(JSON.stringify({success:true,mode:'paused',pushSent:false,reason:'paused_maintenance'}));}
 res.statusCode=404;return res.end(JSON.stringify({success:false,error:'not_found'}));
}
module.exports=handler;
if(require.main===module)require('http').createServer(handler).listen(Number(process.env.PORT)||3000);
