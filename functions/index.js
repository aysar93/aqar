const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

initializeApp();

const db = getFirestore();

const r2AccountId = defineSecret("R2_ACCOUNT_ID");
const r2AccessKeyId = defineSecret("R2_ACCESS_KEY_ID");
const r2SecretAccessKey = defineSecret("R2_SECRET_ACCESS_KEY");
const r2Bucket = defineSecret("R2_BUCKET");
const r2PublicBaseUrl = defineSecret("R2_PUBLIC_BASE_URL");

async function assertAdmin(uid) {
  if (!uid) throw new HttpsError("unauthenticated", "تسجيل الدخول مطلوب");
  const user = await db.collection("users").doc(uid).get();
  if (user.data()?.isAdmin !== true) throw new HttpsError("permission-denied", "هذه العملية للمدير فقط");
}

function safeVideoName(input) {
  const extension = String(input || "video.mp4").split(".").pop().toLowerCase();
  const allowed = ["mp4", "mov", "m4v", "webm"];
  return `${Date.now()}-${crypto.randomUUID()}.${allowed.includes(extension) ? extension : "mp4"}`;
}

exports.createReelUploadUrl = onCall({
  secrets: [r2AccountId, r2AccessKeyId, r2SecretAccessKey, r2Bucket, r2PublicBaseUrl],
  timeoutSeconds: 30,
}, async (request) => {
  await assertAdmin(request.auth?.uid);
  const size = Number(request.data?.size || 0);
  const contentType = String(request.data?.contentType || "");
  if (!contentType.startsWith("video/")) throw new HttpsError("invalid-argument", "نوع الملف غير مدعوم");
  if (size <= 0 || size > 250 * 1024 * 1024) throw new HttpsError("invalid-argument", "حجم الفيديو يجب ألا يتجاوز 250MB");
  const key = `reels/original/${safeVideoName(request.data?.fileName)}`;
  const client = new S3Client({
    region: "auto",
    endpoint: `https://${r2AccountId.value()}.r2.cloudflarestorage.com`,
    credentials: { accessKeyId: r2AccessKeyId.value(), secretAccessKey: r2SecretAccessKey.value() },
  });
  const command = new PutObjectCommand({ Bucket: r2Bucket.value(), Key: key, ContentType: contentType });
  const uploadUrl = await getSignedUrl(client, command, { expiresIn: 10 * 60 });
  return { uploadUrl, publicUrl: `${r2PublicBaseUrl.value().replace(/\/$/, "")}/${key}`, key, expiresInSeconds: 600 };
});

const reelCounters = {
  view: "views", completion: "completions", share: "shares",
  propertyClick: "propertyClicks", officeClick: "officeClicks", externalClick: "externalClicks",
};

exports.recordReelEvent = onCall(async (request) => {
  const reelId = String(request.data?.reelId || "");
  const event = String(request.data?.event || "");
  if (!/^[A-Za-z0-9_-]{10,80}$/.test(reelId) || !reelCounters[event]) {
    throw new HttpsError("invalid-argument", "حدث غير صالح");
  }
  const reel = db.collection("reels").doc(reelId);
  if (!(await reel.get()).exists) throw new HttpsError("not-found", "الريل غير موجود");
  const actor = request.auth?.uid || crypto.createHash("sha256").update(String(request.rawRequest?.ip || "guest")).digest("hex");
  const bucket = Math.floor(Date.now() / (event === "view" ? 300000 : 30000));
  const dedupe = db.collection("reel_event_dedup").doc(crypto.createHash("sha256").update(`${actor}:${reelId}:${event}:${bucket}`).digest("hex"));
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(dedupe)).exists) return;
    transaction.create(dedupe, { reelId, event, createdAt: FieldValue.serverTimestamp(), expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) });
    transaction.update(reel, { [reelCounters[event]]: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
});

exports.refreshReelLikeMetrics = onDocumentWritten("reel_likes/{interactionId}", async (event) => {
  const before = event.data?.before.exists === true;
  const after = event.data?.after.exists === true;
  if (before === after) return;
  const data = (after ? event.data.after.data() : event.data.before.data()) || {};
  if (data.reelId) await db.collection("reels").doc(data.reelId).update({ likes: FieldValue.increment(after ? 1 : -1) });
});

