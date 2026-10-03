const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getDatabase } = require("firebase-admin/database");
const { getApp } = require("firebase-admin/app");

const databaseURL =
  "https://aqar-9f3f9-default-rtdb.asia-southeast1.firebasedatabase.app";

// Only Admin SDK writes this ACL. Never trust a role supplied by the client.
// Reading the current document avoids granting from an out-of-order event.
async function syncPresenceAdmin(uid, afterRead, deletedRevision) {
  const user = await getFirestore().doc(`users/${uid}`).get();
  const allowed = user.exists &&
    user.data().isAdmin === true && user.data().isBlocked !== true;
  // Use a stable server document revision, not a new readTime on each retry.
  // A deletion denies the last existing revision; denial wins equal revisions.
  // An absent-document callable has no deletion event, so uses server readTime.
  const revision = user.exists ? user.updateTime : (deletedRevision || user.readTime);
  const checkedAt = revision.seconds * 1000000 +
    Math.floor(revision.nanoseconds / 1000);
  if (afterRead) await afterRead(); // Deterministic concurrency test seam.
  await getDatabase(getApp(), getApp().options.databaseURL || databaseURL)
    .ref(`admins/${uid}`).transaction((current) => {
      if (Number(current?.checkedAt || 0) > checkedAt) return;
      if (current?.checkedAt === checkedAt &&
          current.presenceDashboard === false && allowed) return;
      if (current?.checkedAt === checkedAt && current.version === 1 &&
          current.presenceDashboard === allowed) return;
      return { presenceDashboard: allowed, version: 1, checkedAt };
    });
  return allowed;
}

// Bootstrap an existing admin on demand; no scan/migration of users.
exports.authorizePresenceDashboard = onCall({ maxInstances: 3, timeoutSeconds: 30 }, async (request) => {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "يلزم تسجيل الدخول");
  }
  if (!(await syncPresenceAdmin(request.auth.uid))) {
    throw new HttpsError("permission-denied", "هذه الإحصائيات للمشرف فقط");
  }
  return { authorized: true };
});

// Keep removals, bans, and promotions in sync. Token/profile edits do no I/O.
// Retrying a failed revocation is necessary while RTDB trusts this server ACL.
// Replays of the same document revision abort without an ACL write.
exports.syncPresenceAdminRole = onDocumentWritten(
  { document: "users/{uid}", retry: true, maxInstances: 3, timeoutSeconds: 30 },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    // Ordinary registration/profile/ban events must not create ACL I/O.
    const wasAdmin = before?.isAdmin === true;
    const isAdmin = after?.isAdmin === true;
    if (!wasAdmin && !isAdmin) return;
    if (wasAdmin === isAdmin &&
        (before?.isBlocked === true) === (after?.isBlocked === true)) return;
    await syncPresenceAdmin(event.params.uid, undefined,
      after === undefined ? event.data.before.updateTime : undefined);
  },
);

// Helper only, not a deployed endpoint (non-enumerable export).
Object.defineProperty(exports, "syncPresenceAdminForTest", { value: syncPresenceAdmin });
