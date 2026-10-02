const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getDatabase } = require("firebase-admin/database");
const { getApp } = require("firebase-admin/app");

const databaseURL =
  "https://aqar-9f3f9-default-rtdb.asia-southeast1.firebasedatabase.app";

// Only Admin SDK writes this ACL. Never trust a role supplied by the client.
// Reading the current document avoids granting from an out-of-order event.
async function syncPresenceAdmin(uid) {
  const user = await getFirestore().doc(`users/${uid}`).get();
  const allowed = user.exists &&
    user.data().isAdmin === true && user.data().isBlocked !== true;
  await getDatabase(getApp(), getApp().options.databaseURL || databaseURL)
    .ref(`admins/${uid}`).set(allowed ? { presenceDashboard: true, version: 1 } : null);
  return allowed;
}

// Bootstrap an existing admin on demand; no scan/migration of users.
exports.authorizePresenceDashboard = onCall(async (request) => {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "يلزم تسجيل الدخول");
  }
  if (!(await syncPresenceAdmin(request.auth.uid))) {
    throw new HttpsError("permission-denied", "هذه الإحصائيات للمشرف فقط");
  }
  return { authorized: true };
});

// Keep removals, bans, and promotions in sync. Token/profile edits do no I/O.
exports.syncPresenceAdminRole = onDocumentWritten(
  { document: "users/{uid}", retry: true },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    // Ordinary registration/profile/ban events must not create ACL I/O.
    if (before?.isAdmin !== true && after?.isAdmin !== true) return;
    if (before?.isAdmin === after?.isAdmin &&
        before?.isBlocked === after?.isBlocked) return;
    await syncPresenceAdmin(event.params.uid);
  },
);
