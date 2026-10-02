const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { canDeleteMessage, isOfficeOpen } = require("./chat_policy");

async function removeAttachments(chatId, paths) {
  for (const path of paths.filter(Boolean)) {
    const parts = path.split('/');
    if (parts.length !== 4 || !['chat_audio', 'chat_images'].includes(parts[0]) || parts[1] !== chatId || !/^[0-9]+\.(m4a|jpg|png)$/.test(parts[3])) continue;
    await getStorage().bucket().file(path).delete({ ignoreNotFound: true });
  }
}

exports.deleteChatMessage = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "سجّل الدخول أولاً");
  const { chatId, messageId } = request.data || {};
  if (typeof chatId !== "string" || typeof messageId !== "string" || !chatId || !messageId || chatId.length > 128 || messageId.length > 128 || chatId.includes("/") || messageId.includes("/")) {
    throw new HttpsError("invalid-argument", "معرّف الرسالة غير صالح");
  }
  const db = getFirestore();
  const userSnapshot = await db.collection("users").doc(uid).get();
  if (!userSnapshot.exists) throw new HttpsError('permission-denied', 'الحساب غير متاح');
  const user = userSnapshot.data();
  const admin = user.isAdmin === true;
  if ((!admin && chatId !== uid) || user.isBlocked === true) throw new HttpsError("permission-denied", "غير مسموح");
  const settings = (await db.doc("settings/app_settings").get()).data() || {};
  const chatReference = db.collection("chats").doc(chatId);
  const messageReference = chatReference.collection("messages").doc(messageId);
  let audioPath = "";
  let imagePath = "";
  await db.runTransaction(async (transaction) => {
    const [chat, snapshot] = await Promise.all([transaction.get(chatReference), transaction.get(messageReference)]);
    if (!snapshot.exists || !chat.exists) throw new HttpsError("not-found", "الرسالة غير متاحة");
    const message = snapshot.data();
    if (!canDeleteMessage({ message, uid, admin, now: Date.now(), preferences: settings.chatPreferences })) {
      throw new HttpsError("permission-denied", "انتهت مهلة الحذف أو الرسالة ليست لك");
    }
    // Keep the storage path privately in the audit entry so a retry can clean up
    // an audio object even after the visible message has become a tombstone.
    const auditReference = chatReference.collection("deletionAudit").doc(messageId);
    const audit = await transaction.get(auditReference);
    const recipients = [...new Set([chatId, settings.adminUid].filter(value => typeof value === 'string' && value && !value.includes('/')))];
    const previews = await Promise.all(recipients.map(recipient => transaction.get(db.collection('notifications').doc(`chat_${chatId}_${recipient}`))));
    audioPath = message.audioPath || audit.data()?.audioPath || "";
    imagePath = message.imagePath || audit.data()?.imagePath || "";
    if (message.deletedAt) return;
    transaction.set(messageReference, {
      senderId: message.senderId, senderType: message.senderType,
      authorUid: message.authorUid || "", createdAt: message.createdAt,
      status: message.status || "sent", isRead: message.isRead === true,
      deletedAt: FieldValue.serverTimestamp(), deletedBy: uid,
      type: "deleted", message: "", imageUrl: "", audioUrl: "", replyToId: "",
    });
    transaction.set(auditReference, { messageId, deletedBy: uid, deletedAt: FieldValue.serverTimestamp(), reason: admin ? "moderation" : "sender", audioPath, imagePath });
    if (chat.data().lastMessageId === messageId) transaction.update(chatReference, { lastMessage: "تم حذف هذه الرسالة" });
    for (const preview of previews) {
      if (preview.exists && preview.data().messageId === messageId) transaction.update(preview.ref, { message: 'تم حذف هذه الرسالة', updatedAt: FieldValue.serverTimestamp() });
    }
  });
  try { await removeAttachments(chatId, [audioPath, imagePath]); }
  catch (error) { console.error('Attachment cleanup deferred to retrying trigger', { chatId, messageId, error: error.message }); }
  return { deleted: true };
});

exports.chatDeletedAttachmentCleanup = onDocumentWritten({ document: 'chats/{chatId}/messages/{messageId}', retry: true }, async (event) => {
  if (!event.data?.after.exists || !event.data.after.data().deletedAt) return;
  const audit = await getFirestore().doc(`chats/${event.params.chatId}/deletionAudit/${event.params.messageId}`).get();
  await removeAttachments(event.params.chatId, [audit.data()?.audioPath, audit.data()?.imagePath]);
});

exports.chatAwayReply = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const message = event.data?.data();
  if (!message || message.senderType !== "user" || message.deletedAt) return;
  const db = getFirestore();
  const settings = (await db.doc("settings/app_settings").get()).data() || {};
  const preferences = settings.chatPreferences || {};
  const receivedAt = message.createdAt?.toDate() || new Date();
  if (settings.allowChat === false || !preferences.hoursEnabled || isOfficeOpen(preferences, receivedAt)) return;
  const text = String(preferences.awayMessage || "").trim().slice(0, 1000);
  if (!text) return;
  const day = new Date(receivedAt.getTime() + 3 * 3600000).toISOString().slice(0, 10);
  const chatReference = db.collection("chats").doc(event.params.chatId);
  const replyReference = chatReference.collection("messages").doc(`away_${day}`);
  const notificationReference = db.collection("notifications").doc(`away_${event.params.chatId}_${day}`);
  await db.runTransaction(async (transaction) => {
    const [chat, reply, source] = await Promise.all([transaction.get(chatReference), transaction.get(replyReference), transaction.get(event.data.ref)]);
    if (!chat.exists || !source.exists || chat.data().isBlocked || chat.data().isClosed || reply.exists || source.data()?.deletedAt) return;
    transaction.set(replyReference, {
      senderId: "admin", senderType: "system", authorUid: "system", type: "text", message: text,
      createdAt: FieldValue.serverTimestamp(), isRead: false, status: "sent", replyToId: "",
    });
    const update = { unreadUser: FieldValue.increment(1) };
    // Avoid replacing the preview of a newer human message when a trigger is delayed.
    if (chat.data().lastMessageId === event.params.messageId) Object.assign(update, { lastMessage: text, lastMessageId: replyReference.id, lastSender: "admin", updatedAt: FieldValue.serverTimestamp() });
    transaction.update(chatReference, update);
    transaction.set(notificationReference, { title: "عقارات الأنبار", message: text, type: "chat_message", userId: event.params.chatId, chatId: event.params.chatId, target: "user", readBy: [], createdAt: FieldValue.serverTimestamp() });
  });
});
