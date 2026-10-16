'use strict';
const {subscriptionId}=require('./push_bridge_policy');
const {defineSecret}=require('firebase-functions/params');
const apiKeySecret=defineSecret('BRIDGE_ONESIGNAL_API_KEY');
const providerSecretOptions=()=>process.env.PUSH_BRIDGE_ENABLED==='true'?{secrets:[apiKeySecret]}:{};
const PRODUCTION_APP='810a4d8d-cfac-492a-956e-0cff98248d25';
function providerConfig() {
 const project=process.env.GCLOUD_PROJECT,appId=process.env.BRIDGE_ONESIGNAL_APP_ID,key=process.env.BRIDGE_ONESIGNAL_API_KEY;
 if(!subscriptionId(appId)||!key)throw Object.assign(Error('OneSignal bridge is not configured'),{code:'provider_not_configured'});
 if(project!=='aqar-9f3f9' && appId===PRODUCTION_APP)throw Object.assign(Error('Production OneSignal forbidden outside production'),{code:'provider_isolation_guard'});
 return {appId,key};
}
async function providerRequest(path,{method='GET',body}={}) {
 const {key}=providerConfig();
 const response=await fetch('https://api.onesignal.com'+path,{method,headers:{Authorization:'Key '+key,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(10000)});
 if(!response.ok)throw Object.assign(Error('OneSignal request rejected'),{code:'onesignal_http_'+response.status});
 return response.json();
}
async function verifySubscriptionBinding({oneSignalId,token,platform,providerToken}) {
 const {appId}=providerConfig();
 const result=await providerRequest(`/apps/${appId}/subscriptions/${oneSignalId}/user/identity`);
 const id=result.identity?.onesignal_id;
 if(!subscriptionId(id))throw Object.assign(Error('Unverified subscription'),{code:'subscription_unverified'});
 const user=await providerRequest(`/apps/${appId}/users/by/onesignal_id/${id}`);
 const subscription=user.subscriptions?.find(x=>x.id===oneSignalId);
 const expected=platform==='iOS'?providerToken:token;
 if(typeof expected!=='string'||expected.length<20||expected.length>4096||subscription?.token!==expected||subscription.enabled===false)throw Object.assign(Error('Subscription token mismatch'),{code:'subscription_unverified'});
}
async function sendOneSignal(message) {
 const {appId}=providerConfig();
 if(message.app_id!==appId||message.include_subscription_ids?.length!==1)throw Object.assign(Error('Audience guard'),{code:'provider_audience_guard'});
 const result=await providerRequest('/notifications?c=push',{method:'POST',body:message});
 if(!result.id)throw Object.assign(Error('Provider did not acknowledge a notification'),{code:'onesignal_no_ack'});
 return result;
}
module.exports={providerConfig,verifySubscriptionBinding,sendOneSignal,providerSecretOptions};
