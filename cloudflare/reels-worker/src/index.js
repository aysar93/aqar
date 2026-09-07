const counters = {
  view: "views",
  completion: "completions",
  share: "shares",
  propertyClick: "propertyClicks",
  officeClick: "officeClicks",
  externalClick: "externalClicks",
};

let cachedGoogleToken;

export default {
  async fetch(request, env) {
    const headers = corsHeaders(request);
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        return json({ ok: true, service: "aqar-reels-api" }, 200, headers);
      }
      if (request.method !== "POST") return json({ error: "not_found" }, 404, headers);
      if (url.pathname === "/upload") return upload(request, env, url, headers);
      if (url.pathname === "/event") return recordEvent(request, env, headers);
      if (url.pathname === "/interaction") return interaction(request, env, headers);
      if (url.pathname === "/report") return report(request, env, headers);
      return json({ error: "not_found" }, 404, headers);
    } catch (error) {
      const status = error.status || 500;
      return json({ error: status === 500 ? "internal_error" : error.message }, status, headers);
    }
  },
};

async function upload(request, env, url, headers) {
  const user = await authenticatedUser(request, env);
  await requireAdmin(user.uid, env);
  const type = request.headers.get("content-type") || "";
  const size = Number(request.headers.get("content-length") || 0);
  if (!type.startsWith("video/")) throw httpError(400, "unsupported_video_type");
  if (size > 100 * 1024 * 1024) throw httpError(413, "video_too_large");
  const fileName = url.searchParams.get("fileName") || "video.mp4";
  const extension = safeExtension(fileName);
  const key = `reels/original/${Date.now()}-${crypto.randomUUID()}.${extension}`;
  await env.REELS_BUCKET.put(key, request.body, { httpMetadata: { contentType: type } });
  return json({ publicUrl: `${env.R2_PUBLIC_BASE_URL.replace(/\/$/, "")}/${key}`, key }, 201, headers);
}

async function recordEvent(request, env, headers) {
  const body = await request.json();
  const reelId = validId(body.reelId);
  const event = String(body.event || "");
  if (!counters[event]) throw httpError(400, "invalid_event");
  const ip = request.headers.get("cf-connecting-ip") || "guest";
  const window = Math.floor(Date.now() / (event === "view" ? 300000 : 30000));
  const dedupeId = await sha256(`${ip}:${reelId}:${event}:${window}`);
  const token = await googleAccessToken(env);
  if (await firestoreExists(`reel_event_dedup/${dedupeId}`, env, token)) return json({ ok: true, duplicate: true }, 200, headers);
  await firestoreSet(`reel_event_dedup/${dedupeId}`, {
    reelId: stringValue(reelId), event: stringValue(event),
    createdAt: timestampValue(new Date()), expiresAt: timestampValue(new Date(Date.now() + 86400000)),
  }, env, token);
  await incrementReel(reelId, counters[event], 1, env, token);
  return json({ ok: true }, 200, headers);
}

async function interaction(request, env, headers) {
  const user = await authenticatedUser(request, env);
  const body = await request.json();
  const reelId = validId(body.reelId);
  const type = body.type === "like" ? "like" : body.type === "save" ? "save" : null;
  if (!type) throw httpError(400, "invalid_interaction");
  const collection = type === "like" ? "reel_likes" : "reel_saves";
  const counter = type === "like" ? "likes" : "saves";
  const path = `${collection}/${user.uid}_${reelId}`;
  const token = await googleAccessToken(env);
  const exists = await firestoreExists(path, env, token);
  if (exists) await firestoreDelete(path, env, token);
  else await firestoreSet(path, { userId: stringValue(user.uid), reelId: stringValue(reelId), createdAt: timestampValue(new Date()) }, env, token);
  await incrementReel(reelId, counter, exists ? -1 : 1, env, token);
  return json({ active: !exists }, 200, headers);
}

async function report(request, env, headers) {
  const user = await authenticatedUser(request, env);
  const body = await request.json();
  const reelId = validId(body.reelId);
  const path = `reel_reports/${user.uid}_${reelId}`;
  const token = await googleAccessToken(env);
  if (await firestoreExists(path, env, token)) return json({ ok: true, duplicate: true }, 200, headers);
  await firestoreSet(path, {
    userId: stringValue(user.uid), reelId: stringValue(reelId),
    reelTitle: stringValue(String(body.reelTitle || "").slice(0, 200)),
    thumbnailUrl: stringValue(String(body.thumbnailUrl || "").slice(0, 1000)),
    reason: stringValue(String(body.reason || "سبب آخر").slice(0, 100)),
    details: stringValue(String(body.details || "").slice(0, 1000)),
    status: stringValue("open"), createdAt: timestampValue(new Date()),
  }, env, token);
  await incrementReel(reelId, "reports", 1, env, token);
  return json({ ok: true }, 201, headers);
}

