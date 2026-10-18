// Dedicated FCM harness. Does not start the production app or OneSignal/Vercel.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_device_service.dart';
import 'services/push_migration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const project = String.fromEnvironment('STAGING_PROJECT_ID');
  const apiKey = String.fromEnvironment('STAGING_API_KEY');
  const appId = String.fromEnvironment('STAGING_APP_ID');
  const sender = String.fromEnvironment('STAGING_SENDER_ID');
  const emulators = bool.fromEnvironment('STAGING_EMULATORS');
  const host = String.fromEnvironment('STAGING_EMULATOR_HOST',
      defaultValue: '127.0.0.1');
  if (!PushMigration.enabled ||
      project == 'aqar-9f3f9' ||
      !project.startsWith('aqar-fcm-test-') && project != 'demo-aqar' ||
      emulators != (project == 'demo-aqar') ||
      apiKey.isEmpty ||
      appId.isEmpty ||
      sender.isEmpty) {
    throw StateError('Explicit isolated staging configuration is required');
  }
  await Firebase.initializeApp(
      options: const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: sender,
    projectId: project,
    iosBundleId: 'com.andalus.aqar.staging',
  ));
  if (emulators) {
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8185);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  }
  runApp(const MaterialApp(home: _Harness()));
}

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String status = 'FCM staging — isolated test accounts only';
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  @override
  void initState() {
    super.initState();
    if (const bool.fromEnvironment('STAGING_EMULATORS')) return;
    void show(RemoteMessage message) {
      if (mounted) {
        setState(
            () => status = 'Received ${message.messageId}\n${message.data}');
      }
    }

    _subscriptions.add(FirebaseMessaging.onMessage.listen(show));
    _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen(show));
    _subscriptions
        .add(FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await PushDeviceService.register(token, uid);
        } catch (error) {
          if (mounted) setState(() => status = '$error');
        }
      }
    }));
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) show(message);
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<void> register() async {
    try {
      const emulators = bool.fromEnvironment('STAGING_EMULATORS');
      final user = FirebaseAuth.instance.currentUser ??
          (await FirebaseAuth.instance.signInAnonymously()).user!;
      final profile =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (!(await profile.get()).exists) {
        await profile.set({
          'notificationsEnabled': true,
          'isBlocked': false,
          'isAdmin': false,
          'accountType': 'user',
          'accountMode': 'user',
        });
      }
      final messaging = FirebaseMessaging.instance;
      String? token;
      if (emulators) {
        token = 'synthetic-emulator-token-${user.uid}';
      } else {
        await messaging.requestPermission();
        if (!mounted) return;
        if (Theme.of(context).platform == TargetPlatform.iOS &&
            await messaging.getAPNSToken() == null) {
          throw StateError('APNs token unavailable; retry after provisioning');
        }
        token = await messaging.getToken();
        await messaging.setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true);
      }
      if (token == null) throw StateError('FCM token unavailable');
      await PushDeviceService.register(token, user.uid);
      if (mounted) {
        setState(() => status =
            'Registered: ${user.uid}\n${emulators ? "Synthetic token; no real delivery" : "Real device token"}');
      }
    } catch (error) {
      if (mounted) setState(() => status = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('FCM staging')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              SelectableText(status),
              ElevatedButton(
                  onPressed: register,
                  child: const Text('Register test device')),
              ElevatedButton(
                  onPressed: () async {
                    await PushDeviceService.detach();
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      setState(() => status = 'Detached and signed out');
                    }
                  },
                  child: const Text('Detach and sign out')),
            ])),
      );
}
