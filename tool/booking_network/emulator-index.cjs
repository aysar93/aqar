'use strict';
if (process.env.GCLOUD_PROJECT !== 'demo-aqar' ||
    process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099' ||
    !['127.0.0.1:9198','http://127.0.0.1:9198'].includes(process.env.FIREBASE_STORAGE_EMULATOR_HOST)) {
  throw Error('LOCAL_EMULATORS_REQUIRED');
}
require('./loopback-only.cjs');
const dependency = require('node:module').createRequire(require('node:path').resolve(__dirname,'../../functions/package.json'));
dependency('firebase-admin/app').initializeApp({
  projectId:'demo-aqar', storageBucket:'demo-aqar.appspot.com',
});
// Load original implementation; export no scheduler or unrelated trigger.
const media = require('../../functions/booking_external_media');
const gateway = require('../../functions/booking_media_gateway');
for (const name of ['reserveBookingVideo','finishBookingVideo','uploadBookingImage']) exports[name] = media[name];
exports.uploadBookingVideoChunk = gateway.uploadBookingVideoChunk;
exports.bookingMediaContent = gateway.bookingMediaContent;
exports.requestBooking = require('../../functions/booking_functions').requestBooking;
