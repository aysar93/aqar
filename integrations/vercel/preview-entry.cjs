'use strict';
const {initializeApp,getApps,cert}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {createLegacyIngress}=require('./legacy-ingress.cjs');
let ingress;
function initializePreview({credential,db}={}) {
 const project=process.env.GCLOUD_PROJECT;
 const emulator=project==='demo-aqar' && process.env.FIRESTORE_EMULATOR_HOST==='127.0.0.1:8185';
 if(!emulator && project!=='aqar-fcm-test-20261014')throw Error('Exact test project required');
 if(db && db.projectId!==project)throw Error('Mixed database project forbidden');
 if(!getApps().length){
  if(emulator)initializeApp({projectId:project});
  else {
   if(credential)initializeApp({projectId:project,credential});
   else {
    const service=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}');
    if(service.project_id!==project)throw Error('Test-only service account required');
    initializeApp({projectId:project,credential:cert(service)});
   }
  }
 }
 if(getApps()[0].options.projectId!==project)throw Error('Mixed Firebase application forbidden');
 const {internals}=require('./push_bridge_functions');
 const store=db||getFirestore();
 return ingress=createLegacyIngress({db:store,dispatch:event=>internals.dispatchBridge(event,store)});
}
async function handler(req,res) {
 const response={status(code){res.statusCode=code;return this;},json(data){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(data));}};
 if(req.method==='GET' && req.url==='/')return response.status(200).json({service:'isolated-push-bridge-preview',production:false});
 if(req.method!=='POST'||!['/send','/api/index'].includes(req.url?.split('?')[0]))return response.status(404).json({error:'not_found'});
 try {
  if(req.body && Buffer.byteLength(JSON.stringify(req.body),'utf8')>65536)return response.status(413).json({error:'payload_too_large'});
  if(!req.body){let size=0,body='';for await(const chunk of req){size+=chunk.length;if(size>65536)return response.status(413).json({error:'payload_too_large'});body+=chunk;}req.body=JSON.parse(body);}
  ingress ||= initializePreview();
  return await ingress(req,response);
 }catch(error){return response.status(error instanceof SyntaxError?400:503).json({success:false,error:error instanceof SyntaxError?'invalid_json':'isolated_preview_unavailable'});}
}
module.exports={handler,initializePreview};
