'use strict';
// Offline readiness gate. It performs no cloud mutation and grants no access.
// A passing synthetic fixture is not evidence of a completed production change.
const fs=require('node:fs');
const LEGACY=['dpl_G7NLNBc8zX539QN46FnNJhss8EJN','dpl_EwEDSV3vYPb3wbgQA9mzXXq1tDf7'];
const LEGACY_FUNCTIONS=['sendNotificationToUser','deliverFcmNotification'];
function assess(snapshot){
 const s=snapshot||{},failures=[];
 if(s.projectId!=='prj_DfyjRjfnIZFb7SKyN1EHD4HZfv1X')failures.push('wrong_project');
 if(s.mode!=='paused'||s.percent!==0)failures.push('not_paused');
 for(const key of ['userIds','installations','legacyTargets','installationAllowlist','legacyRecoveryAllowlist'])if(!Array.isArray(s[key])||s[key].length)failures.push('nonempty_or_unknown_'+key);
 if(s.fcmSendPermission!==false)failures.push('fcm_permission_not_absent');
 if(s.oldKeysChanged!==false)failures.push('old_keys_changed_or_unknown');
 if(!Array.isArray(s.existingDeploymentIds)||LEGACY.some(id=>s.existingDeploymentIds?.includes(id)))failures.push('historical_deployments_not_retired');
 if(!Array.isArray(s.existingFunctionNames)||LEGACY_FUNCTIONS.some(name=>s.existingFunctionNames?.includes(name)))failures.push('direct_functions_not_retired');
 if(s.gitAutoDeploymentBlocked!==true)failures.push('git_reintroduction_not_blocked');
 if(s.deploymentHooksBlocked!==true)failures.push('deployment_hooks_not_accounted_for');
 if(s.approvedManualDeploymentOnly!==true)failures.push('manual_deployment_policy_not_confirmed');
 if(s.maintenanceReady!==true||s.canonicalDeploymentId!=='dpl_DYZa5Drina73ujWgZdiUnCoKHqCm')failures.push('paused_rollback_or_canonical_not_confirmed');
 return {readyForPausedRetirement:failures.length===0,failures,permitsFcmActivation:false};
}
module.exports={assess,LEGACY,LEGACY_FUNCTIONS};
if(require.main===module){
 try{const result=assess(JSON.parse(fs.readFileSync(process.argv[2],'utf8')));console.log(JSON.stringify(result,null,2));process.exitCode=result.readyForPausedRetirement?0:1;}
 catch{console.error('Readiness evidence missing or invalid; no operation performed');process.exitCode=1;}
}
