'use strict';
// Operator tool: exact test project only; no production credentials or payloads.
const fs=require('node:fs'),path=require('node:path');
const base=path.join(process.env.APPDATA||'', 'npm/node_modules/firebase-tools/lib/');
const auth=require(base+'auth'),{Client}=require(base+'apiv2');
(async()=>{
 const project='aqar-fcm-test-20261014',email=process.env.AQAR_TEST_ALERT_EMAIL;
 if(!email||!/^\S+@\S+\.\S+$/.test(email))throw Error('Explicit test alert email required');
 const options={project,nonInteractive:true};auth.setActiveAccount(options,auth.getGlobalDefaultAccount());await require(base+'requireAuth').requireAuth(options);
 const api=new Client({urlPrefix:'https://monitoring.googleapis.com',apiVersion:'v3'}),root='/projects/'+project;
 const existing=(await api.get(root+'/notificationChannels',{skipLog:{resBody:true}})).body.notificationChannels||[];
 let channel=existing.find(c=>c.type==='email'&&c.labels?.email_address===email);
 if(!channel)channel=(await api.post(root+'/notificationChannels',{type:'email',displayName:'Aqar test push operator',labels:{email_address:email},enabled:true},{skipLog:{reqBody:true,resBody:true}})).body;
 const title='Aqar isolated push bridge delivery failures';
 const policies=(await api.get(root+'/alertPolicies',{skipLog:{resBody:true}})).body.alertPolicies||[];
 const filter='resource.type="cloud_run_revision" AND severity>=ERROR AND resource.labels.service_name=~"^(deliverbridgenotification|bridgecommentcreated|bridgereplycreated|bridgechatmessagecreated|registerpushdevice|unregisterpushdevice|monitorpushdeliveryhealth|reviewpushdeliveryhealth)$"';
 const spec={displayName:title,combiner:'OR',enabled:true,notificationChannels:[channel.name],conditions:[{displayName:'Push function failure or stuck delivery detected',conditionMatchedLog:{filter}}],alertStrategy:{notificationRateLimit:{period:'1800s'},autoClose:'1800s'},documentation:{mimeType:'text/markdown',content:'TEST PROJECT ONLY. Inspect review_required or stale attempting deliveries. Pause rollout before investigation. Never blindly resend an ambiguous accepted attempt. Do not put tokens or message bodies in incident notes.'},userLabels:{scope:'isolated-test',system:'aqar-push'}};
 let policy=policies.find(p=>p.displayName===title);
 if(!policy)policy=(await api.post(root+'/alertPolicies',spec,{skipLog:{reqBody:true,resBody:true}})).body;
 const result={project,enabled:policy.enabled,policy:policy.name,channel:channel.name,channelType:channel.type,channelEnabled:channel.enabled,verificationStatus:channel.verificationStatus,notificationRateLimitSeconds:1800,mailReceiptVerified:false,productionChanged:false};
 fs.mkdirSync('local-outputs/bridge-live-20261015',{recursive:true});fs.writeFileSync('local-outputs/bridge-live-20261015/alert-policy.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(e=>{console.error(e.message);process.exitCode=1});
