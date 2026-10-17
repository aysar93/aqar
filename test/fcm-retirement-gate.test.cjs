'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {assess,LEGACY}=require('../tools/fcm-retirement-gate.cjs');
const valid=()=>({projectId:'prj_DfyjRjfnIZFb7SKyN1EHD4HZfv1X',mode:'paused',percent:0,userIds:[],installations:[],legacyTargets:[],installationAllowlist:[],legacyRecoveryAllowlist:[],fcmSendPermission:false,oldKeysChanged:false,existingDeploymentIds:['dpl_DYZa5Drina73ujWgZdiUnCoKHqCm','dpl_BJ7BcrBbLzNFPywfjzRamajXyKYw'],existingFunctionNames:['deliverBridgeNotification'],gitAutoDeploymentBlocked:true,deploymentHooksBlocked:true,approvedManualDeploymentOnly:true,maintenanceReady:true,canonicalDeploymentId:'dpl_DYZa5Drina73ujWgZdiUnCoKHqCm'});
test('retirement gate refuses historical, direct-function and deployment-trigger bypasses',()=>{
 for(const id of LEGACY)assert.equal(assess({...valid(),existingDeploymentIds:[id]}).readyForPausedRetirement,false);
 for(const name of ['sendNotificationToUser','deliverFcmNotification'])assert.equal(assess({...valid(),existingFunctionNames:[name]}).readyForPausedRetirement,false);
 for(const key of ['gitAutoDeploymentBlocked','deploymentHooksBlocked','approvedManualDeploymentOnly'])assert.equal(assess({...valid(),[key]:false}).readyForPausedRetirement,false);
});
test('retirement gate is fail-closed for unknown evidence, enabled mode, a cohort or send permission',()=>{
 assert.equal(assess().readyForPausedRetirement,false);
 for(const change of [{mode:'fcm'},{percent:1},{userIds:['u']},{installations:[{uid:'u',id:'i'}]},{legacyTargets:[{uid:'u',key:'k'}]},{fcmSendPermission:true},{oldKeysChanged:true},{projectId:'other'},{maintenanceReady:false}])assert.equal(assess({...valid(),...change}).readyForPausedRetirement,false);
});
test('a complete synthetic retirement proof never authorizes FCM activation',()=>{
 const result=assess(valid());assert.equal(result.readyForPausedRetirement,true);assert.equal(result.permitsFcmActivation,false);
});
