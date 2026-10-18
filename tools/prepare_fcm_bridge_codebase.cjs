'use strict';
// Offline packaging only: never invokes Firebase, IAM or a provider.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const files=['push_functions.js','push_bridge_functions.js','push_bridge_policy.js','push_bridge_dispatch.js','push_bridge_delivery.js','push_policy.js','push_onesignal.js','source-authorization.cjs'];
function prepare(root=path.resolve(__dirname,'..'),destination=path.join(root,'build/fcm-bridge-source')){
 if(path.resolve(destination)!==path.join(root,'build/fcm-bridge-source'))throw Error('FIXED_LOCAL_BUILD_DIRECTORY_REQUIRED');
 fs.mkdirSync(destination,{recursive:true});
 const hashes={};for(const name of files){let content=fs.readFileSync(path.join(root,'functions',name),'utf8');
  if(name==='push_bridge_functions.js')content=content.replaceAll("document:'notifications/{notificationId}',retry:","document:'notifications/{notificationId}',serviceAccount:'aqar-push-events@aqar-9f3f9.iam.gserviceaccount.com',retry:").replaceAll("document:'properties/{propertyId}/comments/{commentId}',retry:","document:'properties/{propertyId}/comments/{commentId}',serviceAccount:'aqar-push-events@aqar-9f3f9.iam.gserviceaccount.com',retry:").replaceAll("document:'properties/{propertyId}/comments/{commentId}/replies/{replyId}',retry:","document:'properties/{propertyId}/comments/{commentId}/replies/{replyId}',serviceAccount:'aqar-push-events@aqar-9f3f9.iam.gserviceaccount.com',retry:").replaceAll("document:'chats/{chatId}/messages/{messageId}',retry:","document:'chats/{chatId}/messages/{messageId}',serviceAccount:'aqar-push-events@aqar-9f3f9.iam.gserviceaccount.com',retry:");
  fs.writeFileSync(path.join(destination,name),content);hashes[name]=crypto.createHash('sha256').update(content).digest('hex');
 }
 for(const name of ['package.json','package-lock.json'])fs.copyFileSync(path.join(root,'functions',name),path.join(destination,name));
 const pkg=JSON.parse(fs.readFileSync(path.join(destination,'package.json'),'utf8'));delete pkg.scripts;fs.writeFileSync(path.join(destination,'package.json'),JSON.stringify(pkg,null,2)+'\n');
 fs.mkdirSync(path.join(destination,'trusted_inbox/shared'),{recursive:true});
 fs.copyFileSync(path.join(root,'functions/trusted_inbox/core.js'),path.join(destination,'trusted_inbox/core.js'));
 fs.copyFileSync(path.join(root,'functions/trusted_inbox/shared/push_policy.js'),path.join(destination,'trusted_inbox/shared/push_policy.js'));
 fs.writeFileSync(path.join(destination,'index.js'),`'use strict';
const project='aqar-9f3f9';
if((process.env.GCLOUD_PROJECT||process.env.GOOGLE_CLOUD_PROJECT)!==project)throw Error('EXACT_PRODUCTION_PROJECT_REQUIRED');
require('firebase-admin/app').initializeApp({projectId:project});
require('firebase-functions/v2').setGlobalOptions({region:'us-central1',serviceAccount:'aqar-push-runtime@'+project+'.iam.gserviceaccount.com',minInstances:0,maxInstances:2});
const registration=require('./push_functions');
exports.registerPushDevice=registration.registerPushDevice;
exports.unregisterPushDevice=registration.unregisterPushDevice;
Object.assign(exports,require('./push_bridge_functions'));
`);
 const manifest={offlineOnly:true,codebase:'push-bridge',sourceFiles:hashes,functions:['registerPushDevice','unregisterPushDevice','deliverBridgeNotification','bridgeCommentCreated','bridgeReplyCreated','bridgeChatMessageCreated','reviewPushDeliveryHealth','monitorPushDeliveryHealth'],futureTrustedInboxDeployed:false,credentialsCopied:false};
 fs.writeFileSync(path.join(destination,'source-manifest.json'),JSON.stringify(manifest,null,2)+'\n');return manifest;
}
if(require.main===module)console.log(JSON.stringify(prepare()));
module.exports={prepare};