exports.refreshReelSaveMetrics = onDocumentWritten("reel_saves/{interactionId}", async (event) => {
  const before = event.data?.before.exists === true;
  const after = event.data?.after.exists === true;
  if (before === after) return;
  const data = (after ? event.data.after.data() : event.data.before.data()) || {};
  if (data.reelId) await db.collection("reels").doc(data.reelId).update({ saves: FieldValue.increment(after ? 1 : -1) });
});

exports.refreshReelReportMetrics = onDocumentCreated("reel_reports/{reportId}", async (event) => {
  const reelId = event.data?.data()?.reelId;
  if (reelId) await db.collection("reels").doc(reelId).update({ reports: FieldValue.increment(1) });
});

exports.publishScheduledReels = onSchedule("every 5 minutes", async () => {
  const now = new Date();
  const [scheduled, expired] = await Promise.all([
    db.collection("reels").where("status", "==", "scheduled").where("publishAt", "<=", now).limit(200).get(),
    db.collection("reels").where("status", "==", "published").where("expiresAt", "<=", now).limit(200).get(),
  ]);
  const batch = db.batch();
  scheduled.docs.forEach((doc) => batch.update(doc.ref, { status: "published", updatedAt: FieldValue.serverTimestamp() }));
  expired.docs.forEach((doc) => batch.update(doc.ref, { status: "expired", updatedAt: FieldValue.serverTimestamp() }));
  if (scheduled.size + expired.size > 0) await batch.commit();
});

function normalizeIraqiPhone(input) {
  const localizedDigits = {
    "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
    "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
    "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
    "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9",
  };
  let digits = String(input || "")
    .split("")
    .map((character) => localizedDigits[character] || character)
    .join("")
    .replace(/[^0-9]/g, "");

  if (digits.startsWith("00964")) digits = digits.slice(5);
  else if (digits.startsWith("964")) digits = digits.slice(3);
  else if (digits.startsWith("0")) digits = digits.slice(1);

  return /^7\d{9}$/.test(digits) ? `+964${digits}` : null;
}

function phoneIndexId(phone) {
  return crypto.createHash("sha256").update(phone).digest("hex");
}

function emailIndexId(email) {
  return crypto.createHash("sha256").update(email).digest("hex");
}

function legacyPhoneForms(phone) {
  const national = phone.slice(4);
  return [phone, `0${national}`, national, `964${national}`, `00964${national}`];
}

