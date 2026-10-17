'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {assessReversible,LEGACY,LEGACY_HOSTS}=require('../tools/fcm-retirement-gate.cjs');
const valid=()=>({projectId:'prj_DfyjRjfnIZFb7SKyN1EHD4HZfv1X',mode:'paused',percent:0,userIds:[],installations:[],legacyTargets:[],installationAllowlist:[],legacyRecoveryAllowlist:[],fcmSendPermission:false,oldKeysChanged:false,existingDeploymentIds:[...LEGACY,'dpl_DYZa5Drina73ujWgZdiUnCoKHqCm','dpl_BJ7BcrBbLzNFPywfjzRamajXyKYw'],existingFunctionNames:['deliverBridgeNotification'],deploymentHooksBlocked:true,approvedManualDeploymentOnly:true,maintenanceReady:true,canonicalDeploymentId:'dpl_DYZa5Drina73ujWgZdiUnCoKHqCm',gitLinkRetained:true,ignoredBuildStep:'exit 0',legacyHostDeny:{active:true,action:'deny',bypassedBeforeDeny:false,hosts:LEGACY_HOSTS.slice()},hostReadChecks:Object.fromEntries(LEGACY_HOSTS.map(h=>[h,403])),currentAndMaintenanceUnaffected:true});
test('retained deployments can meet a reversible retirement proof without enabling FCM',()=>{
 const result=assessReversible(valid());assert.equal(result.readyForReversibleRetirement,true);assert.equal(result.historicalArtifactsRetained,true);assert.equal(result.permitsFcmActivation,false);
});
test('reversible retirement rejects collateral blocks, bypasses and unverified controls',()=>{
 for(const changes of [{ignoredBuildStep:null},{gitLinkRetained:false},{legacyHostDeny:{...valid().legacyHostDeny,hosts:[...LEGACY_HOSTS,'notification-server-henna.vercel.app']}},{legacyHostDeny:{...valid().legacyHostDeny,bypassedBeforeDeny:true}},{hostReadChecks:{}},{currentAndMaintenanceUnaffected:false},{existingDeploymentIds:[...valid().existingDeploymentIds,'unreviewed-ready-deployment']},{userIds:['u']},{fcmSendPermission:true}])assert.equal(assessReversible({...valid(),...changes}).readyForReversibleRetirement,false);
 const rule=require('../server-candidates/notification-retirement-controls/legacy-host-deny.proposed.json');
 assert.deepEqual(rule.conditionGroup.map(g=>g.conditions[0].value).sort(),LEGACY_HOSTS.slice().sort());
 assert(rule.conditionGroup.every(g=>g.conditions.length===1&&g.conditions[0].type==='host'&&g.conditions[0].op==='eq'));
});
