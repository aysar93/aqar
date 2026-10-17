'use strict';
const TEAM='team_OuMMNqbA3ALsK4nAoBE7UxSe';
const ISSUER='https://oidc.vercel.com/aysar93s-projects';
const PROFILES=Object.freeze({
 isolated:{project:'aqar-fcm-test-20261014',vercelProject:'prj_TsHXMhxKETjzIjUbjXcxEPQDaKxy',environment:'preview',account:'aqar-vercel-keyless-test',pool:'aqar-vercel-paused',provider:'vercel-preview'},
 'production-paused':{project:'aqar-9f3f9',vercelProject:'prj_DfyjRjfnIZFb7SKyN1EHD4HZfv1X',environment:'production',account:'aqar-push-vercel',pool:'aqar-vercel-paused',provider:'vercel-production'}
});
function configuration(env=process.env){
 const name=env.FCM_SERVER_PROFILE||'isolated',profile=PROFILES[name];
 if(!profile||env.GCLOUD_PROJECT!==profile.project||env.VERCEL_ENV!==profile.environment||env.VERCEL_PROJECT_ID!==profile.vercelProject||!/^\d+$/.test(env.GCP_PROJECT_NUMBER||''))throw Error('DEPLOYMENT_CONTEXT_REJECTED');
 if(env.FCM_MIGRATION_ENABLED!=='true'||env.PUSH_BRIDGE_ENABLED!=='true'||env.BRIDGE_ONESIGNAL_ENABLED!=='false')throw Error('PAUSED_CONFIGURATION_REQUIRED');
 return Object.freeze({...profile,name,team:TEAM,issuer:ISSUER,audience:'https://vercel.com/aysar93s-projects',projectNumber:env.GCP_PROJECT_NUMBER,serviceAccount:profile.account+'@'+profile.project+'.iam.gserviceaccount.com'});
}
function validateClaims(token,config){
 let claims;try{claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString('utf8'));}catch{throw Error('OIDC_CONTEXT_REJECTED');}
 if(claims.iss!==config.issuer||claims.aud!==config.audience||claims.owner_id!==config.team||claims.project_id!==config.vercelProject||claims.environment!==config.environment)throw Error('OIDC_CONTEXT_REJECTED');
 // This is a context precheck only. Google STS verifies signature, expiry,
 // issuer/audience and the provider's immutable project/team conditions.
 return token;
}
function makeRuntime(config,{getToken,ExternalAccountClient,GoogleAuth,Firestore,initializeApp,getApps}={}){
 if(!getToken)getToken=require('@vercel/oidc').getVercelOidcToken;
 if(!ExternalAccountClient)({ExternalAccountClient,GoogleAuth}=require('google-auth-library'));
 if(!Firestore)({Firestore}=require('firebase-admin/firestore'));
 if(!initializeApp)({initializeApp,getApps}=require('firebase-admin/app'));
 const authClient=ExternalAccountClient.fromJSON({
  type:'external_account',audience:`//iam.googleapis.com/projects/${config.projectNumber}/locations/global/workloadIdentityPools/${config.pool}/providers/${config.provider}`,
  subject_token_type:'urn:ietf:params:oauth:token-type:jwt',token_url:'https://sts.googleapis.com/v1/token',
  service_account_impersonation_url:`https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${config.serviceAccount}:generateAccessToken`,
  subject_token_supplier:{getSubjectToken:async()=>validateClaims(await getToken(),config)}
 });
 if(!authClient)throw Error('FEDERATED_AUTH_UNAVAILABLE');
 authClient.scopes=['https://www.googleapis.com/auth/cloud-platform'];
 const credential={getAccessToken:async()=>{const result=await authClient.getAccessToken();if(!result?.token)throw Error('FEDERATED_AUTH_UNAVAILABLE');return {access_token:result.token,expires_in:Math.max(1,Math.floor(((authClient.credentials?.expiry_date||Date.now()+300000)-Date.now())/1000))};}};
 if(!getApps().length)initializeApp({projectId:config.project,credential});
 if(getApps()[0].options.projectId!==config.project)throw Error('MIXED_FIREBASE_PROJECT');
 const db=new Firestore({projectId:config.project,auth:new GoogleAuth({authClient}),preferRest:true});
 return {db,authClient};
}
module.exports={configuration,validateClaims,makeRuntime};
