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
const LEGACY_HOSTS=[
 'notification-server-68tstlpxw-aysar93s-projects.vercel.app',
 'notification-server-mnh6zdtym-aysar93s-projects.vercel.app',
 'notification-server-git-main-aysar93s-projects.vercel.app',
];
function assessReversible(snapshot){
 const s=snapshot||{},base=assess(s);
 // Historical presence is intentional in this mode; it is never represented
 // as deletion. Every retained host must instead have an observed deny proof.
 const failures=base.failures.filter(x=>!['historical_deployments_not_retired','git_reintroduction_not_blocked'].includes(x));
 const approved=['dpl_DYZa5Drina73ujWgZdiUnCoKHqCm','dpl_BJ7BcrBbLzNFPywfjzRamajXyKYw',...LEGACY];
 if(!Array.isArray(s.existingDeploymentIds)||s.existingDeploymentIds.some(id=>!approved.includes(id)))failures.push('unknown_ready_deployment');
 if(s.gitLinkRetained!==true||s.ignoredBuildStep!=='exit 0')failures.push('reversible_build_freeze_not_confirmed');
 const rule=s.legacyHostDeny;
 if(!rule||rule.active!==true||rule.action!=='deny'||rule.bypassedBeforeDeny!==false||!Array.isArray(rule.hosts)||rule.hosts.length!==LEGACY_HOSTS.length||!LEGACY_HOSTS.every(h=>rule.hosts.includes(h)))failures.push('exact_legacy_host_deny_not_confirmed');
 if(!LEGACY_HOSTS.every(h=>s.hostReadChecks?.[h]===403))failures.push('legacy_host_block_not_observed');
 if(s.currentAndMaintenanceUnaffected!==true)failures.push('current_or_maintenance_unverified');
 return {readyForReversibleRetirement:failures.length===0,failures,historicalArtifactsRetained:true,permitsFcmActivation:false};
}
module.exports={assess,assessReversible,LEGACY,LEGACY_HOSTS,LEGACY_FUNCTIONS};
if(require.main===module){
 try{const reversible=process.argv.includes('--reversible');const result=(reversible?assessReversible:assess)(JSON.parse(fs.readFileSync(process.argv[2],'utf8')));console.log(JSON.stringify(result,null,2));process.exitCode=(reversible?result.readyForReversibleRetirement:result.readyForPausedRetirement)?0:1;}
 catch{console.error('Readiness evidence missing or invalid; no operation performed');process.exitCode=1;}
}
