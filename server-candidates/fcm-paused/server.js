'use strict';
const {configuration,makeRuntime}=require('./keyless-auth.cjs');
const {createApp}=require('./app.cjs');
const {dispatchBridge}=require('./push_bridge_dispatch');
let runtime;
const app=createApp({getRuntime:async()=>runtime||=(makeRuntime(configuration())),dispatch:dispatchBridge,
 onError:error=>console.error({message:'paused_keyless_server_failed',code:['DEPLOYMENT_CONTEXT_REJECTED','PAUSED_CONFIGURATION_REQUIRED','OIDC_CONTEXT_REJECTED','PAUSED_INVARIANT_REQUIRED','EMPTY_COHORT_REQUIRED','FEDERATED_AUTH_UNAVAILABLE','MIXED_FIREBASE_PROJECT'].includes(error.message)?error.message:'request_unavailable'})});
module.exports=app;
if(require.main===module)app.listen(Number(process.env.PORT)||3000);
