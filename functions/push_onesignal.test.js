const {test}=require('node:test'),assert=require('node:assert/strict');
const {providerConfig,verifySubscriptionBinding,sendOneSignal}=require('./push_onesignal');
test('test project cannot address production OneSignal',()=>{
 process.env.GCLOUD_PROJECT='demo-aqar';process.env.BRIDGE_ONESIGNAL_APP_ID='810a4d8d-cfac-492a-956e-0cff98248d25';process.env.BRIDGE_ONESIGNAL_API_KEY='synthetic';
 assert.throws(providerConfig,e=>e.code==='provider_isolation_guard');
});
test('subscription ID alone cannot bind another physical device; secret provider token must match',async()=>{
 const fetch=global.fetch;const os='12345678-1234-4234-a234-123456789abc';
 process.env.BRIDGE_ONESIGNAL_APP_ID='22345678-1234-4234-a234-123456789abc';
 global.fetch=async url=>({ok:true,json:async()=>String(url).endsWith('/identity')?{identity:{onesignal_id:os}}:{subscriptions:[{id:os,token:'provider-secret-token-123456',enabled:true}]}});
 try {
  await assert.rejects(verifySubscriptionBinding({oneSignalId:os,token:'other-token-1234567890',platform:'android'}),e=>e.code==='subscription_unverified');
  await verifySubscriptionBinding({oneSignalId:os,token:'provider-secret-token-123456',platform:'android'});
  await verifySubscriptionBinding({oneSignalId:os,token:'different-fcm-token',platform:'iOS',providerToken:'provider-secret-token-123456'});
  await assert.rejects(sendOneSignal({app_id:process.env.BRIDGE_ONESIGNAL_APP_ID,included_segments:['All']}),e=>e.code==='provider_audience_guard');
 } finally {global.fetch=fetch;}
});
