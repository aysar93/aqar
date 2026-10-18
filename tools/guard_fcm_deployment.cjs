'use strict';
// Repository merge approval does not authorize a production deployment.
if(process.env.FCM_PRODUCTION_DEPLOY_APPROVED!=='independently-approved-paused-only'){
 console.error('FCM_DEPLOYMENT_BLOCKED: independent production approval is required; no deploy command was executed.');process.exitCode=1;
}
