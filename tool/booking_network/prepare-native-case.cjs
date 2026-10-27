'use strict';
require('./loopback-only.cjs');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const kind=process.argv[2];if(!['N3','S3_KILL','V5A'].includes(kind))throw Error('Local case required');
const dep=require('node:module').createRequire(path.resolve(__dirname,'../../functions/package.json'));
Object.assign(process.env,{GCLOUD_PROJECT:'demo-aqar',FIRESTORE_EMULATOR_HOST:'127.0.0.1:8185',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:9099'});
const {initializeApp,deleteApp}=dep('firebase-admin/app'),{getFirestore}=dep('firebase-admin/firestore');
(async()=>{const app=initializeApp({projectId:'demo-aqar'});try{
const file=path.join(__dirname,'.local/native-defines.json'),f=JSON.parse(fs.readFileSync(file)),db=getFirestore();
const old=await db.doc('booking_venues/'+f.BOOKINGS_LOCAL_VENUE).get();if(!old.exists)throw Error('Fixture missing');
f.BOOKINGS_LOCAL_VENUE='native_case_'+kind.toLowerCase()+'_'+crypto.randomUUID().replaceAll('-','');
await db.doc('booking_venues/'+f.BOOKINGS_LOCAL_VENUE).set({...old.data(),mediaPaths:[]});
f.BOOKING_CASE=kind;f.BOOKINGS_LOCAL_REQUEST_ID='native_'+crypto.randomUUID().replaceAll('-','');f.BOOKINGS_LOCAL_START=Date.now()+48*3600000;
fs.writeFileSync(file,JSON.stringify(f),{mode:0o600});console.log('Fresh isolated demo venue ready for '+kind+'; private values omitted');
}finally{await deleteApp(app);}})().catch(()=>{console.error('LOCAL_CASE_PREPARATION_FAILED');process.exitCode=1;});
