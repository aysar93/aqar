'use strict';
// This isolated future codebase has no OneSignal key, binding or network path.
// Existing production OneSignal code/configuration remains untouched.
async function sendOneSignal(){throw Object.assign(Error('OneSignal transport is not configured in trusted inbox'),{code:'transport_not_configured'});}
module.exports={sendOneSignal};
