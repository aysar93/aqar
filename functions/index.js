const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");

initializeApp();
Object.assign(exports, require('./booking_functions'));

const db = getFirestore();
Object.assign(exports, require('./chat_functions'));
Object.assign(exports, require('./analytics_presence_access'));

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
      data: require('./notification_push_data').notificationPushData(data, event.params.notificationId),

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

// Server-only office counters; source transitions are atomic and deduplicated.
const officeCounters = require('./office_counters');
exports.refreshOfficeFollowerMetrics = officeCounters.refreshOfficeFollowerMetrics;
exports.refreshOfficeReviewMetrics = officeCounters.refreshOfficeReviewMetrics;
exports.refreshOfficePropertyMetrics = officeCounters.refreshOfficePropertyMetrics;

const paymentSettings = require("./payment_accounts");
for (const name of ["getPaymentAccountSettings", "savePaymentAccountSettings", "createSubscriptionPayment"]) exports[name] = paymentSettings[name];