async function consumeAuthAttempt(request, action) {
  const ip = request.rawRequest?.ip || "unknown";
  const key = crypto.createHash("sha256").update(`${action}:${ip}`).digest("hex");
  const reference = db.collection("auth_rate_limits").doc(key);
  const now = Date.now();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() || {};
    const windowStartedAt = Number(data.windowStartedAt || 0);
    const withinWindow = now - windowStartedAt < 15 * 60 * 1000;
    const count = withinWindow ? Number(data.count || 0) + 1 : 1;
    if (count > 25) {
      throw new HttpsError("resource-exhausted", "محاولات كثيرة، حاول لاحقًا");
    }
    transaction.set(reference, {
      action,
      count,
      windowStartedAt: withinWindow ? windowStartedAt : now,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

exports.createPasswordAccount = onCall(async (request) => {
  await consumeAuthAttempt(request, "register");
  const name = String(request.data?.name || "").trim();
  const phone = normalizeIraqiPhone(request.data?.phone);
  const email = String(request.data?.email || "").trim().toLowerCase();
  const password = String(request.data?.password || "");

  if (name.length < 3) throw new HttpsError("invalid-argument", "الاسم غير صحيح");
  if (!phone) throw new HttpsError("invalid-argument", "رقم الهاتف العراقي غير صحيح");
  if (password.length < 6) {
    throw new HttpsError("invalid-argument", "كلمة المرور يجب أن تتضمن 6 أحرف على الأقل");
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "البريد الإلكتروني غير صحيح");
  }
  if (email) {
    try {
      await getAuth().getUserByEmail(email);
      throw new HttpsError("already-exists", "البريد الإلكتروني مستخدم مسبقًا");
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error.code !== "auth/user-not-found") throw error;
    }
  }
  const [legacyPhone, normalizedPhone] = await Promise.all([
    db.collection("users").where("phone", "in", legacyPhoneForms(phone)).limit(1).get(),
    db.collection("users").where("phoneNormalized", "==", phone).limit(1).get(),
  ]);
  if (!legacyPhone.empty || !normalizedPhone.empty) {
    throw new HttpsError("already-exists", "رقم الهاتف مستخدم مسبقًا");
  }

  const indexRef = db.collection("phone_login_index").doc(phoneIndexId(phone));
  const emailIndexRef = email
    ? db.collection("email_login_index").doc(emailIndexId(email))
    : null;
  const reservationId = crypto.randomUUID();
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(indexRef);
    if (existing.exists) throw new HttpsError("already-exists", "رقم الهاتف مستخدم مسبقًا");
    if (emailIndexRef) {
      const existingEmail = await transaction.get(emailIndexRef);
      if (existingEmail.exists) {
        throw new HttpsError("already-exists", "البريد الإلكتروني مستخدم مسبقًا");
      }
    }
    transaction.create(indexRef, {
      phone,
      reservationId,
      status: "reserved",
      createdAt: FieldValue.serverTimestamp(),
    });
    if (emailIndexRef) {
      transaction.create(emailIndexRef, {
        email,
        reservationId,
        status: "reserved",
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  });

  const authEmail = `phone-${phone.slice(1)}@login.aqar.invalid`;
  let userRecord;
  try {
    userRecord = await getAuth().createUser({
      email: authEmail,
      password,
      displayName: name,
      disabled: false,
    });
    const userRef = db.collection("users").doc(userRecord.uid);
    await db.runTransaction(async (transaction) => {
      const reservation = await transaction.get(indexRef);
      if (!reservation.exists || reservation.data().reservationId !== reservationId) {
        throw new HttpsError("aborted", "تعذر حجز رقم الهاتف");
      }
      transaction.set(userRef, {
        uid: userRecord.uid,
        name,
        email,
        phone,
        phoneNormalized: phone,
        photo: "",
        photoUrl: "",
        provider: "password",
        providers: ["password"],
        isAdmin: false,
        accountType: "user",
        officeId: "",
        activeOfficeId: "",
        accountMode: "user",
        isVerified: true,
        phoneVerified: false,
        isBlocked: false,
        createdAt: FieldValue.serverTimestamp(),
        lastLogin: FieldValue.serverTimestamp(),
      });
      transaction.set(indexRef, {
        uid: userRecord.uid,
        authEmail,
        phone,
        status: "active",
        reservationId: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (emailIndexRef) {
        transaction.set(emailIndexRef, {
          uid: userRecord.uid,
          authEmail,
          email,
          status: "active",
          reservationId: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
    return { authEmail };
  } catch (error) {
    if (userRecord?.uid) await getAuth().deleteUser(userRecord.uid).catch(() => null);
    await indexRef.delete().catch(() => null);
    if (emailIndexRef) await emailIndexRef.delete().catch(() => null);
    if (error instanceof HttpsError) throw error;
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "البريد الإلكتروني مستخدم مسبقًا");
    }
    console.error("createPasswordAccount", error);
    throw new HttpsError("internal", "تعذر إنشاء الحساب");
  }
});

exports.resolveEmailLogin = onCall(async (request) => {
  await consumeAuthAttempt(request, "login");
  const email = String(request.data?.email || "").trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "البريد الإلكتروني غير صحيح");
  }
  const indexed = await db.collection("email_login_index")
    .doc(emailIndexId(email))
    .get();
  if (!indexed.exists || indexed.data().status !== "active") {
    throw new HttpsError("not-found", "بيانات الدخول غير صحيحة");
  }
  return { authEmail: indexed.data().authEmail };
});

exports.resolvePhoneLogin = onCall(async (request) => {
  await consumeAuthAttempt(request, "login");
  const phone = normalizeIraqiPhone(request.data?.phone);
  if (!phone) throw new HttpsError("invalid-argument", "رقم الهاتف العراقي غير صحيح");

  const indexRef = db.collection("phone_login_index").doc(phoneIndexId(phone));
  const indexed = await indexRef.get();
  if (indexed.exists && indexed.data().status === "active") {
    return { authEmail: indexed.data().authEmail };
  }

  const legacy = await db.collection("users")
    .where("phone", "in", legacyPhoneForms(phone))
    .limit(2)
    .get();
  if (legacy.empty) throw new HttpsError("not-found", "بيانات الدخول غير صحيحة");
  if (legacy.size > 1) {
    throw new HttpsError("failed-precondition", "يوجد تعارض في رقم الهاتف، تواصل مع الإدارة");
  }

  const uid = legacy.docs[0].id;
  const userRecord = await getAuth().getUser(uid);
  if (!userRecord.email) {
    throw new HttpsError("failed-precondition", "هذا الحساب لا يدعم كلمة المرور، استخدم طريقة دخوله الأصلية");
  }
  await indexRef.set({
    uid,
    authEmail: userRecord.email,
    phone,
    status: "active",
    migratedAt: FieldValue.serverTimestamp(),
  });
  await legacy.docs[0].ref.set({ phoneNormalized: phone }, { merge: true });
  return { authEmail: userRecord.email };
});

exports.sendNotificationToUser = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {

    const data = event.data.data();

    const userId = data.userId;
    const title = data.title;
    const message = data.message;

    // إذا كان إشعار عام لا نرسل الآن
    if (!userId || userId === "all") {
      return null;
    }


    const userDoc = await db
      .collection("users")
      .doc(userId)
      .get();


    if (!userDoc.exists) {
      return null;
    }


    const userData = userDoc.data();

// ==========================
// احترام إعدادات الإشعارات
// ==========================

// إذا أوقف المستخدم الإشعارات من داخل التطبيق
// لا نرسل Push، لكن وثيقة الإشعار تبقى موجودة
// ويمكنه رؤيتها داخل صفحة الإشعارات.
if (userData.notificationsEnabled === false) {
  return null;
}

const token = userData.fcmToken;

if (!token) {
  return null;
}


    await getMessaging().send({

      token: token,

      notification: {
        title: title,
        body: message,
      },

      android: {
        notification: {
          sound: "default",
        },
      },

    });


    return null;
  }
);

// تُدار عدادات المكتب في الخادم حصراً. هذا يمنع فشل المتابعة أو التقييم
// بسبب قواعد العميل، ويجعلها صحيحة حتى عند تعديل/حذف سجل قديم.
async function refreshOfficeMetrics(officeId, { followers = false, reviews = false, properties = false }) {
  if (!officeId) return null;

  const officeRef = db.collection("offices").doc(officeId);
  const office = await officeRef.get();
  if (!office.exists) return null;

  const updates = { updatedAt: new Date() };

  if (followers) {
    const snapshot = await db.collection("office_followers")
      .where("officeId", "==", officeId)
      .where("isActive", "==", true)
      .get();
    updates.followersCount = snapshot.size;
  }

  if (reviews) {
    const snapshot = await db.collection("office_reviews")
      .where("officeId", "==", officeId)
      .where("status", "==", "published")
      .get();
    const ratings = snapshot.docs.map((doc) => Number(doc.data().rating) || 0);
    updates.reviewsCount = ratings.length;
    updates.rating = ratings.length
      ? ratings.reduce((total, rating) => total + rating, 0) / ratings.length
      : 0;
  }

  if (properties) {
    const snapshot = await db.collection("properties")
      .where("officeId", "==", officeId)
      .where("status", "==", "approved")
      .get();
    updates.propertiesCount = snapshot.size;
  }

  await officeRef.update(updates);
  return null;
}

exports.refreshOfficeFollowerMetrics = onDocumentWritten(
  "office_followers/{followerId}",
  async (event) => refreshOfficeMetrics(
    event.data.after.exists ? event.data.after.data().officeId : event.data.before.data().officeId,
    { followers: true },
  ),
);

exports.refreshOfficeReviewMetrics = onDocumentWritten(
  "office_reviews/{reviewId}",
  async (event) => refreshOfficeMetrics(
    event.data.after.exists ? event.data.after.data().officeId : event.data.before.data().officeId,
    { reviews: true },
  ),
);

exports.refreshOfficePropertyMetrics = onDocumentWritten(
  "properties/{propertyId}",
  async (event) => {
    const beforeOfficeId = event.data.before.exists ? event.data.before.data().officeId : "";
    const afterOfficeId = event.data.after.exists ? event.data.after.data().officeId : "";
    await Promise.all([
      refreshOfficeMetrics(beforeOfficeId, { properties: true }),
      beforeOfficeId === afterOfficeId
        ? Promise.resolve()
        : refreshOfficeMetrics(afterOfficeId, { properties: true }),
    ]);
    return null;
  },
);
