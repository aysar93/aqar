const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();

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