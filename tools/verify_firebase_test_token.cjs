// Diagnostic only: read an isolated test token via stdin, never log its value.
const {initializeApp}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
initializeApp({projectId:'aqar-media-test-20261018'});
let token='';process.stdin.setEncoding('utf8');process.stdin.on('data',x=>token+=x);
process.stdin.on('end',async()=>{try{const c=await getAuth().verifyIdToken(token.trim(),false);console.log(JSON.stringify({validSignatureAndTime:true,project:c.aud,expiresUnix:c.exp,revocationChecked:false}));}catch(e){console.log(JSON.stringify({validSignatureAndTime:false,errorCode:/^auth\/[a-z-]+$/.test(e.code||'')?e.code:'unknown',revocationChecked:false}));}finally{token='';}});
