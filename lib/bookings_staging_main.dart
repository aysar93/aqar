import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bookings/booking_screen.dart';
import 'theme/app_theme.dart';

const bookingStagingProject = 'aqar-bookings-test-20261009';
bool bookingStagingAllowed(String? flavor, String project) =>
    flavor == 'bookingsStaging' && project == bookingStagingProject;
final _stagingNavigator = GlobalKey<NavigatorState>();
RemoteMessage? _pendingNotification;
void _openNotification(RemoteMessage message) {
  final bookingId = message.data['bookingId'];
  if (bookingId is! String || bookingId.isEmpty || bookingId.contains('/'))
    return;
  if (FirebaseAuth.instance.currentUser == null ||
      _stagingNavigator.currentState == null) {
    _pendingNotification = message;
    return;
  }
  _stagingNavigator.currentState!.push(MaterialPageRoute(
      builder: (_) => BookingDetailsScreen(bookingId: bookingId)));
}

Future<void> main() async {
  if (!bookingStagingAllowed(appFlavor, bookingStagingProject))
    throw StateError('Dedicated staging flavor required');
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp();
  if (!bookingStagingAllowed(appFlavor, app.options.projectId)) {
    await app.delete();
    throw StateError('Staging cannot connect to any other Firebase project');
  }
  FirebaseMessaging.onMessageOpenedApp.listen(_openNotification);
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _pendingNotification = message;
  }).catchError((_) {});
  runApp(MaterialApp(
      navigatorKey: _stagingNavigator,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            const Material(
                color: Colors.amber,
                child: SafeArea(
                    bottom: false,
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('STAGING — اختبار فقط — لا تحوّل أموالًا',
                            style: TextStyle(color: Colors.black))))),
            Expanded(child: child!)
          ])),
      home: const _StagingLogin()));
}

class _StagingLogin extends StatefulWidget {
  const _StagingLogin();
  @override
  State<_StagingLogin> createState() => _LoginState();
}

class _LoginState extends State<_StagingLogin> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;
  StreamSubscription<String>? tokenUpdates;
  @override
  void dispose() {
    tokenUpdates?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('حساب اختبار staging')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text(
            'يتطلب تشغيل خدمات مشروع الاختبار المنفصل وتوفير حساب اختبار من الإدارة. حسابات المحاكيات المحلية لا تعمل هنا.'),
        TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
        TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور')),
        if (error != null) Text(error!),
        FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: email.text.trim(), password: password.text);
                      final uid = FirebaseAuth.instance.currentUser!.uid;
                      final user = await FirebaseFirestore.instance
                          .doc('users/$uid')
                          .get();
                      if (!user.exists || user.data()?['isBlocked'] == true)
                        throw StateError('Inactive test account');
                      // Notification permission failures must not prevent booking access.
                      try {
                        await FirebaseMessaging.instance.requestPermission();
                        final token =
                            await FirebaseMessaging.instance.getToken();
                        if (token != null)
                          await FirebaseFirestore.instance
                              .doc('users/$uid')
                              .update({'fcmToken': token});
                        tokenUpdates = FirebaseMessaging.instance.onTokenRefresh
                            .listen((token) {
                          FirebaseFirestore.instance
                              .doc('users/$uid')
                              .update({'fcmToken': token}).catchError((_) {});
                        });
                      } catch (_) {}
                      if (mounted) {
                        final navigation = Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => BookingScreen(
                                    admin: user.data()?['isAdmin'] == true)));
                        final notification = _pendingNotification;
                        _pendingNotification = null;
                        if (notification != null)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (FirebaseAuth.instance.currentUser != null)
                              _openNotification(notification);
                          });
                        await navigation;
                      }
                    } catch (_) {
                      if (mounted)
                        setState(() => error =
                            'تعذر الدخول. تحقق من الحساب وتشغيل خدمات staging واتصال الإنترنت.');
                    } finally {
                      await tokenUpdates?.cancel();
                      tokenUpdates = null;
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        try {
                          await FirebaseFirestore.instance
                              .doc('users/$uid')
                              .update({'fcmToken': FieldValue.delete()});
                        } catch (_) {}
                      }
                      await FirebaseAuth.instance.signOut();
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'جاري الدخول...' : 'دخول'))
      ]));
}
