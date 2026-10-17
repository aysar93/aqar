'use strict';
const express=require('express'),cors=require('cors');
function assertPaused(rollout){
 if(!rollout||rollout.mode!=='paused'||rollout.percent!==0||rollout.legacyIngressCoordinated!==false||!Array.isArray(rollout.installationAllowlist)||rollout.installationAllowlist.length||!Array.isArray(rollout.legacyRecoveryAllowlist)||rollout.legacyRecoveryAllowlist.length)throw Error('PAUSED_INVARIANT_REQUIRED');
 const c=rollout.cohort;if(!c||!['userIds','installations','legacyTargets'].every(k=>Array.isArray(c[k])&&c[k].length===0)||JSON.stringify(c.providers)!=='["fcm"]')throw Error('EMPTY_COHORT_REQUIRED');
 return rollout;
}
function createApp({getRuntime,dispatch,createIngress=require('./legacy-ingress.cjs').createLegacyIngress,onError=()=>{}}){
 const app=express();app.use(cors());app.use(express.json({limit:'64kb'}));
 async function context(){const {db}=await getRuntime();assertPaused((await db.doc('push_bridge_config/rollout').get()).data());return db;}
 app.get('/',async(_req,res)=>{try{await context();res.json({service:'notification-server',status:'ready',mode:'paused',pushSent:false});}catch(error){onError(error);res.status(503).json({success:false,error:'paused_server_unavailable'});}});
 app.post('/send',async(req,res)=>{
  const id=req.body?.notificationId||req.body?.data?.notificationId;
  if(typeof id!=='string'||!id||id.length>128||id.includes('/'))return res.status(400).json({success:false,error:'notification_id_required'});
  try{const db=await context();const ingress=createIngress({db,dispatch:async event=>{assertPaused((await db.doc('push_bridge_config/rollout').get()).data());return dispatch(event,db);}});return await ingress(req,res);}catch(error){onError(error);return res.status(503).json({success:false,error:'paused_server_unavailable'});}
 });
 app.use((_req,res)=>res.status(404).json({success:false,error:'not_found'}));
 app.use((error,_req,res,_next)=>{const clientError=['entity.too.large','entity.parse.failed'].includes(error.type);if(!clientError)onError(error);return res.status(error.type==='entity.too.large'?413:error.type==='entity.parse.failed'?400:503).json({success:false,error:error.type==='entity.too.large'?'payload_too_large':error.type==='entity.parse.failed'?'invalid_json':'paused_server_unavailable'});});
 return app;
}
module.exports={assertPaused,createApp};
