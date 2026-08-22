import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';
import 'notification_navigation_service.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _initialized = false;

  // =========================================================
  // تهيئة نظام الإشعارات
  // مهم: هذه الدالة لا تطلب Permission من المستخدم
  // =========================================================
  static Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;

    // =========================================================
    // Firebase Messaging
    // =========================================================

    // نحاول الحصول على Token إذا كان متاحاً بالفعل.
    // لا نطلب صلاحية الإشعارات هنا.
    try {
      final token = await _messaging.getToken();

      debugPrint("FCM Token: $token");

      final user = FirebaseAuth.instance.currentUser;

      if (user != null && token != null) {
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "fcmToken": token,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("FCM Token Error: $e");
    }

    // =========================================================
    // تحديث FCM Token
    // =========================================================

    _messaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "fcmToken": newToken,
        }, SetOptions(merge: true));
      }
    });

    // =========================================================
    // وصول إشعار FCM والتطبيق مفتوح
    // =========================================================

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint("========== Firebase ==========");
      debugPrint(message.notification?.title);
      debugPrint(message.notification?.body);
    });

    // =========================================================
    // الضغط على إشعار FCM والتطبيق في الخلفية
    // =========================================================

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) async {
        debugPrint("========== FCM CLICK ==========");
        debugPrint("Data: ${message.data}");

        await _handleNotificationClick(
          Map<String, dynamic>.from(message.data),
        );
      },
    );

    // =========================================================
    // OneSignal
    // =========================================================

    OneSignal.initialize(
      "810a4d8d-cfac-492a-956e-0cff98248d25",
    );

    // عند كون التطبيق مفتوحاً، OneSignal قد يعترض الإشعار
    // ولا يعرضه في شريط إشعارات الهاتف افتراضياً.
    // نطلب منه عرضه صراحةً.
    OneSignal.Notifications.addForegroundWillDisplayListener(
      (event) {
        debugPrint("========== ONESIGNAL FOREGROUND ==========");
        debugPrint(
          "Notification ID: ${event.notification.notificationId}",
        );
        event.notification.display();
      },
    );

    // مهم:
    // لا نطلب Permission هنا.
    // سيتم طلبه لاحقاً بعد تسجيل الدخول.

    // =========================================================
    // الضغط على إشعار OneSignal
    // =========================================================

    OneSignal.Notifications.addClickListener(
      (event) async {
        debugPrint("========== ONESIGNAL CLICK ==========");

        final additionalData = event.notification.additionalData;

        debugPrint("Data: $additionalData");

        if (additionalData == null) {
          return;
        }

        await _handleNotificationClick(
          Map<String, dynamic>.from(additionalData),
        );
      },
    );

    // =========================================================
    // OneSignal Subscription
    // =========================================================

    final user = FirebaseAuth.instance.currentUser;

    final subscriptionId = OneSignal.User.pushSubscription.id;

    debugPrint("OneSignal ID: $subscriptionId");

    if (user != null && subscriptionId != null) {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "oneSignalId": subscriptionId,
      }, SetOptions(merge: true));
    }

    OneSignal.User.pushSubscription.addObserver(
      (state) async {
        final id = state.current.id;

        debugPrint("New OneSignal ID: $id");

        final currentUser = FirebaseAuth.instance.currentUser;

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

    // =========================================================
    // فتح التطبيق من FCM وهو مغلق
    // =========================================================

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint("========== FCM INITIAL ==========");
      debugPrint("Data: ${initialMessage.data}");

      Future.delayed(
        const Duration(milliseconds: 1200),
        () async {
          await _handleNotificationClick(
            Map<String, dynamic>.from(
              initialMessage.data,
            ),
          );
        },
      );
    }
  }

  // =========================================================
  // طلب صلاحية الإشعارات
  //
  // لا يتم استدعاء هذه الدالة عند تشغيل التطبيق.
  // سنستدعيها من نافذتنا بعد تسجيل الدخول.
  // =========================================================

  static Future<bool> requestNotificationPermission() async {
    try {
      // Firebase / Android / iOS
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        "Notification Permission: "
        "${settings.authorizationStatus}",
      );

      final bool firebaseAllowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      // OneSignal
      // إذا كان النظام يحتاج إظهار Permission فسيتم ذلك هنا،
      // وليس أثناء تشغيل التطبيق.
      await OneSignal.Notifications.requestPermission(true);

      if (firebaseAllowed) {
        await saveTokens();
      }

      return firebaseAllowed;
    } catch (e) {
      debugPrint(
        "Notification Permission Error: $e",
      );

      return false;
    }
  }

  // =========================================================
