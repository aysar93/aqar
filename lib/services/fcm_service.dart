import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class FCMService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // =========================
    // Firebase Messaging
    // =========================

    NotificationSettings settings =
        await _messaging.requestPermission();

    print(
      "Notification Permission: ${settings.authorizationStatus}",
    );

    final token = await _messaging.getToken();

    print("FCM Token: $token");

    final user = FirebaseAuth.instance.currentUser;

    if (user != null && token != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "fcmToken": token,
      }, SetOptions(merge: true));
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .set({
          "fcmToken": newToken,
        }, SetOptions(merge: true));
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      print("========== Firebase ==========");
      print(message.notification?.title);
      print(message.notification?.body);
    });

    // =========================
    // OneSignal
    // =========================

    OneSignal.initialize(
      "810a4d8d-cfac-492a-956e-0cff98248d25",
    );

    OneSignal.Notifications.requestPermission(true);

    final subscriptionId =
        OneSignal.User.pushSubscription.id;

    print("OneSignal ID: $subscriptionId");

    if (user != null && subscriptionId != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "oneSignalId": subscriptionId,
      }, SetOptions(merge: true));
    }

    OneSignal.User.pushSubscription.addObserver(
      (state) async {
        final id = state.current.id;

        print("New OneSignal ID: $id");

        final currentUser =
            FirebaseAuth.instance.currentUser;

        if (currentUser != null && id != null) {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(currentUser.uid)
              .set({
            "oneSignalId": id,
          }, SetOptions(merge: true));
        }
      },
    );
  }

static Future<void> saveTokens() async {

  final user =
      FirebaseAuth.instance.currentUser;

  if (user == null) return;


  final fcmToken =
      await FirebaseMessaging.instance.getToken();


  final oneSignalId =
      OneSignal.User.pushSubscription.id;


  await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .set({

        if (fcmToken != null)
          "fcmToken": fcmToken,

        if (oneSignalId != null)
          "oneSignalId": oneSignalId,

      },
      SetOptions(merge:true)
  );


  print("Tokens Saved Successfully");

}

}