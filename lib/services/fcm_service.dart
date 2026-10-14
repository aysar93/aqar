import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_navigation_service.dart';
import 'push_token_sync.dart';
import 'push_migration.dart';
import 'push_device_service.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _initialized = false;
  static const _privacyChannel = MethodChannel('aqar/push_privacy');

  static Future<void> _drainNativeNotificationTap() async {
    final payload = await _privacyChannel
        .invokeMapMethod<String, dynamic>('getPendingNotificationTap');
    if (payload != null) await _handleNotificationClick(payload);
  }

  // =========================================================
  // تهيئة نظام الإشعارات
  // مهم: هذه الدالة لا تطلب Permission من المستخدم
  // =========================================================
  static Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;

    if (PushMigration.enabled &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      _privacyChannel.setMethodCallHandler((call) async {
        if (call.method == 'notificationTapAvailable') {
          await _drainNativeNotificationTap();
        }
      });
      await _drainNativeNotificationTap();
    }

    // =========================================================
    // Firebase Messaging
    // =========================================================

    // =========================================================
    // تحديث FCM Token
    // =========================================================

    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveRefreshedToken('fcmToken', newToken);
    });

    // =========================================================
    // وصول إشعار FCM والتطبيق مفتوح
    // =========================================================

    FirebaseMessaging.onMessage.listen((message) async {
      if (PushMigration.enabled &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || message.data['userId'] != user.uid) return;
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (profile.data()?['isBlocked'] == true ||
            profile.data()?['notificationsEnabled'] == false ||
            FirebaseAuth.instance.currentUser?.uid != user.uid) {
          return;
        }
        final context =
            NotificationNavigationService.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          // Replace stale banners, including those held by accessibility mode.
          clearForegroundNotifications();
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            content: Text(
                '${message.notification?.title ?? ''}\n${message.notification?.body ?? ''}'),
            action: SnackBarAction(
                label: 'عرض',
                onPressed: () => _handleNotificationClick(
                    Map<String, dynamic>.from(message.data))),
          ));
        }
      }
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

    if (PushMigration.oneSignalEnabled) {
      const bridgeAppId = String.fromEnvironment('BRIDGE_ONESIGNAL_APP_ID');
      if (PushMigration.bridgeEnabled &&
          PushMigration.isolated &&
          (bridgeAppId.isEmpty ||
              bridgeAppId == '810a4d8d-cfac-492a-956e-0cff98248d25')) {
        throw StateError(
            'Dedicated test OneSignal app required for isolated bridge');
      }
      await OneSignal.initialize(
        PushMigration.bridgeEnabled && bridgeAppId.isNotEmpty
            ? bridgeAppId
            : "810a4d8d-cfac-492a-956e-0cff98248d25",
      );

      // عند كون التطبيق مفتوحاً، OneSignal قد يعترض الإشعار
      // ولا يعرضه في شريط إشعارات الهاتف افتراضياً.
      // نطلب منه عرضه صراحةً.
      OneSignal.Notifications.addForegroundWillDisplayListener(
        (event) async {
          if (PushMigration.bridgeEnabled) {
            event.preventDefault();
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null ||
                event.notification.additionalData?['userId'] != uid) return;
            final profile = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            if (FirebaseAuth.instance.currentUser?.uid != uid ||
                profile.data()?['isBlocked'] == true ||
                profile.data()?['notificationsEnabled'] == false) return;
          }
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

          await _handleNotificationClick(
            Map<String, dynamic>.from(additionalData ?? <String, dynamic>{}),
          );
        },
      );

      // =========================================================
      // OneSignal Subscription
      // =========================================================

      OneSignal.User.pushSubscription.addObserver((state) async {
        final id = state.current.id;
        if (id != null) await _saveRefreshedToken('oneSignalId', id);
      });
    }

    // Read the launch payload before any network-dependent token writes.
    // The route coordinator waits for the real shell/login to become ready.
    final initialRequest = _messaging.getInitialMessage();
    final initialMessage = PushMigration.enabled &&
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.iOS
        ? await initialRequest.timeout(const Duration(seconds: 3),
            onTimeout: () => null)
        : await initialRequest;
    if (initialMessage != null) {
      debugPrint('FCM initial message: ${initialMessage.messageId}');
      await _handleNotificationClick(
          Map<String, dynamic>.from(initialMessage.data));
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: !PushMigration.enabled,
        badge: !PushMigration.enabled,
        sound: !PushMigration.enabled,
      );
    }
    await saveTokens();
  }

  // =========================================================
  // طلب صلاحية الإشعارات
  //
  // لا يتم استدعاء هذه الدالة عند تشغيل التطبيق.
  // سنستدعيها من نافذتنا بعد تسجيل الدخول.
  // =========================================================

  static Future<bool> requestNotificationPermission() async {
    var allowed = false;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      debugPrint('FCM permission check failed: $error');
    }

    if (PushMigration.oneSignalEnabled) {
      try {
        final oneSignalAllowed =
            await OneSignal.Notifications.requestPermission(true);
        allowed = allowed || oneSignalAllowed;
      } catch (error) {
        debugPrint('OneSignal permission check failed: $error');
      }
    }

    if (allowed) await saveTokens();
    return allowed;
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
    clearForegroundNotifications();
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

    // Queue until MainShell is ready, including cold starts and onboarding.
    await NotificationNavigationService.handlePushNotification(navigationData);
  }

  // =========================================================
  // حفظ FCM + OneSignal Tokens
  // =========================================================

  static Future<void> _saveRefreshedToken(String field, String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token.isEmpty) return;
    try {
      if (PushMigration.bridgeEnabled) {
        await saveTokens();
        return;
      }
      if (PushMigration.enabled && field == 'fcmToken') {
        await PushDeviceService.register(token, user.uid);
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {field: token},
        SetOptions(merge: true),
      );
      if (field == 'fcmToken') {
        await PushDeviceService.register(token, user.uid);
      }
    } catch (error) {
      debugPrint('Refreshed push token save failed for $field: $error');
    }
  }

  static Future<void> saveTokens() async {
    await PushDeviceService.flushPendingRevocations();
    if (PushMigration.bridgeEnabled) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final profile =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      if (OneSignal.User.pushSubscription.optedIn != true &&
          profile.data()?['notificationsEnabled'] != false &&
          profile.data()?['isBlocked'] != true) {
        await OneSignal.User.pushSubscription.optIn();
      }
      final token = await readFcmTokenWhenReady(
          requiresApns: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
          readApnsToken: _messaging.getAPNSToken,
          readFcmToken: _messaging.getToken);
      final subscription = OneSignal.User.pushSubscription.id;
      final apns = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? await _messaging.getAPNSToken()
          : null;
      if (token != null && FirebaseAuth.instance.currentUser?.uid == uid) {
        await PushDeviceService.register(token, uid,
            oneSignalId: subscription, providerToken: apns);
      }
      return;
    }
    await synchronizePushTokens(
      currentUserId: () => FirebaseAuth.instance.currentUser?.uid,
      readOneSignalId: () async =>
          PushMigration.enabled ? null : OneSignal.User.pushSubscription.id,
      readFcmToken: () => readFcmTokenWhenReady(
        requiresApns: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        readApnsToken: _messaging.getAPNSToken,
        readFcmToken: _messaging.getToken,
      ),
      write: (userId, fields) async {
        if (PushMigration.enabled) {
          final token = fields['fcmToken'];
          if (token != null) await PushDeviceService.register(token, userId);
          return;
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set(fields, SetOptions(merge: true));
        final token = fields['fcmToken'];
        if (token != null) await PushDeviceService.register(token, userId);
      },
      onError: (provider, error) =>
          debugPrint('Push token sync failed for $provider: $error'),
    );
  }

  /// Rotate the token and clear notifications belonging to the previous account.
  /// Detach the server installation before calling this while signing out.
  static Future<void> clearAccountNotifications() async {
    if (!PushMigration.enabled) return;
    clearForegroundNotifications();
    if (PushMigration.bridgeEnabled) {
      try {
        await OneSignal.User.pushSubscription
            .optOut()
            .timeout(const Duration(seconds: 2));
        await OneSignal.logout().timeout(const Duration(seconds: 2));
      } catch (_) {
        debugPrint('OneSignal local logout queued or unavailable');
      }
    }
    try {
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('FCM token reset failed: $error');
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await const MethodChannel('aqar/push_privacy')
            .invokeMethod<void>('clearDeliveredNotifications');
      } catch (error) {
        debugPrint('Delivered notification cleanup failed: $error');
      }
    }
  }

  static void clearForegroundNotifications() {
    if (!PushMigration.enabled) return;
    final context = NotificationNavigationService.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }
}
