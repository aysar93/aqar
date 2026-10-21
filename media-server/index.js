// Separate media codebase; never imported by the FCM/default production index.
const {onRequest}=require('firebase-functions/v2/https');
const {initializeApp}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getFirestore}=require('firebase-admin/firestore');
const {getStorage}=require('firebase-admin/storage');
const {createPrivateUploadHandler,firestoreQuota}=require('./media_private_upload');
const {createPrivateReadHandler}=require('./media_private_read');
const {createCleanupRequestHandler}=require('./media_cleanup_request');
const app=initializeApp();
const bucketName=process.env.MEDIA_STORAGE_BUCKET;
if(bucketName!=='aqar-9f3f9-media-canary')throw Error('Explicit approved media bucket required');
const db=getFirestore(app),bucket=getStorage(app).bucket(bucketName);
const deps={auth:getAuth(app),db,bucket,authorizeQuota:firestoreQuota(db)};
const options={region:'us-central1',memory:'256MiB',timeoutSeconds:60,maxInstances:1,concurrency:1,cors:false,serviceAccount:'aqar-media-runtime@aqar-9f3f9.iam.gserviceaccount.com'};
exports.uploadMedia=onRequest(options,createPrivateUploadHandler(deps));
exports.readPrivateMedia=onRequest(options,createPrivateReadHandler(deps));

exports.requestMediaCleanup=onRequest(options,createCleanupRequestHandler(deps));
