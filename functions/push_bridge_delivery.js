'use strict';
const {deliveryId,oneSignalMessage}=require('./push_bridge_policy');
const {messageFor}=require('./push_policy');
// Dependency injection keeps provider network calls out of emulator tests.
// The store must atomically revalidate recipient/installation and claim one
// event/device key. It must not release ambiguous claims or switch providers.
async function deliverBridge({event,targets,store,sendFcm,sendOneSignal,appId,now=Date.now}) {
 const results=[];
 for(const target of targets) {
  const id=deliveryId(event,target);
  const claim=await store.claim(id,event,target,now());
  if(!claim){results.push({id,status:'skipped'});continue;}
  let response;
  try {
   response=target.provider==='fcm'
    ? await sendFcm({...messageFor(event,target.endpoint),data:{...messageFor(event,target.endpoint).data,eventId:event.key}})
    : await sendOneSignal(oneSignalMessage(event,target,appId));
  } catch(error) {
   // Even timeouts and HTTP 5xx can follow provider acceptance. Never route
   // this event/device through the other provider as an automatic fallback.
   const invalid=['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(error.code);
   await store.finish(id,{status:invalid?'invalid_token':'review_required',errorCode:String(error.code||'provider_unknown').slice(0,80),updatedAtMs:now()});
   results.push({id,status:invalid?'invalid_token':'review_required'});
   continue;
  }
  // Keep acknowledgement persistence outside the send catch. A database error
  // after provider success must leave an attempting claim for reconciliation.
  await store.finish(id,{status:'accepted',providerMessageId:String(response?.id||response).slice(0,256),updatedAtMs:now()});
  results.push({id,status:'accepted'});
 }
 return results;
}
module.exports={deliverBridge};