// معرفة حالة صلاحية إشعارات النظام
// =========================================================

  static Future<bool> isSystemNotificationPermissionGranted() async {
    final settings = await _messaging.getNotificationSettings();

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

// =========================================================
// تشغيل إشعارات المستخدم
// =========================================================

  static Future<bool> enableNotifications() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    try {
      bool allowed = await isSystemNotificationPermissionGranted();

      // إذا لم تكن صلاحية النظام ممنوحة، نطلبها الآن.
      if (!allowed) {
        allowed = await requestNotificationPermission();
      }

      if (!allowed) {
        return false;
      }

      await saveTokens();

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "notificationsEnabled": true,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint("Enable Notifications Error: $e");
      return false;
    }
  }

// =========================================================
// إيقاف إشعارات المستخدم
// =========================================================

  static Future<bool> disableNotifications() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "notificationsEnabled": false,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint("Disable Notifications Error: $e");
      return false;
    }
  }

  // =========================================================
  // معالجة الضغط على الإشعار
  // =========================================================

  static String _lastHandledNotificationKey = '';
  static DateTime? _lastHandledNotificationAt;

  static Future<void> _handleNotificationClick(
    Map<String, dynamic> data,
  ) async {
    if (data.isEmpty) {
      debugPrint(
        "Notification click ignored: data is empty.",
      );

      return;
    }

    // بعض الخوادم قد ترسل بيانات الوجهة داخل data
    // وبعضها قد يرسلها مباشرة.
    final nestedData = data["data"];

    Map<String, dynamic> navigationData = Map<String, dynamic>.from(data);

    if (nestedData is Map) {
      navigationData.addAll(
        Map<String, dynamic>.from(nestedData),
      );
    }

    debugPrint(
      "Navigation Data: $navigationData",
    );

    final notificationId =
        (navigationData["notificationId"] ?? "").toString().trim();

    final notificationKey = notificationId.isNotEmpty
        ? notificationId
        : [
            navigationData["type"] ?? "",
            navigationData["propertyId"] ?? "",
            navigationData["officeId"] ?? "",
            navigationData["chatId"] ?? "",
          ].join("|");

    final now = DateTime.now();

    if (_lastHandledNotificationKey == notificationKey &&
        _lastHandledNotificationAt != null &&
        now.difference(_lastHandledNotificationAt!) <
            const Duration(seconds: 2)) {
      debugPrint(
        "Notification click ignored: duplicate click.",
      );
      return;
    }

    _lastHandledNotificationKey = notificationKey;
    _lastHandledNotificationAt = now;

    // نعطي MaterialApp فرصة ليصبح Navigator جاهزاً.
    for (int attempt = 0; attempt < 10; attempt++) {
      if (NotificationNavigationService.navigatorKey.currentContext != null) {
        await NotificationNavigationService.handlePushNotification(
          navigationData,
        );

        return;
      }

      await Future.delayed(
        const Duration(milliseconds: 300),
      );
    }

    debugPrint(
      "Notification navigation failed: "
      "Navigator is not ready.",
    );
  }

  // =========================================================
  // حفظ FCM + OneSignal Tokens
  // =========================================================

  static Future<void> saveTokens() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      final oneSignalId = OneSignal.User.pushSubscription.id;

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        if (fcmToken != null) "fcmToken": fcmToken,
        if (oneSignalId != null) "oneSignalId": oneSignalId,
      }, SetOptions(merge: true));

      debugPrint("Tokens Saved Successfully");
    } catch (e) {
      debugPrint("Save Tokens Error: $e");
    }
  }
}