async function authenticatedUser(request, env) {
  const authorization = request.headers.get("authorization") || "";
  if (!authorization.startsWith("Bearer ")) throw httpError(401, "authentication_required");
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${env.FIREBASE_WEB_API_KEY}`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ idToken: authorization.slice(7) }),
  });
  if (!response.ok) throw httpError(401, "invalid_token");
  const payload = await response.json();
  const uid = payload.users?.[0]?.localId;
  if (!uid) throw httpError(401, "invalid_token");
  return { uid };
}

async function requireAdmin(uid, env) {
  const token = await googleAccessToken(env);
  const response = await firestoreGet(`users/${uid}`, env, token);
  if (response?.fields?.isAdmin?.booleanValue !== true) throw httpError(403, "admin_required");
}

async function googleAccessToken(env) {
  if (cachedGoogleToken?.expiresAt > Date.now() + 60000) return cachedGoogleToken.value;
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  if (account.project_id !== env.FIREBASE_PROJECT_ID) throw new Error("service_account_project_mismatch");
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({ iss: account.client_email, scope: "https://www.googleapis.com/auth/datastore", aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 }));
  const key = await crypto.subtle.importKey("pkcs8", pemBytes(account.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const assertion = `${header}.${claims}.${base64UrlBytes(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }) });
  if (!response.ok) throw new Error("google_token_failed");
  const payload = await response.json();
  cachedGoogleToken = { value: payload.access_token, expiresAt: Date.now() + payload.expires_in * 1000 };
  return cachedGoogleToken.value;
}

const firestoreBase = (env) => `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
async function firestoreGet(path, env, token) { const r = await fetch(`${firestoreBase(env)}/${path}`, { headers: { authorization: `Bearer ${token}` } }); if (r.status === 404) return null; if (!r.ok) throw new Error("firestore_get_failed"); return r.json(); }
async function firestoreExists(path, env, token) { return (await firestoreGet(path, env, token)) !== null; }
async function firestoreSet(path, fields, env, token) { const r = await fetch(`${firestoreBase(env)}/${path}`, { method: "PATCH", headers: { authorization: `Bearer ${token}`, "content-type": "application/json" }, body: JSON.stringify({ fields }) }); if (!r.ok) throw new Error("firestore_set_failed"); }
async function firestoreDelete(path, env, token) { const r = await fetch(`${firestoreBase(env)}/${path}`, { method: "DELETE", headers: { authorization: `Bearer ${token}` } }); if (!r.ok && r.status !== 404) throw new Error("firestore_delete_failed"); }
async function incrementReel(reelId, field, amount, env, token) {
  const document = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/reels/${reelId}`;
  const r = await fetch(`${firestoreBase(env)}:commit`, { method: "POST", headers: { authorization: `Bearer ${token}`, "content-type": "application/json" }, body: JSON.stringify({ writes: [{ transform: { document, fieldTransforms: [{ fieldPath: field, increment: { integerValue: String(amount) } }, { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" }] } }] }) });
  if (!r.ok) throw new Error("firestore_increment_failed");
}

function safeExtension(name) { const value = name.split(".").pop().toLowerCase(); return ["mp4", "mov", "m4v", "webm"].includes(value) ? value : "mp4"; }
function validId(value) { const id = String(value || ""); if (!/^[A-Za-z0-9_-]{10,80}$/.test(id)) throw httpError(400, "invalid_reel"); return id; }
function stringValue(value) { return { stringValue: value }; }
function timestampValue(value) { return { timestampValue: value.toISOString() }; }
function httpError(status, message) { const error = new Error(message); error.status = status; return error; }
function corsHeaders(request) { return { "access-control-allow-origin": request.headers.get("origin") || "*", "access-control-allow-headers": "Authorization, Content-Type", "access-control-allow-methods": "GET, POST, OPTIONS", "vary": "Origin" }; }
function json(value, status, headers) { return new Response(JSON.stringify(value), { status, headers: { ...headers, "content-type": "application/json; charset=utf-8" } }); }
function base64Url(value) { return base64UrlBytes(new TextEncoder().encode(value)); }
function base64UrlBytes(bytes) { let text = ""; for (const byte of bytes) text += String.fromCharCode(byte); return btoa(text).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_"); }
function pemBytes(pem) { const raw = atob(pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "")); return Uint8Array.from(raw, (character) => character.charCodeAt(0)); }
async function sha256(value) { const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)); return [...new Uint8Array(hash)].map((byte) => byte.toString(16).padStart(2, "0")).join(""); }
